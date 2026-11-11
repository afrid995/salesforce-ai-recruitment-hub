/**
 * @description Invocable Apex Action for Agentforce AI Recruitment Assistant.
 * Provides recruiter-facing natural language insights into active recruitment alerts,
 * high-attention priorities, requisition-specific flagging rationale, overdue interview
 * guidance, and skill gap candidate impact.
 *
 * Strictly adheres to Responsible AI:
 * - Decision-support only: Never makes autonomous hiring decisions.
 * - For interview rescheduling, guides the recruiter to the Action Center for explicit confirmation.
 * - Always uses factual, evidence-based descriptions.
 */
public with sharing class RecruitmentAlertAction {

    public class AlertRequest {
        @InvocableVariable(label='Query Type' description='Query type: all_alerts, high_attention, why_job_flagged, overdue_interviews, skill_gap_candidates' required=false)
        public String queryType;

        @InvocableVariable(label='Job Title or Code' description='Optional job title or requisition code (e.g. AI/ML Engineer, REQ-AIML-001)' required=false)
        public String jobTitleOrCode;

        @InvocableVariable(label='Skill Name' description='Optional skill name for skill gap queries (e.g. LLMs, Agentforce, Python)' required=false)
        public String skillName;
    }

    public class AlertResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Summary')
        public String summary;

        @InvocableVariable(label='High Attention Count')
        public Integer highAttentionCount;

        @InvocableVariable(label='Requires Review Count')
        public Integer requiresReviewCount;

        @InvocableVariable(label='Total Active Alerts')
        public Integer totalActiveAlerts;

        @InvocableVariable(label='Responsible AI Notice')
        public String responsibleAiNotice;

        public AlertResult() {
            this.isSuccess = true;
            this.highAttentionCount = 0;
            this.requiresReviewCount = 0;
            this.totalActiveAlerts = 0;
            this.responsibleAiNotice = RecruitmentRiskService.RESPONSIBLE_AI_NOTICE;
            this.summary = '';
        }
    }

    @InvocableMethod(
        label='Get Recruitment Alerts and Recruiter Actions'
        description='Retrieves active recruitment alerts, high-attention items, requisition flagging rationale, overdue interview details, and skill gap candidate impact.'
    )
    public static List<AlertResult> getRecruitmentAlerts(List<AlertRequest> requests) {
        List<AlertResult> results = new List<AlertResult>();
        if (requests == null || requests.isEmpty()) {
            AlertResult defRes = new AlertResult();
            defRes.summary = 'No alert request provided. Please specify query type.';
            results.add(defRes);
            return results;
        }

        // Fetch current Action Center data
        RecruitmentAlertService.AlertOverviewDTO dto = RecruitmentAlertService.getActionCenterAlerts(null, 'all', 'all', 'all');

        for (AlertRequest req : requests) {
            AlertResult res = new AlertResult();
            res.highAttentionCount = dto.highAttentionCount;
            res.requiresReviewCount = dto.requiresReviewCount;
            res.totalActiveAlerts = dto.activeAlertsCount;

            String qType = String.isNotBlank(req.queryType) ? req.queryType.toLowerCase().trim() : 'all_alerts';

            if (qType.contains('high') || qType == 'high_attention') {
                res.summary = formatHighAttentionAlerts(dto);
            } else if (qType.contains('why') || qType.contains('flagged') || String.isNotBlank(req.jobTitleOrCode)) {
                res.summary = formatJobFlaggedAlerts(dto, req.jobTitleOrCode);
            } else if (qType.contains('interview') || qType.contains('overdue')) {
                res.summary = formatOverdueInterviewGuidance(dto);
            } else if (qType.contains('skill') || String.isNotBlank(req.skillName)) {
                res.summary = formatSkillGapCandidates(req.skillName);
            } else {
                res.summary = formatAllAlertsOverview(dto);
            }

            results.add(res);
        }

        return results;
    }

    private static String formatAllAlertsOverview(RecruitmentAlertService.AlertOverviewDTO dto) {
        List<String> lines = new List<String>();
        lines.add('### Recruiter Action Center: Active Alerts Overview\n');
        lines.add('**Operational Attention Summary**:');
        lines.add('- **High Attention Alerts**: ' + dto.highAttentionCount);
        lines.add('- **Requires Recruiter Review**: ' + dto.requiresReviewCount);
        lines.add('- **Informational**: ' + dto.informationalCount);
        lines.add('- **Acknowledged by Recruiters**: ' + dto.acknowledgedCount);
        lines.add('- **Resolved**: ' + dto.resolvedCount + '\n');

        lines.add('**Immediate Attention Items**:');
        Integer count = 0;
        for (RecruitmentAlertService.AlertItemDTO a : dto.alerts) {
            if (a.severity == RecruitmentRiskService.SEV_HIGH && a.isActive) {
                count++;
                lines.add('- **[' + a.severity + '] ' + a.title + '**');
                lines.add('  - *Evidence*: ' + a.evidence);
                lines.add('  - *Explanation*: ' + a.explanation);
                if (count >= 5) break;
            }
        }
        if (count == 0) {
            lines.add('No active High Attention alerts. Requisition pipelines are progressing within normal parameters.');
        }

        lines.add('\n*Action Guidance: Open the **Action Center** tab to acknowledge alerts or reschedule interviews with human confirmation.*');
        lines.add('\n> [!NOTE]\n> ' + dto.responsibleAiNotice);
        return String.join(lines, '\n');
    }

    private static String formatHighAttentionAlerts(RecruitmentAlertService.AlertOverviewDTO dto) {
        List<String> lines = new List<String>();
        lines.add('### High-Attention Recruitment Issues Requiring Recruiter Review\n');

        Integer highCount = 0;
        for (RecruitmentAlertService.AlertItemDTO a : dto.alerts) {
            if (a.severity == RecruitmentRiskService.SEV_HIGH && a.isActive) {
                highCount++;
                lines.add('#### ' + highCount + '. ' + a.title);
                lines.add('- **Category**: `' + a.alertType + '`');
                if (String.isNotBlank(a.jobTitle)) lines.add('- **Job**: ' + a.jobTitle + (String.isNotBlank(a.jobCode) ? ' (' + a.jobCode + ')' : ''));
                if (String.isNotBlank(a.candidateName)) lines.add('- **Candidate**: ' + a.candidateName);
                lines.add('- **Evidence**: ' + a.evidence);
                lines.add('- **Explanation**: ' + a.explanation);
                lines.add('- **Recommended Recruiter Action**: ' + getActionRecommendation(a) + '\n');
            }
        }

        if (highCount == 0) {
            lines.add('There are currently no unresolved High Attention alerts.');
        }

        lines.add('> [!NOTE]\n> ' + dto.responsibleAiNotice);
        return String.join(lines, '\n');
    }

    private static String formatJobFlaggedAlerts(RecruitmentAlertService.AlertOverviewDTO dto, String jobQuery) {
        List<String> lines = new List<String>();
        String target = String.isNotBlank(jobQuery) ? jobQuery.toLowerCase().trim() : '';

        List<RecruitmentAlertService.AlertItemDTO> matchedAlerts = new List<RecruitmentAlertService.AlertItemDTO>();
        for (RecruitmentAlertService.AlertItemDTO a : dto.alerts) {
            if (String.isNotBlank(a.jobTitle) && (String.isBlank(target) || a.jobTitle.toLowerCase().contains(target) || (a.jobCode != null && a.jobCode.toLowerCase().contains(target)))) {
                matchedAlerts.add(a);
            }
        }

        String displayJob = String.isNotBlank(jobQuery) ? jobQuery : 'Active Job Requisition';
        lines.add('### Recruitment Attention Review: ' + displayJob + '\n');

        if (matchedAlerts.isEmpty()) {
            lines.add('No active alerts found matching "' + displayJob + '". Pipeline metrics appear healthy.');
        } else {
            lines.add('Found **' + matchedAlerts.size() + '** operational attention alert(s):\n');
            for (RecruitmentAlertService.AlertItemDTO a : matchedAlerts) {
                lines.add('- **[' + a.severity + '] ' + a.title + '**');
                lines.add('  - *Status*: `' + a.status + '`');
                lines.add('  - *Evidence*: ' + a.evidence);
                lines.add('  - *Explanation*: ' + a.explanation);
                lines.add('  - *Next Step*: ' + getActionRecommendation(a) + '\n');
            }
        }

        lines.add('> [!NOTE]\n> ' + dto.responsibleAiNotice);
        return String.join(lines, '\n');
    }

    private static String formatOverdueInterviewGuidance(RecruitmentAlertService.AlertOverviewDTO dto) {
        List<String> lines = new List<String>();
        lines.add('### Overdue Scheduled Interviews Guidance\n');

        Integer overdueCount = 0;
        for (RecruitmentAlertService.AlertItemDTO a : dto.alerts) {
            if (a.alertType == RecruitmentRiskService.TYPE_INT && a.canReschedule && a.isActive) {
                overdueCount++;
                lines.add('- **' + a.title + '**');
                lines.add('  - *Job*: ' + a.jobTitle);
                lines.add('  - *Details*: ' + a.evidence);
                lines.add('  - *Action*: In the **Action Center**, click **Reschedule Interview** to pick a future date and time with human confirmation.\n');
            }
        }

        if (overdueCount == 0) {
            lines.add('No past-due scheduled interviews are currently on the calendar.');
        } else {
            lines.add('> [!IMPORTANT]');
            lines.add('> Human-in-the-Loop Governance: Interviews cannot be rescheduled autonomously by AI. All schedule updates require explicit recruiter selection and confirmation.');
        }

        lines.add('\n> [!NOTE]\n> ' + dto.responsibleAiNotice);
        return String.join(lines, '\n');
    }

    private static String formatSkillGapCandidates(String skillTarget) {
        List<String> lines = new List<String>();
        lines.add('### Candidate Pool Skill Gap Analysis\n');

        String cleanSkill = String.isNotBlank(skillTarget) ? skillTarget.toLowerCase().trim() : '';

        // Query Candidate_Job_Match__c records
        List<Candidate_Job_Match__c> matches = [
            SELECT Id, Candidate__r.Candidate_Name__c, Job_Requisition__r.Job_Title__c,
                   Overall_Match_Score__c, Missing_Skills__c, Recommendation__c
            FROM Candidate_Job_Match__c
            ORDER BY Overall_Match_Score__c DESC
            LIMIT 100
        ];

        Map<String, List<String>> candidatesBySkill = new Map<String, List<String>>();
        for (Candidate_Job_Match__c m : matches) {
            if (String.isBlank(m.Missing_Skills__c)) continue;
            String cName = m.Candidate__r != null ? m.Candidate__r.Candidate_Name__c : 'Candidate';
            String jTitle = m.Job_Requisition__r != null ? m.Job_Requisition__r.Job_Title__c : 'Job';
            List<String> skills = m.Missing_Skills__c.split(',');
            for (String s : skills) {
                String trimmed = s.trim();
                String k = trimmed.toLowerCase();
                if (String.isBlank(cleanSkill) || k.contains(cleanSkill)) {
                    if (!candidatesBySkill.containsKey(trimmed)) {
                        candidatesBySkill.put(trimmed, new List<String>());
                    }
                    candidatesBySkill.get(trimmed).add(cName + ' (' + jTitle + ' - ' + m.Overall_Match_Score__c + '%)');
                }
            }
        }

        if (candidatesBySkill.isEmpty()) {
            lines.add('No candidate matches found missing skill "' + skillTarget + '".');
        } else {
            lines.add('Observed candidate skill shortages across evaluated candidate-job matches:\n');
            Integer count = 0;
            for (String sk : candidatesBySkill.keySet()) {
                count++;
                List<String> cList = candidatesBySkill.get(sk);
                lines.add('**' + sk + '** (Missing in ' + cList.size() + ' evaluations):');
                for (Integer i = 0; i < Math.min(4, cList.size()); i++) {
                    lines.add('  - ' + cList[i]);
                }
                if (cList.size() > 4) {
                    lines.add('  - *...and ' + (cList.size() - 4) + ' more candidate evaluation(s)*');
                }
                lines.add('');
                if (count >= 5) break;
            }
        }

        lines.add('> [!NOTE]\n> ' + RecruitmentRiskService.RESPONSIBLE_AI_NOTICE);
        return String.join(lines, '\n');
    }

    private static String getActionRecommendation(RecruitmentAlertService.AlertItemDTO a) {
        if (a.alertType == RecruitmentRiskService.TYPE_INT && a.canReschedule) {
            return 'Click "Reschedule Interview" in Action Center to coordinate a future date/time.';
        }
        if (a.alertType == RecruitmentRiskService.TYPE_REQ) {
            return 'Click "View Match Intelligence" or "Compare Candidates" to evaluate pipeline depth.';
        }
        if (a.alertType == RecruitmentRiskService.TYPE_PIPE) {
            return 'Open Requisition record to review pending candidate applications in current stage.';
        }
        return 'Review pipeline records and click "Acknowledge" to record assessment.';
    }
}
