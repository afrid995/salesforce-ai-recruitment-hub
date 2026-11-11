/**
 * @description Phase 5: Recruitment Risk & Bottleneck Intelligence Service.
 * Provides deterministic, explainable operational signals across 4 categories:
 * 1. Requisition Attention & Candidate Coverage
 * 2. Pipeline Bottlenecks
 * 3. Skill Shortage Intelligence
 * 4. Interview Attention
 *
 * Strictly decision-support only:
 * - NO predictive hiring, NO rejection algorithms, NO probability guessing.
 * - Strictly consumes existing Candidate_Job_Match__c intelligence; zero score recalculations.
 * - ZERO DML / mutation on Candidate, Application, or Interview records.
 * - Standardized human-in-the-loop phrasing: 'Requires recruiter review'.
 */
public with sharing class RecruitmentRiskService {

    public static final String SEV_HIGH = 'High Attention';
    public static final String SEV_REVIEW = 'Requires Recruiter Review';
    public static final String SEV_INFO = 'Informational';

    public static final String TYPE_REQ = 'Requisition Attention';
    public static final String TYPE_PIPE = 'Pipeline Bottlenecks';
    public static final String TYPE_SKILL = 'Skill Gaps';
    public static final String TYPE_INT = 'Interview Attention';

    public static final String RESPONSIBLE_AI_NOTICE =
        'Responsible AI Operational Notice: Recruitment risk and bottleneck signals are deterministic, ' +
        'evidence-based observations of current Salesforce records provided solely for human recruiter decision support. ' +
        'These signals do not predict hiring outcomes, candidate success, or candidate rejection. ' +
        'All recruitment and hiring decisions remain the exclusive responsibility of human recruiters.';

    public class RiskSignal {
        @AuraEnabled public String signalId { get; set; }
        @AuraEnabled public String signalType { get; set; }
        @AuraEnabled public String severity { get; set; }
        @AuraEnabled public String severityClass { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String evidence { get; set; }
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public Datetime calculatedDate { get; set; }
        @AuraEnabled public Boolean requiresRecruiterReview { get; set; }
        @AuraEnabled public String drillDownAction { get; set; }
        @AuraEnabled public Id relatedRecordId { get; set; }
    }

    public class RequisitionRiskSummary {
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal requiredHeadcount { get; set; }
        @AuraEnabled public Integer applicationCount { get; set; }
        @AuraEnabled public Integer evaluatedCandidateCount { get; set; }
        @AuraEnabled public Integer strongMatchCount { get; set; }       // >= 80%
        @AuraEnabled public Integer goodMatchCount { get; set; }         // >= 65%
        @AuraEnabled public Integer moderateMatchCount { get; set; }     // >= 50%
        @AuraEnabled public Integer lowMatchCount { get; set; }          // < 50%
        @AuraEnabled public Decimal highestMatchScore { get; set; }
        @AuraEnabled public String highestMatchCandidateName { get; set; }
        @AuraEnabled public Decimal averageMatchScore { get; set; }
        @AuraEnabled public Decimal percentGoodOrHigher { get; set; }    // (good+strong)/total
        @AuraEnabled public Decimal percentStrong { get; set; }          // strong/total
        @AuraEnabled public String overallAttentionLevel { get; set; }
        @AuraEnabled public List<RiskSignal> signals { get; set; }

        public RequisitionRiskSummary() {
            this.signals = new List<RiskSignal>();
            this.requiredHeadcount = 0;
            this.applicationCount = 0;
            this.evaluatedCandidateCount = 0;
            this.strongMatchCount = 0;
            this.goodMatchCount = 0;
            this.moderateMatchCount = 0;
            this.lowMatchCount = 0;
            this.highestMatchScore = 0.00;
            this.highestMatchCandidateName = 'None';
            this.averageMatchScore = 0.00;
            this.percentGoodOrHigher = 0.0;
            this.percentStrong = 0.0;
            this.overallAttentionLevel = 'Healthy';
        }
    }

    public class SkillGapRiskMetric {
        @AuraEnabled public String skillName { get; set; }
        @AuraEnabled public Integer affectedEvaluations { get; set; }
        @AuraEnabled public Integer affectedCandidates { get; set; }
        @AuraEnabled public Integer affectedJobsCount { get; set; }
        @AuraEnabled public List<String> affectedJobTitles { get; set; }
        @AuraEnabled public List<Id> affectedJobIds { get; set; }
        @AuraEnabled public Boolean isMultiJobGap { get; set; }

        public SkillGapRiskMetric() {
            this.affectedEvaluations = 0;
            this.affectedCandidates = 0;
            this.affectedJobsCount = 0;
            this.affectedJobTitles = new List<String>();
            this.affectedJobIds = new List<Id>();
            this.isMultiJobGap = false;
        }
    }

    public class RiskDashboardDTO {
        @AuraEnabled public Integer totalHighAttentionCount { get; set; }
        @AuraEnabled public Integer totalRequiresReviewCount { get; set; }
        @AuraEnabled public Integer totalInformationalCount { get; set; }
        @AuraEnabled public Integer totalOverdueInterviews { get; set; }
        @AuraEnabled public Integer totalJobsNeedingAttention { get; set; }
        @AuraEnabled public List<RiskSignal> allSignals { get; set; }
        @AuraEnabled public List<RiskSignal> requisitionSignals { get; set; }
        @AuraEnabled public List<RiskSignal> pipelineSignals { get; set; }
        @AuraEnabled public List<RiskSignal> skillGapSignals { get; set; }
        @AuraEnabled public List<RiskSignal> interviewSignals { get; set; }
        @AuraEnabled public List<RequisitionRiskSummary> jobSummaries { get; set; }
        @AuraEnabled public List<SkillGapRiskMetric> recurringSkillGaps { get; set; }
        @AuraEnabled public String responsibleAiNotice { get; set; }

        public RiskDashboardDTO() {
            this.totalHighAttentionCount = 0;
            this.totalRequiresReviewCount = 0;
            this.totalInformationalCount = 0;
            this.totalOverdueInterviews = 0;
            this.totalJobsNeedingAttention = 0;
            this.allSignals = new List<RiskSignal>();
            this.requisitionSignals = new List<RiskSignal>();
            this.pipelineSignals = new List<RiskSignal>();
            this.skillGapSignals = new List<RiskSignal>();
            this.interviewSignals = new List<RiskSignal>();
            this.jobSummaries = new List<RequisitionRiskSummary>();
            this.recurringSkillGaps = new List<SkillGapRiskMetric>();
            this.responsibleAiNotice = RESPONSIBLE_AI_NOTICE;
        }
    }

    public class RiskThresholds {
        public Decimal goodMatchScore = 65.0;
        public Decimal lowMatchScore = 50.0;
        public Decimal lowMatchConcentration = 60.0;
        public Decimal poolAverageScore = 45.0;
        public Decimal screeningBacklog = 50.0;
        public Decimal underReviewBacklog = 40.0;
        public Decimal interviewDecisionBacklog = 2.0;
        public Decimal systemicSkillGapJobs = 2.0;
        public Decimal systemicSkillGapEvals = 3.0;
        public Decimal overdueInterviewHours = 0.0;
    }

    public static RiskThresholds loadThresholds() {
        RiskThresholds th = new RiskThresholds();
        try {
            List<Recruitment_Alert_Threshold__mdt> records = [
                SELECT Alert_Key__c, Enabled__c, Severity__c, Threshold_Value__c
                FROM Recruitment_Alert_Threshold__mdt
                WHERE Enabled__c = true
            ];
            for (Recruitment_Alert_Threshold__mdt r : records) {
                if (r.Threshold_Value__c == null) continue;
                String k = r.Alert_Key__c != null ? r.Alert_Key__c.toUpperCase() : '';
                if (k == 'GOOD_MATCH_SCORE') th.goodMatchScore = r.Threshold_Value__c;
                else if (k == 'LOW_MATCH_SCORE') th.lowMatchScore = r.Threshold_Value__c;
                else if (k == 'LOW_MATCH_CONCENTRATION') th.lowMatchConcentration = r.Threshold_Value__c;
                else if (k == 'POOL_AVERAGE_SCORE') th.poolAverageScore = r.Threshold_Value__c;
                else if (k == 'SCREENING_BACKLOG') th.screeningBacklog = r.Threshold_Value__c;
                else if (k == 'UNDER_REVIEW_BACKLOG') th.underReviewBacklog = r.Threshold_Value__c;
                else if (k == 'INTERVIEW_DECISION_BACKLOG') th.interviewDecisionBacklog = r.Threshold_Value__c;
                else if (k == 'SYSTEMIC_SKILL_GAP_JOBS') th.systemicSkillGapJobs = r.Threshold_Value__c;
                else if (k == 'SYSTEMIC_SKILL_GAP_EVALS') th.systemicSkillGapEvals = r.Threshold_Value__c;
                else if (k == 'OVERDUE_INTERVIEW_HOURS') th.overdueInterviewHours = r.Threshold_Value__c;
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Could not query Recruitment_Alert_Threshold__mdt, using defaults: ' + ex.getMessage());
        }
        return th;
    }

    /**
     * @description Main entry point for evaluating recruitment risks and bottlenecks.
     * Evaluates active jobs, candidate match coverage, pipeline stages, interview schedules,
     * and missing skills using deterministic rules.
     */
    public static RiskDashboardDTO evaluateRisks(String targetJobId, String severityFilter, String signalTypeFilter) {
        RiskDashboardDTO dto = new RiskDashboardDTO();
        Datetime nowTime = Datetime.now();
        RiskThresholds th = loadThresholds();

        // 1. Query Job Requisitions
        String jobQuery = 'SELECT Id, Name, Job_Title__c, Job_Code__c, Department__c, Status__c, Number_of_Positions__c, Required_Skills__c FROM Job_Requisition__c WHERE Id != null';
        if (String.isNotBlank(targetJobId)) {
            jobQuery += ' AND Id = :targetJobId';
        }
        jobQuery += ' ORDER BY Job_Title__c ASC';
        List<Job_Requisition__c> targetJobs = Database.query(jobQuery);
        Set<Id> targetJobIds = new Map<Id, Job_Requisition__c>(targetJobs).keySet();

        if (targetJobs.isEmpty()) {
            return dto;
        }

        // 2. Query Applications
        List<Job_Application__c> allApps = [
            SELECT Id, Application_Number__c, Application_Status__c, Application_Date__c,
                   Candidate__c, Candidate__r.Candidate_Name__c, Job_Requisition__c, Job_Requisition__r.Job_Title__c
            FROM Job_Application__c
            WHERE Job_Requisition__c IN :targetJobIds
        ];

        Map<Id, List<Job_Application__c>> appsByJob = new Map<Id, List<Job_Application__c>>();
        for (Job_Application__c app : allApps) {
            if (!appsByJob.containsKey(app.Job_Requisition__c)) {
                appsByJob.put(app.Job_Requisition__c, new List<Job_Application__c>());
            }
            appsByJob.get(app.Job_Requisition__c).add(app);
        }

        // 3. Query Candidate_Job_Match__c (consume existing scores only)
        List<Candidate_Job_Match__c> allMatches = [
            SELECT Id, Candidate__c, Candidate__r.Candidate_Name__c, Job_Requisition__c,
                   Job_Requisition__r.Job_Title__c, Overall_Match_Score__c, Recommendation__c,
                   Missing_Skills__c, Matched_Skills__c
            FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c IN :targetJobIds
            ORDER BY Overall_Match_Score__c DESC
        ];

        Map<Id, List<Candidate_Job_Match__c>> matchesByJob = new Map<Id, List<Candidate_Job_Match__c>>();
        for (Candidate_Job_Match__c m : allMatches) {
            if (!matchesByJob.containsKey(m.Job_Requisition__c)) {
                matchesByJob.put(m.Job_Requisition__c, new List<Candidate_Job_Match__c>());
            }
            matchesByJob.get(m.Job_Requisition__c).add(m);
        }

        // 4. Query Interviews
        List<Interview__c> allInterviews = [
            SELECT Id, Name, Interview_Name__c, Interview_Date__c, Interview_Status__c, Interview_Type__c,
                   Candidate__c, Candidate__r.Candidate_Name__c, Job_Application__c,
                   Job_Application__r.Job_Requisition__c, Job_Application__r.Job_Requisition__r.Job_Title__c,
                   Job_Application__r.Candidate__c, Job_Application__r.Candidate__r.Candidate_Name__c
            FROM Interview__c
            WHERE Job_Application__r.Job_Requisition__c IN :targetJobIds
            ORDER BY Interview_Date__c ASC
        ];

        Map<Id, List<Interview__c>> interviewsByJob = new Map<Id, List<Interview__c>>();
        for (Interview__c iv : allInterviews) {
            Id jId = iv.Job_Application__r != null ? iv.Job_Application__r.Job_Requisition__c : null;
            if (jId != null) {
                if (!interviewsByJob.containsKey(jId)) {
                    interviewsByJob.put(jId, new List<Interview__c>());
                }
                interviewsByJob.get(jId).add(iv);
            }
        }

        // -------------------------------------------------------------
        // EVALUATION 1: REQUISITION ATTENTION & CANDIDATE COVERAGE
        // -------------------------------------------------------------
        Set<Id> jobsWithAttention = new Set<Id>();

        for (Job_Requisition__c j : targetJobs) {
            Boolean isOpen = 'Open'.equalsIgnoreCase(j.Status__c);
            Decimal headcount = j.Number_of_Positions__c != null && j.Number_of_Positions__c > 0 ? j.Number_of_Positions__c : 1;
            List<Job_Application__c> jApps = appsByJob.containsKey(j.Id) ? appsByJob.get(j.Id) : new List<Job_Application__c>();
            List<Candidate_Job_Match__c> jMatches = matchesByJob.containsKey(j.Id) ? matchesByJob.get(j.Id) : new List<Candidate_Job_Match__c>();

            RequisitionRiskSummary sum = new RequisitionRiskSummary();
            sum.jobId = j.Id;
            sum.jobTitle = j.Job_Title__c;
            sum.jobCode = j.Job_Code__c;
            sum.department = j.Department__c;
            sum.status = j.Status__c;
            sum.requiredHeadcount = headcount;
            sum.applicationCount = jApps.size();

            // Count unique evaluated candidates
            Set<Id> uniqueCandidates = new Set<Id>();
            for (Candidate_Job_Match__c m : jMatches) {
                if (m.Candidate__c != null) uniqueCandidates.add(m.Candidate__c);
            }
            sum.evaluatedCandidateCount = uniqueCandidates.size();

            Decimal sumScore = 0;
            Decimal maxScore = 0;
            String topCand = 'None';
            Integer strongC = 0;
            Integer goodC = 0;
            Integer modC = 0;
            Integer lowC = 0;

            for (Candidate_Job_Match__c m : jMatches) {
                Decimal sc = m.Overall_Match_Score__c != null ? m.Overall_Match_Score__c : 0.00;
                sumScore += sc;
                if (sc > maxScore) {
                    maxScore = sc;
                    if (m.Candidate__r != null && String.isNotBlank(m.Candidate__r.Candidate_Name__c)) {
                        topCand = m.Candidate__r.Candidate_Name__c;
                    }
                }
                if (sc >= 80.00) {
                    strongC++;
                } else if (sc >= th.goodMatchScore) {
                    goodC++;
                } else if (sc >= th.lowMatchScore) {
                    modC++;
                } else {
                    lowC++;
                }
            }

            sum.strongMatchCount = strongC;
            sum.goodMatchCount = goodC;
            sum.moderateMatchCount = modC;
            sum.lowMatchCount = lowC;
            sum.highestMatchScore = maxScore.setScale(2);
            sum.highestMatchCandidateName = topCand;
            sum.averageMatchScore = !jMatches.isEmpty() ? (sumScore / jMatches.size()).setScale(2) : 0.00;

            Integer goodOrHigher = strongC + goodC;
            sum.percentGoodOrHigher = !jMatches.isEmpty()
                ? ((Decimal.valueOf(goodOrHigher) / Decimal.valueOf(jMatches.size())) * 100).setScale(1)
                : 0.0;
            sum.percentStrong = !jMatches.isEmpty()
                ? ((Decimal.valueOf(strongC) / Decimal.valueOf(jMatches.size())) * 100).setScale(1)
                : 0.0;

            // Generate Requisition Attention Signals (Only for Open jobs)
            if (isOpen) {
                // Rule 1A: Zero Applications on Open Requisition
                if (jApps.isEmpty()) {
                    RiskSignal sig = createSignal(
                        TYPE_REQ,
                        headcount >= 2 ? SEV_HIGH : SEV_REVIEW,
                        'Zero applications received for ' + j.Job_Title__c,
                        j,
                        '0 applications received for ' + headcount.intValue() + ' open position(s).',
                        j.Job_Title__c + ' currently has no candidate applications. Attention indicated by current pipeline data. Requires recruiter review.',
                        'Job',
                        j.Id
                    );
                    sum.signals.add(sig);
                    dto.requisitionSignals.add(sig);
                    jobsWithAttention.add(j.Id);
                }

                // Rule 1B: Zero Match Evaluations on Open Requisition
                if (jMatches.isEmpty()) {
                    RiskSignal sig = createSignal(
                        TYPE_REQ,
                        SEV_REVIEW,
                        'Match evaluation unavailable for ' + j.Job_Title__c,
                        j,
                        '0 candidate match records calculated on Candidate_Job_Match__c.',
                        'Candidate match evaluations have not yet been generated for ' + j.Job_Title__c + '. Requires recruiter review.',
                        'Match',
                        j.Id
                    );
                    sum.signals.add(sig);
                    dto.requisitionSignals.add(sig);
                    jobsWithAttention.add(j.Id);
                } else {
                    // Rule 1C: Zero Good Match Candidates
                    if (goodOrHigher == 0) {
                        RiskSignal sig = createSignal(
                            TYPE_REQ,
                            SEV_HIGH,
                            'Zero Good Match candidates for ' + j.Job_Title__c,
                            j,
                            '0 of ' + jMatches.size() + ' evaluated candidates scored >= ' + th.goodMatchScore.setScale(0) + '%. Highest score is ' + maxScore.setScale(1) + '%.',
                            'Current candidate pool contains few Good Matches. No candidate currently meets the ' + th.goodMatchScore.setScale(0) + '% match benchmark for ' +
                                j.Job_Title__c + '. Requires recruiter review.',
                            'Match',
                            j.Id
                        );
                        sum.signals.add(sig);
                        dto.requisitionSignals.add(sig);
                        jobsWithAttention.add(j.Id);
                    }
                    // Rule 1D: Good Match Candidate Deficit Relative to Required Headcount
                    else if (goodOrHigher < headcount) {
                        String sev = (headcount >= 2 && goodOrHigher <= 1) ? SEV_HIGH : SEV_REVIEW;
                        RiskSignal sig = createSignal(
                            TYPE_REQ,
                            sev,
                            'Candidate coverage below headcount for ' + j.Job_Title__c,
                            j,
                            'Required Headcount: ' + headcount.intValue() + ' | Evaluated Candidates: ' + jMatches.size() +
                                ' | Candidates >= ' + th.goodMatchScore.setScale(0) + '%: ' + goodOrHigher + '.',
                            'Requires recruiter review: ' + goodOrHigher + ' candidate(s) currently meet the Good Match threshold for ' +
                                headcount.intValue() + ' required position(s). Current match coverage is limited.',
                            'Compare',
                            j.Id
                        );
                        sum.signals.add(sig);
                        dto.requisitionSignals.add(sig);
                        jobsWithAttention.add(j.Id);
                    }

                    // Rule 1E: High Proportion of Low Match Candidates
                    if (jMatches.size() >= 3) {
                        Decimal lowPct = (Decimal.valueOf(lowC) / Decimal.valueOf(jMatches.size())) * 100;
                        if (lowPct >= th.lowMatchConcentration) {
                            RiskSignal sig = createSignal(
                                TYPE_REQ,
                                SEV_REVIEW,
                                'High low-match concentration for ' + j.Job_Title__c,
                                j,
                                lowC + ' of ' + jMatches.size() + ' evaluated candidates (' + lowPct.setScale(0) + '%) scored below ' + th.lowMatchScore.setScale(0) + '%.',
                                'Over ' + th.lowMatchConcentration.setScale(0) + '% of evaluated candidates for ' + j.Job_Title__c + ' have match scores below ' + th.lowMatchScore.setScale(0) + '%. Requires recruiter review.',
                                'Match',
                                j.Id
                            );
                            sum.signals.add(sig);
                            dto.requisitionSignals.add(sig);
                            jobsWithAttention.add(j.Id);
                        }
                    }

                    // Rule 1F: Average Candidate Match Score Below Moderate Benchmark
                    if (sum.averageMatchScore > 0 && sum.averageMatchScore < th.poolAverageScore) {
                        RiskSignal sig = createSignal(
                            TYPE_REQ,
                            SEV_REVIEW,
                            'Low average match score for ' + j.Job_Title__c,
                            j,
                            'Candidate pool average match score is ' + sum.averageMatchScore + '%.',
                            j.Job_Title__c + ' candidate pool has an average match score of ' + sum.averageMatchScore +
                                '%, below the moderate benchmark of ' + th.poolAverageScore.setScale(0) + '%. Requires recruiter review.',
                            'Match',
                            j.Id
                        );
                        sum.signals.add(sig);
                        dto.requisitionSignals.add(sig);
                        jobsWithAttention.add(j.Id);
                    }

                    // Rule 1G: Strong Match Pipeline (Informational)
                    if (strongC >= headcount) {
                        RiskSignal sig = createSignal(
                            TYPE_REQ,
                            SEV_INFO,
                            'Strong candidate coverage for ' + j.Job_Title__c,
                            j,
                            strongC + ' candidate(s) scored >= 80% for ' + headcount.intValue() + ' position(s).',
                            'Requisition has ' + strongC + ' candidate(s) evaluated at Strong Match (>= 80%), meeting headcount requirements.',
                            'Compare',
                            j.Id
                        );
                        sum.signals.add(sig);
                        dto.requisitionSignals.add(sig);
                    }
                }
            }

            // Assign overall attention level for this job
            Boolean hasHigh = false;
            Boolean hasReview = false;
            for (RiskSignal s : sum.signals) {
                if (s.severity == SEV_HIGH) hasHigh = true;
                if (s.severity == SEV_REVIEW) hasReview = true;
            }
            if (hasHigh) {
                sum.overallAttentionLevel = SEV_HIGH;
            } else if (hasReview) {
                sum.overallAttentionLevel = SEV_REVIEW;
            } else {
                sum.overallAttentionLevel = 'Healthy';
            }

            dto.jobSummaries.add(sum);
        }

        // -------------------------------------------------------------
        // EVALUATION 2: PIPELINE BOTTLENECKS
        // -------------------------------------------------------------
        for (Job_Requisition__c j : targetJobs) {
            List<Job_Application__c> jApps = appsByJob.containsKey(j.Id) ? appsByJob.get(j.Id) : new List<Job_Application__c>();
            if (jApps.isEmpty()) continue;

            Map<String, Integer> stageCounts = new Map<String, Integer>{
                'Applied' => 0,
                'Under Review' => 0,
                'Shortlisted' => 0,
                'Interview Scheduled' => 0,
                'Interviewed' => 0,
                'Selected' => 0
            };

            for (Job_Application__c a : jApps) {
                if (a.Application_Status__c != null && stageCounts.containsKey(a.Application_Status__c)) {
                    stageCounts.put(a.Application_Status__c, stageCounts.get(a.Application_Status__c) + 1);
                }
            }

            Integer totalA = jApps.size();
            Integer appliedCount = stageCounts.get('Applied');
            Integer underReviewCount = stageCounts.get('Under Review');
            Integer scheduledCount = stageCounts.get('Interview Scheduled');
            Integer interviewedCount = stageCounts.get('Interviewed');

            // Bottleneck Rule 2A: Applied Stage Concentration
            if (appliedCount >= 3 && ((Decimal.valueOf(appliedCount) / Decimal.valueOf(totalA)) >= (th.screeningBacklog / 100.0))) {
                RiskSignal sig = createSignal(
                    TYPE_PIPE,
                    SEV_REVIEW,
                    'Application screening backlog for ' + j.Job_Title__c,
                    j,
                    appliedCount + ' of ' + totalA + ' applications (' +
                        ((Decimal.valueOf(appliedCount)/Decimal.valueOf(totalA))*100).setScale(0) + '%) are in Applied status.',
                    appliedCount + ' applications are currently awaiting initial recruiter review. Requires recruiter review.',
                    'Job',
                    j.Id
                );
                dto.pipelineSignals.add(sig);
                jobsWithAttention.add(j.Id);
            }

            // Bottleneck Rule 2B: Under Review Concentration
            if (underReviewCount >= 2 && ((Decimal.valueOf(underReviewCount) / Decimal.valueOf(totalA)) >= (th.underReviewBacklog / 100.0))) {
                RiskSignal sig = createSignal(
                    TYPE_PIPE,
                    SEV_REVIEW,
                    'Screening concentration for ' + j.Job_Title__c,
                    j,
                    underReviewCount + ' of ' + totalA + ' applications are currently in Under Review status.',
                    underReviewCount + ' applications are currently in Under Review. Recruiter review may be required.',
                    'Job',
                    j.Id
                );
                dto.pipelineSignals.add(sig);
                jobsWithAttention.add(j.Id);
            }

            // Bottleneck Rule 2C: Interview Scheduling Queue (>= 2 apps in Interview Scheduled)
            if (scheduledCount >= 2) {
                RiskSignal sig = createSignal(
                    TYPE_PIPE,
                    SEV_REVIEW,
                    'Interview scheduling queue for ' + j.Job_Title__c,
                    j,
                    scheduledCount + ' applications are currently in Interview Scheduled stage.',
                    scheduledCount + ' candidates are in Interview Scheduled stage awaiting interview session completion or confirmation. Requires recruiter review.',
                    'Interview',
                    j.Id
                );
                dto.pipelineSignals.add(sig);
                jobsWithAttention.add(j.Id);
            }

            // Bottleneck Rule 2D: Post-Interview Decision Concentration
            if (interviewedCount >= th.interviewDecisionBacklog.intValue()) {
                RiskSignal sig = createSignal(
                    TYPE_PIPE,
                    SEV_REVIEW,
                    'Post-interview decision backlog for ' + j.Job_Title__c,
                    j,
                    interviewedCount + ' candidates have completed interviews (Interviewed status) awaiting final decision.',
                    interviewedCount + ' candidates have completed interviews and await selection decision or feedback progression. Requires recruiter review.',
                    'Job',
                    j.Id
                );
                dto.pipelineSignals.add(sig);
                jobsWithAttention.add(j.Id);
            }
        }

        // -------------------------------------------------------------
        // EVALUATION 3: INTERVIEW ATTENTION
        // -------------------------------------------------------------
        Integer overdueIntCount = 0;
        for (Interview__c iv : allInterviews) {
            String st = iv.Interview_Status__c;
            Boolean isScheduled = 'Scheduled'.equalsIgnoreCase(st);
            Boolean isOverdue = (iv.Interview_Date__c != null && iv.Interview_Date__c < nowTime && isScheduled);

            if (isOverdue) {
                overdueIntCount++;
                String cName = iv.Job_Application__r != null && iv.Job_Application__r.Candidate__r != null
                    ? iv.Job_Application__r.Candidate__r.Candidate_Name__c
                    : (iv.Candidate__r != null ? iv.Candidate__r.Candidate_Name__c : 'Candidate');
                String jTitle = iv.Job_Application__r != null && iv.Job_Application__r.Job_Requisition__r != null
                    ? iv.Job_Application__r.Job_Requisition__r.Job_Title__c
                    : 'Job Requisition';
                Id jId = iv.Job_Application__r != null ? iv.Job_Application__r.Job_Requisition__c : null;

                RiskSignal sig = new RiskSignal();
                sig.signalId = 'INT-OVERDUE-' + iv.Id;
                sig.signalType = TYPE_INT;
                sig.severity = SEV_HIGH;
                sig.severityClass = 'badge-high';
                sig.title = 'Overdue scheduled interview: ' + cName;
                sig.jobId = jId;
                sig.jobTitle = jTitle;
                sig.evidence = 'Interview scheduled for ' + iv.Interview_Date__c.format('MMM dd, yyyy HH:mm') +
                    ' has passed and status remains ' + st + '.';
                sig.explanation = 'Interview for ' + cName + ' (' + jTitle + ') was scheduled for ' +
                    iv.Interview_Date__c.format('MMM dd, yyyy HH:mm') + ' and is past due. Requires recruiter review.';
                sig.calculatedDate = nowTime;
                sig.requiresRecruiterReview = true;
                sig.drillDownAction = 'Interview';
                sig.relatedRecordId = iv.Id;

                dto.interviewSignals.add(sig);
                if (jId != null) jobsWithAttention.add(jId);
            }
        }
        dto.totalOverdueInterviews = overdueIntCount;

        // Check for active jobs with shortlisting/interviewing applications but 0 upcoming interviews
        for (Job_Requisition__c j : targetJobs) {
            if ('Open'.equalsIgnoreCase(j.Status__c)) {
                List<Job_Application__c> jApps = appsByJob.containsKey(j.Id) ? appsByJob.get(j.Id) : new List<Job_Application__c>();
                Integer activeCandidatePipeline = 0;
                for (Job_Application__c a : jApps) {
                    if ('Shortlisted'.equalsIgnoreCase(a.Application_Status__c) ||
                        'Interview Scheduled'.equalsIgnoreCase(a.Application_Status__c)) {
                        activeCandidatePipeline++;
                    }
                }

                List<Interview__c> jInterviews = interviewsByJob.containsKey(j.Id) ? interviewsByJob.get(j.Id) : new List<Interview__c>();
                Integer upcomingCount = 0;
                for (Interview__c iv : jInterviews) {
                    if (iv.Interview_Date__c != null && iv.Interview_Date__c >= nowTime && 'Scheduled'.equalsIgnoreCase(iv.Interview_Status__c)) {
                        upcomingCount++;
                    }
                }

                if (activeCandidatePipeline >= 1 && upcomingCount == 0) {
                    RiskSignal sig = createSignal(
                        TYPE_INT,
                        activeCandidatePipeline >= 2 ? SEV_REVIEW : SEV_INFO,
                        'No upcoming interviews scheduled for ' + j.Job_Title__c,
                        j,
                        activeCandidatePipeline + ' candidate(s) are shortlisted/interview-scheduled, but 0 upcoming interviews are on the calendar.',
                        j.Job_Title__c + ' has candidates awaiting interview rounds without upcoming interview sessions scheduled. Requires recruiter review.',
                        'Job',
                        j.Id
                    );
                    dto.interviewSignals.add(sig);
                    if (activeCandidatePipeline >= 2) jobsWithAttention.add(j.Id);
                }
            }
        }

        // -------------------------------------------------------------
        // EVALUATION 4: SKILL SHORTAGE INTELLIGENCE
        // -------------------------------------------------------------
        Map<String, SkillGapHolder> skillHolderMap = new Map<String, SkillGapHolder>();
        for (Candidate_Job_Match__c m : allMatches) {
            if (String.isNotBlank(m.Missing_Skills__c)) {
                List<String> rawSkills = m.Missing_Skills__c.split(',');
                for (String rs : rawSkills) {
                    String cleanSkill = rs.trim();
                    if (cleanSkill.length() >= 2) {
                        String key = cleanSkill.toLowerCase();
                        if (!skillHolderMap.containsKey(key)) {
                            skillHolderMap.put(key, new SkillGapHolder(cleanSkill));
                        }
                        SkillGapHolder holder = skillHolderMap.get(key);
                        holder.affectedEvaluationCount++;
                        if (m.Candidate__c != null) {
                            holder.affectedCandidateIds.add(m.Candidate__c);
                        }
                        if (m.Job_Requisition__c != null) {
                            holder.affectedJobIds.add(m.Job_Requisition__c);
                            if (m.Job_Requisition__r != null && String.isNotBlank(m.Job_Requisition__r.Job_Title__c)) {
                                holder.affectedJobTitles.add(m.Job_Requisition__r.Job_Title__c);
                            }
                        }
                    }
                }
            }
        }

        List<SkillGapHolder> sortedHolders = skillHolderMap.values();
        sortSkillHolders(sortedHolders);

        for (SkillGapHolder h : sortedHolders) {
            SkillGapRiskMetric metric = new SkillGapRiskMetric();
            metric.skillName = h.originalName;
            metric.affectedEvaluations = h.affectedEvaluationCount;
            metric.affectedCandidates = h.affectedCandidateIds.size();
            metric.affectedJobsCount = h.affectedJobIds.size();
            metric.affectedJobTitles = new List<String>(h.affectedJobTitles);
            metric.affectedJobIds = new List<Id>(h.affectedJobIds);
            metric.isMultiJobGap = (h.affectedJobIds.size() >= th.systemicSkillGapJobs.intValue());
            dto.recurringSkillGaps.add(metric);

            // Generate Signal for Multi-Job recurring skill gaps
            if (metric.isMultiJobGap && metric.affectedEvaluations >= th.systemicSkillGapEvals.intValue()) {
                RiskSignal sig = new RiskSignal();
                sig.signalId = 'SKILL-GAP-' + h.originalName.replaceAll('[^a-zA-Z0-9]', '');
                sig.signalType = TYPE_SKILL;
                sig.severity = SEV_REVIEW;
                sig.severityClass = 'badge-review';
                sig.title = 'Recurring skill shortage: ' + h.originalName;
                sig.evidence = h.originalName + ' is missing in ' + h.affectedEvaluationCount +
                    ' match evaluations across ' + metric.affectedJobsCount + ' requisitions (' +
                    String.join(metric.affectedJobTitles, ', ') + ').';
                sig.explanation = h.originalName + ' is a recurring candidate skill gap across multiple active requisitions. Requires recruiter review.';
                sig.calculatedDate = nowTime;
                sig.requiresRecruiterReview = true;
                sig.drillDownAction = 'Match';

                dto.skillGapSignals.add(sig);
            }
        }

        // -------------------------------------------------------------
        // CONSOLIDATION, FILTERING, & SORTING
        // -------------------------------------------------------------
        List<RiskSignal> rawAll = new List<RiskSignal>();
        rawAll.addAll(dto.requisitionSignals);
        rawAll.addAll(dto.pipelineSignals);
        rawAll.addAll(dto.interviewSignals);
        rawAll.addAll(dto.skillGapSignals);

        // Apply dynamic filters if specified
        List<RiskSignal> filteredList = new List<RiskSignal>();
        for (RiskSignal s : rawAll) {
            Boolean matchSev = String.isBlank(severityFilter) || severityFilter.equalsIgnoreCase('all') || s.severity.equalsIgnoreCase(severityFilter);
            Boolean matchType = String.isBlank(signalTypeFilter) || signalTypeFilter.equalsIgnoreCase('all') || s.signalType.equalsIgnoreCase(signalTypeFilter);
            if (matchSev && matchType) {
                filteredList.add(s);
            }
        }

        sortSignals(filteredList);
        dto.allSignals = filteredList;

        // Recalculate totals from raw signals
        Integer highCount = 0;
        Integer reviewCount = 0;
        Integer infoCount = 0;
        for (RiskSignal s : rawAll) {
            if (s.severity == SEV_HIGH) highCount++;
            else if (s.severity == SEV_REVIEW) reviewCount++;
            else if (s.severity == SEV_INFO) infoCount++;
        }
        dto.totalHighAttentionCount = highCount;
        dto.totalRequiresReviewCount = reviewCount;
        dto.totalInformationalCount = infoCount;
        dto.totalJobsNeedingAttention = jobsWithAttention.size();

        return dto;
    }

    /**
     * @description Factory method to create an explainable RiskSignal with standard metadata.
     */
    private static RiskSignal createSignal(
        String signalType,
        String severity,
        String title,
        Job_Requisition__c job,
        String evidence,
        String explanation,
        String drillDownAction,
        Id relatedRecordId
    ) {
        RiskSignal sig = new RiskSignal();
        sig.signalId = signalType.substring(0, 3).toUpperCase() + '-' + (job != null ? job.Id : 'ORG') + '-' + Math.abs(Crypto.getRandomInteger());
        sig.signalType = signalType;
        sig.severity = severity;
        sig.severityClass = (severity == SEV_HIGH) ? 'badge-high' : ((severity == SEV_REVIEW) ? 'badge-review' : 'badge-info');
        sig.title = title;
        if (job != null) {
            sig.jobId = job.Id;
            sig.jobTitle = job.Job_Title__c;
            sig.jobCode = job.Job_Code__c;
            sig.department = job.Department__c;
        }
        sig.evidence = evidence;
        sig.explanation = explanation;
        sig.calculatedDate = Datetime.now();
        sig.requiresRecruiterReview = true;
        sig.drillDownAction = drillDownAction;
        sig.relatedRecordId = relatedRecordId;
        return sig;
    }

    // Skill Gap Aggregation Helper
    private class SkillGapHolder {
        public String originalName;
        public Integer affectedEvaluationCount;
        public Set<Id> affectedCandidateIds;
        public Set<Id> affectedJobIds;
        public Set<String> affectedJobTitles;

        public SkillGapHolder(String originalName) {
            this.originalName = originalName;
            this.affectedEvaluationCount = 0;
            this.affectedCandidateIds = new Set<Id>();
            this.affectedJobIds = new Set<Id>();
            this.affectedJobTitles = new Set<String>();
        }
    }

    private static void sortSkillHolders(List<SkillGapHolder> listToOrder) {
        Integer n = listToOrder.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = 0; j < n - i - 1; j++) {
                // Order by affectedJobIds size DESC, then evaluation count DESC
                Boolean swap = false;
                if (listToOrder[j].affectedJobIds.size() < listToOrder[j + 1].affectedJobIds.size()) {
                    swap = true;
                } else if (listToOrder[j].affectedJobIds.size() == listToOrder[j + 1].affectedJobIds.size()) {
                    if (listToOrder[j].affectedEvaluationCount < listToOrder[j + 1].affectedEvaluationCount) {
                        swap = true;
                    }
                }
                if (swap) {
                    SkillGapHolder temp = listToOrder[j];
                    listToOrder[j] = listToOrder[j + 1];
                    listToOrder[j + 1] = temp;
                }
            }
        }
    }

    private static void sortSignals(List<RiskSignal> listToOrder) {
        Integer n = listToOrder.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = 0; j < n - i - 1; j++) {
                Integer rankA = getSeverityRank(listToOrder[j].severity);
                Integer rankB = getSeverityRank(listToOrder[j + 1].severity);
                if (rankA > rankB) { // Lower rank number means higher priority (1: High, 2: Review, 3: Info)
                    RiskSignal temp = listToOrder[j];
                    listToOrder[j] = listToOrder[j + 1];
                    listToOrder[j + 1] = temp;
                }
            }
        }
    }

    private static Integer getSeverityRank(String sev) {
        if (sev == SEV_HIGH) return 1;
        if (sev == SEV_REVIEW) return 2;
        return 3;
    }
}
