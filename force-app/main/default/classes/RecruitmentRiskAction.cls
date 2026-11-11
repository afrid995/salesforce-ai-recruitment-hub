/**
 * @description Invocable Apex Action for Agentforce AI Recruitment Assistant.
 * Enables recruiters and hiring managers to query deterministic recruitment risks,
 * candidate coverage deficits, pipeline bottlenecks, recurring skill shortages,
 * and overdue interviews.
 */
public with sharing class RecruitmentRiskAction {

    public class RiskRequest {
        @InvocableVariable(label='Job Title or Code' description='Optional job title or requisition code (e.g. AI/ML Engineer, REQ-AIML-001).' required=false)
        public String jobTitleOrCode;

        @InvocableVariable(label='Query Type' description='Type of query: all, requisition_attention, candidate_coverage, pipeline_bottlenecks, skill_gaps, overdue_interviews, why_job_needs_attention.' required=false)
        public String queryType;

        @InvocableVariable(label='Severity Filter' description='Optional filter: High Attention, Requires Recruiter Review, Informational.' required=false)
        public String severityFilter;
    }

    public class RiskResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Summary')
        public String summary;

        @InvocableVariable(label='High Attention Count')
        public Integer highAttentionCount;

        @InvocableVariable(label='Requires Review Count')
        public Integer requiresReviewCount;

        @InvocableVariable(label='Overdue Interviews Count')
        public Integer overdueInterviewsCount;

        @InvocableVariable(label='Top Recurring Skill Gaps')
        public String topRecurringSkillGaps;

        @InvocableVariable(label='Responsible AI Notice')
        public String responsibleAiNotice;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        public RiskResult() {
            this.isSuccess = true;
            this.highAttentionCount = 0;
            this.requiresReviewCount = 0;
            this.overdueInterviewsCount = 0;
            this.topRecurringSkillGaps = '';
            this.responsibleAiNotice = RecruitmentRiskService.RESPONSIBLE_AI_NOTICE;
            this.errorMessage = '';
        }
    }

    @InvocableMethod(
        label='Get Recruitment Risk and Bottleneck Intelligence'
        description='Identifies recruitment risks, operational bottlenecks, candidate coverage deficits, recurring skill gaps, and overdue interviews based on live Salesforce data.'
    )
    public static List<RiskResult> getRiskIntelligence(List<RiskRequest> requests) {
        List<RiskResult> results = new List<RiskResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (RiskRequest req : requests) {
            RiskResult res = new RiskResult();
            try {
                String targetJobId = null;
                String matchedJobTitle = null;

                // Resolve Job if specified
                if (String.isNotBlank(req.jobTitleOrCode)) {
                    String term = req.jobTitleOrCode.trim();
                    List<Job_Requisition__c> matchedJobs = [
                        SELECT Id, Job_Title__c, Job_Code__c
                        FROM Job_Requisition__c
                        WHERE Job_Title__c LIKE :('%' + term + '%')
                           OR Job_Code__c = :term
                        LIMIT 1
                    ];
                    if (!matchedJobs.isEmpty()) {
                        targetJobId = matchedJobs[0].Id;
                        matchedJobTitle = matchedJobs[0].Job_Title__c;
                    } else {
                        res.isSuccess = false;
                        res.errorMessage = 'No job requisition found matching "' + term + '" in Salesforce.';
                        res.summary = '### Recruitment Attention Analysis\n\nNo job requisition matching **"' +
                            term + '"** was found in Salesforce. Please check the job title or code.';
                        results.add(res);
                        continue;
                    }
                }

                // Query risk intelligence
                RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(
                    targetJobId,
                    req.severityFilter,
                    null
                );

                res.highAttentionCount = dto.totalHighAttentionCount;
                res.requiresReviewCount = dto.totalRequiresReviewCount;
                res.overdueInterviewsCount = dto.totalOverdueInterviews;

                // Collect top skill gaps
                List<String> topSkills = new List<String>();
                for (Integer i = 0; i < Math.min(5, dto.recurringSkillGaps.size()); i++) {
                    RecruitmentRiskService.SkillGapRiskMetric m = dto.recurringSkillGaps[i];
                    topSkills.add(m.skillName + ' (' + m.affectedEvaluations + ' evaluations, ' + m.affectedJobsCount + ' jobs)');
                }
                res.topRecurringSkillGaps = String.join(topSkills, '; ');

                // Build tailored summary based on queryType
                String qType = String.isNotBlank(req.queryType) ? req.queryType.toLowerCase() : 'all';
                res.summary = formatSummary(dto, qType, matchedJobTitle);

            } catch (Exception ex) {
                res.isSuccess = false;
                res.errorMessage = ex.getMessage();
                res.summary = 'Error evaluating recruitment risks: ' + ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    private static String formatSummary(
        RecruitmentRiskService.RiskDashboardDTO dto,
        String queryType,
        String targetJobTitle
    ) {
        List<String> sb = new List<String>();

        if (String.isNotBlank(targetJobTitle)) {
            sb.add('### Recruitment Attention Analysis: ' + targetJobTitle + '\n');
            if (dto.jobSummaries.isEmpty()) {
                sb.add('Current data indicates no open requisition or match evaluations recorded for this role.');
                return String.join(sb, '\n');
            }
            RecruitmentRiskService.RequisitionRiskSummary sum = dto.jobSummaries[0];
            sb.add('**Overall Attention Level**: `' + sum.overallAttentionLevel + '`\n');
            sb.add('- **Required Headcount**: ' + sum.requiredHeadcount.intValue());
            sb.add('- **Total Applications**: ' + sum.applicationCount);
            sb.add('- **Evaluated Candidates**: ' + sum.evaluatedCandidateCount);
            sb.add('- **Good or Higher Matches (>= 65%)**: ' + (sum.strongMatchCount + sum.goodMatchCount) +
                ' (' + sum.percentGoodOrHigher + '%)');
            sb.add('- **Strong Matches (>= 80%)**: ' + sum.strongMatchCount + ' (' + sum.percentStrong + '%)');
            sb.add('- **Average Match Score**: ' + sum.averageMatchScore + '%');
            sb.add('- **Highest Match Candidate**: ' + sum.highestMatchCandidateName + ' (' + sum.highestMatchScore + '%)\n');

            if (!sum.signals.isEmpty()) {
                sb.add('**Observable Attention Signals**:');
                for (RecruitmentRiskService.RiskSignal s : sum.signals) {
                    sb.add('- **[' + s.severity + '] ' + s.title + '**');
                    sb.add('  - *Evidence*: ' + s.evidence);
                    sb.add('  - *Explanation*: ' + s.explanation);
                }
            } else {
                sb.add('Current data indicates healthy candidate coverage meeting headcount requirements. No high attention signals generated.');
            }

            sb.add('\n> [!NOTE]\n> ' + RecruitmentRiskService.RESPONSIBLE_AI_NOTICE);
            return String.join(sb, '\n');
        }

        // Organization-Wide Queries
        if (queryType == 'overdue_interviews') {
            sb.add('### Overdue Scheduled Interviews\n');
            sb.add('Current data indicates **' + dto.totalOverdueInterviews + '** overdue scheduled interview(s) requiring recruiter review:\n');
            if (dto.interviewSignals.isEmpty()) {
                sb.add('There are currently no overdue scheduled interviews.');
            } else {
                for (RecruitmentRiskService.RiskSignal s : dto.interviewSignals) {
                    if (s.severity == RecruitmentRiskService.SEV_HIGH) {
                        sb.add('- **' + s.title + '** (' + s.jobTitle + ')');
                        sb.add('  - ' + s.explanation);
                    }
                }
            }
        } else if (queryType == 'skill_gaps') {
            sb.add('### Top Recurring Skill Shortages Across Requisitions\n');
            sb.add('Current data indicates the following recurring talent gaps across evaluated candidate pools:\n');
            for (Integer i = 0; i < Math.min(8, dto.recurringSkillGaps.size()); i++) {
                RecruitmentRiskService.SkillGapRiskMetric m = dto.recurringSkillGaps[i];
                sb.add('- **' + m.skillName + '**: Missing across **' + m.affectedEvaluations +
                    '** candidate evaluations across **' + m.affectedJobsCount + '** active requisition(s) (' +
                    String.join(m.affectedJobTitles, ', ') + ').');
            }
            sb.add('\n*Recommendation*: Requires recruiter review. Candidate pools may require targeted sourcing or adjusted skill requirements.');
        } else if (queryType == 'pipeline_bottlenecks') {
            sb.add('### Current Recruitment Pipeline Bottlenecks\n');
            if (dto.pipelineSignals.isEmpty()) {
                sb.add('Current pipeline data indicates balanced progression across application stages without critical concentration.');
            } else {
                for (RecruitmentRiskService.RiskSignal s : dto.pipelineSignals) {
                    sb.add('- **[' + s.severity + '] ' + s.title + '**');
                    sb.add('  - *Evidence*: ' + s.evidence);
                    sb.add('  - *Explanation*: ' + s.explanation);
                }
            }
        } else if (queryType == 'candidate_coverage' || queryType == 'requisition_attention') {
            sb.add('### Requisition Attention & Candidate Coverage Summary\n');
            sb.add('Current pipeline data indicates **' + dto.totalJobsNeedingAttention + '** open requisition(s) requiring recruiter attention:\n');
            for (RecruitmentRiskService.RiskSignal s : dto.requisitionSignals) {
                sb.add('- **[' + s.severity + '] ' + s.title + '**');
                sb.add('  - *Evidence*: ' + s.evidence);
                sb.add('  - *Explanation*: ' + s.explanation);
            }
        } else {
            // General Overview
            sb.add('### Recruitment Risk & Bottleneck Intelligence Overview\n');
            sb.add('**Operational Attention Summary**:');
            sb.add('- **High Attention Signals**: ' + dto.totalHighAttentionCount);
            sb.add('- **Requires Recruiter Review**: ' + dto.totalRequiresReviewCount);
            sb.add('- **Overdue Interviews**: ' + dto.totalOverdueInterviews);
            sb.add('- **Requisitions Needing Attention**: ' + dto.totalJobsNeedingAttention + '\n');

            sb.add('**Key Attention Items**:');
            Integer count = 0;
            for (RecruitmentRiskService.RiskSignal s : dto.allSignals) {
                if (s.severity == RecruitmentRiskService.SEV_HIGH || s.severity == RecruitmentRiskService.SEV_REVIEW) {
                    sb.add('- **[' + s.severity + '] ' + s.title + '** (' + s.signalType + ')');
                    sb.add('  - *Explanation*: ' + s.explanation);
                    count++;
                    if (count >= 6) break;
                }
            }
        }

        sb.add('\n> [!NOTE]\n> ' + RecruitmentRiskService.RESPONSIBLE_AI_NOTICE);
        return String.join(sb, '\n');
    }
}
