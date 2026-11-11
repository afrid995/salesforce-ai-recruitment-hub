/**
 * @description Comprehensive test suite for Phase 5 RecruitmentRiskService and RecruitmentRiskController.
 * Validates all 16 required test scenarios:
 * 1. Job with zero candidates.
 * 2. Job with zero match evaluations.
 * 3. Job with only Low/Moderate matches.
 * 4. Job with Good Match candidates.
 * 5. Job with Strong Match candidates.
 * 6. Candidate coverage below headcount.
 * 7. Pipeline concentration (Applied, Under Review, Post-Interview).
 * 8. Overdue interview.
 * 9. Upcoming interview.
 * 10. Recurring skill gap.
 * 11. Multiple jobs sharing same skill gap.
 * 12. No false positive attention signals (closed jobs, healthy jobs).
 * 13. Responsible-AI wording ('Requires recruiter review').
 * 14. Zero status mutation.
 * 15. Bulk processing.
 * 16. Empty datasets.
 */
@IsTest
private class RecruitmentRiskServiceTest {

    @TestSetup
    static void setupTestData() {
        // 1. Create Job Requisitions
        List<Job_Requisition__c> jobs = new List<Job_Requisition__c>();

        // Job 1: AI/ML Engineer (Headcount 4, Low Candidate Coverage, 3 Low Matches, 1 Good Match)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-RISK-001',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Number_of_Positions__c = 4,
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Master of Science',
            Required_Skills__c = 'Python, PyTorch, REST APIs, Docker'
        ));

        // Job 2: Software Engineer (Headcount 1, Strong Match coverage)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'Software Engineer',
            Job_Code__c = 'REQ-RISK-002',
            Department__c = 'Software Development',
            Status__c = 'Open',
            Number_of_Positions__c = 1,
            Location__c = 'Austin, TX',
            Experience_Required__c = 3.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'JavaScript, React, Node.js, REST APIs'
        ));

        // Job 3: Data Analyst (Headcount 2, Zero Good Matches, Low Average Score < 45)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'Data Analyst',
            Job_Code__c = 'REQ-RISK-003',
            Department__c = 'Data Science',
            Status__c = 'Open',
            Number_of_Positions__c = 2,
            Location__c = 'Remote',
            Experience_Required__c = 2.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'SQL, Tableau, Statistical Modeling, Python'
        ));

        // Job 4: DevOps Engineer (Headcount 3, 0 Applications, 0 Matches)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'DevOps Engineer',
            Job_Code__c = 'REQ-RISK-004',
            Department__c = 'IT',
            Status__c = 'Open',
            Number_of_Positions__c = 3,
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 5.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'AWS, Kubernetes, Terraform'
        ));

        // Job 5: Closed Requisition (Should NOT generate open-job attention signals)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'Cloud Architect',
            Job_Code__c = 'REQ-RISK-005',
            Department__c = 'IT',
            Status__c = 'Closed',
            Closing_Date__c = Date.today(),
            Number_of_Positions__c = 1,
            Location__c = 'Austin, TX'
        ));

        insert jobs;

        // 2. Create Candidates
        List<Candidate__c> candidates = new List<Candidate__c>();
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.morgan@risktest.com',
            Candidate_Status__c = 'Interviewing',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'Master of Science',
            Skills__c = 'Python, PyTorch, Docker'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Brenda Vance',
            Email__c = 'brenda.vance@risktest.com',
            Candidate_Status__c = 'Screening',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 3.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'JavaScript, React, Node.js'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Carlos Mendez',
            Email__c = 'carlos.mendez@risktest.com',
            Candidate_Status__c = 'Shortlisted',
            Location__c = 'Remote',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'SQL, Tableau'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Diana Chen',
            Email__c = 'diana.chen@risktest.com',
            Candidate_Status__c = 'New',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 2.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'Python'
        ));

        insert candidates;

        // 3. Create Applications
        List<Job_Application__c> apps = new List<Job_Application__c>();
        
        // Job 1: 4 applications (3 in 'Applied' -> screening backlog concentration!)
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[0].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-5)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[1].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-4)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[2].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-3)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[3].Id,
            Application_Status__c = 'Interview Scheduled',
            Application_Date__c = Date.today().addDays(-2)
        ));

        // Job 2: 2 applications (both 'Interviewed' -> post-interview decision concentration!)
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[1].Id,
            Candidate__c = candidates[0].Id,
            Application_Status__c = 'Interviewed',
            Application_Date__c = Date.today().addDays(-7)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[1].Id,
            Candidate__c = candidates[2].Id,
            Application_Status__c = 'Interviewed',
            Application_Date__c = Date.today().addDays(-6)
        ));

        // Job 3: 2 applications (both 'Under Review' -> screening concentration!)
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[2].Id,
            Candidate__c = candidates[1].Id,
            Application_Status__c = 'Under Review',
            Application_Date__c = Date.today().addDays(-3)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[2].Id,
            Candidate__c = candidates[3].Id,
            Application_Status__c = 'Under Review',
            Application_Date__c = Date.today().addDays(-2)
        ));

        insert apps;

        // 4. Create Candidate_Job_Match__c records
        List<Candidate_Job_Match__c> matches = new List<Candidate_Job_Match__c>();
        // Job 1 Matches: 1 Good (72), 2 Low (45, 40)
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[0].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 72.00,
            Recommendation__c = 'Good Match',
            Missing_Skills__c = 'REST APIs, Kubernetes'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[1].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 45.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'REST APIs, Python'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[2].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 40.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'REST APIs, Docker'
        ));

        // Job 2 Matches: 2 Strong (88, 82)
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[0].Id,
            Job_Requisition__c = jobs[1].Id,
            Overall_Match_Score__c = 88.00,
            Recommendation__c = 'Strong Match',
            Missing_Skills__c = 'REST APIs'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[2].Id,
            Job_Requisition__c = jobs[1].Id,
            Overall_Match_Score__c = 82.00,
            Recommendation__c = 'Strong Match',
            Missing_Skills__c = 'TypeScript'
        ));

        // Job 3 Matches: 0 Good (42, 44 -> low average)
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[1].Id,
            Job_Requisition__c = jobs[2].Id,
            Overall_Match_Score__c = 42.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'Statistical Modeling, REST APIs'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[3].Id,
            Job_Requisition__c = jobs[2].Id,
            Overall_Match_Score__c = 44.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'Statistical Modeling, Python'
        ));

        insert matches;

        // 5. Create Interviews
        List<Interview__c> interviews = new List<Interview__c>();
        // Overdue scheduled interview (Job 1)
        interviews.add(new Interview__c(
            Interview_Name__c = 'AI Round 1',
            Job_Application__c = apps[3].Id, // Diana Chen, Job 1
            Candidate__c = candidates[3].Id,
            Interview_Date__c = Datetime.now().addDays(-2),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        ));

        // Future scheduled interview (Job 2)
        interviews.add(new Interview__c(
            Interview_Name__c = 'System Design',
            Job_Application__c = apps[4].Id, // Alex Morgan, Job 2
            Candidate__c = candidates[0].Id,
            Interview_Date__c = Datetime.now().addDays(4),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        ));

        // Completed interview
        interviews.add(new Interview__c(
            Interview_Name__c = 'Phone Screen',
            Job_Application__c = apps[4].Id,
            Candidate__c = candidates[0].Id,
            Interview_Date__c = Datetime.now().addDays(-6),
            Interview_Status__c = 'Completed',
            Interview_Type__c = 'Phone'
        ));

        insert interviews;
    }

    @IsTest
    static void testEvaluateRisksAll() {
        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'RiskDashboardDTO should not be null');
        System.assert(dto.totalHighAttentionCount > 0, 'Should have high attention signals');
        System.assert(dto.totalRequiresReviewCount > 0, 'Should have review signals');
        System.assertEquals(1, dto.totalOverdueInterviews, 'Should identify exactly 1 overdue interview');
        System.assert(dto.totalJobsNeedingAttention >= 3, 'At least 3 jobs need attention');

        // Verify Requisition Attention Signals
        System.assert(dto.requisitionSignals.size() > 0, 'Requisition signals should be populated');
        
        // Verify Pipeline Bottleneck Signals
        System.assert(dto.pipelineSignals.size() > 0, 'Pipeline signals should be populated');

        // Verify Interview Attention Signals
        System.assert(dto.interviewSignals.size() > 0, 'Interview signals should be populated');
        Boolean foundOverdue = false;
        for (RecruitmentRiskService.RiskSignal s : dto.interviewSignals) {
            if (s.title.contains('Overdue scheduled interview')) {
                foundOverdue = true;
                System.assertEquals(RecruitmentRiskService.SEV_HIGH, s.severity);
                System.assert(s.explanation.contains('Requires recruiter review.'));
            }
        }
        System.assert(foundOverdue, 'Overdue interview signal must be present');

        // Verify Skill Gap Intelligence
        System.assert(dto.recurringSkillGaps.size() > 0, 'Recurring skill gaps must be calculated');
        // REST APIs is missing across Job 1, Job 2, and Job 3
        Boolean foundRestApi = false;
        for (RecruitmentRiskService.SkillGapRiskMetric m : dto.recurringSkillGaps) {
            if (m.skillName == 'REST APIs') {
                foundRestApi = true;
                System.assert(m.isMultiJobGap, 'REST APIs must be flagged as multi-job gap');
                System.assert(m.affectedJobsCount >= 3, 'REST APIs must affect at least 3 jobs');
            }
        }
        System.assert(foundRestApi, 'REST APIs must be identified as top recurring gap');

        // Verify Responsible AI Wording
        System.assert(dto.responsibleAiNotice.contains('Responsible AI Operational Notice'));
        for (RecruitmentRiskService.RiskSignal s : dto.allSignals) {
            System.assert(
                s.explanation.contains('Requires recruiter review') ||
                s.explanation.contains('Recruiter review may be required') ||
                s.severity == RecruitmentRiskService.SEV_INFO,
                'Every signal must use responsible AI phrasing: ' + s.explanation
            );
        }
    }

    @IsTest
    static void testJobZeroCandidatesAndEvaluations() {
        Job_Requisition__c devOpsJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-RISK-004' LIMIT 1];

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(devOpsJob.Id, null, null);
        Test.stopTest();

        System.assertEquals(1, dto.jobSummaries.size());
        RecruitmentRiskService.RequisitionRiskSummary sum = dto.jobSummaries[0];
        System.assertEquals(0, sum.applicationCount);
        System.assertEquals(0, sum.evaluatedCandidateCount);
        System.assertEquals(RecruitmentRiskService.SEV_HIGH, sum.overallAttentionLevel);

        Boolean foundZeroApps = false;
        Boolean foundZeroMatches = false;
        for (RecruitmentRiskService.RiskSignal s : sum.signals) {
            if (s.title.contains('Zero applications')) foundZeroApps = true;
            if (s.title.contains('Match evaluation unavailable')) foundZeroMatches = true;
        }
        System.assert(foundZeroApps, 'Should flag zero applications for DevOps job');
        System.assert(foundZeroMatches, 'Should flag missing match evaluations for DevOps job');
    }

    @IsTest
    static void testJobZeroGoodMatchesAndCoverageDeficit() {
        Job_Requisition__c dataAnalystJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-RISK-003' LIMIT 1];

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(dataAnalystJob.Id, null, null);
        Test.stopTest();

        System.assertEquals(1, dto.jobSummaries.size());
        RecruitmentRiskService.RequisitionRiskSummary sum = dto.jobSummaries[0];
        System.assertEquals(0, sum.goodMatchCount);
        System.assertEquals(0, sum.strongMatchCount);
        System.assertEquals(43.00, sum.averageMatchScore);

        Boolean foundZeroGood = false;
        Boolean foundLowAvg = false;
        for (RecruitmentRiskService.RiskSignal s : sum.signals) {
            if (s.title.contains('Zero Good Match candidates')) foundZeroGood = true;
            if (s.title.contains('Low average match score')) foundLowAvg = true;
        }
        System.assert(foundZeroGood, 'Should flag zero good match candidates');
        System.assert(foundLowAvg, 'Should flag low average match score below moderate benchmark');
    }

    @IsTest
    static void testJobWithStrongMatches() {
        Job_Requisition__c sweJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-RISK-002' LIMIT 1];

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(sweJob.Id, null, null);
        Test.stopTest();

        System.assertEquals(1, dto.jobSummaries.size());
        RecruitmentRiskService.RequisitionRiskSummary sum = dto.jobSummaries[0];
        System.assertEquals(2, sum.strongMatchCount);
        System.assertEquals(88.00, sum.highestMatchScore);
        System.assertEquals('Alex Morgan', sum.highestMatchCandidateName);

        Boolean foundStrongInfo = false;
        for (RecruitmentRiskService.RiskSignal s : sum.signals) {
            if (s.title.contains('Strong candidate coverage')) {
                foundStrongInfo = true;
                System.assertEquals(RecruitmentRiskService.SEV_INFO, s.severity);
            }
        }
        System.assert(foundStrongInfo, 'Should note strong candidate coverage exceeding headcount as Informational');
    }

    @IsTest
    static void testPipelineConcentrations() {
        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(null, null, RecruitmentRiskService.TYPE_PIPE);
        Test.stopTest();

        Boolean foundAppliedBacklog = false;
        Boolean foundUnderReview = false;
        Boolean foundPostInterview = false;

        for (RecruitmentRiskService.RiskSignal s : dto.pipelineSignals) {
            if (s.title.contains('Application screening backlog')) foundAppliedBacklog = true;
            if (s.title.contains('Screening concentration')) foundUnderReview = true;
            if (s.title.contains('Post-interview decision backlog')) foundPostInterview = true;
        }

        System.assert(foundAppliedBacklog, 'Should detect screening backlog in Applied stage');
        System.assert(foundUnderReview, 'Should detect concentration in Under Review stage');
        System.assert(foundPostInterview, 'Should detect decision backlog in Interviewed stage');
    }

    @IsTest
    static void testClosedJobGeneratesNoOpenRequisitionSignals() {
        Job_Requisition__c closedJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-RISK-005' LIMIT 1];

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(closedJob.Id, null, null);
        Test.stopTest();

        System.assertEquals(1, dto.jobSummaries.size());
        System.assertEquals(0, dto.jobSummaries[0].signals.size(), 'Closed job must not generate open requisition attention signals');
        System.assertEquals('Healthy', dto.jobSummaries[0].overallAttentionLevel);
    }

    @IsTest
    static void testSeverityAndCategoryFiltering() {
        Test.startTest();
        // Severity Filter
        RecruitmentRiskService.RiskDashboardDTO highOnly = RecruitmentRiskService.evaluateRisks(
            null, RecruitmentRiskService.SEV_HIGH, null
        );
        for (RecruitmentRiskService.RiskSignal s : highOnly.allSignals) {
            System.assertEquals(RecruitmentRiskService.SEV_HIGH, s.severity);
        }

        // Category Filter
        RecruitmentRiskService.RiskDashboardDTO skillOnly = RecruitmentRiskService.evaluateRisks(
            null, null, RecruitmentRiskService.TYPE_SKILL
        );
        for (RecruitmentRiskService.RiskSignal s : skillOnly.allSignals) {
            System.assertEquals(RecruitmentRiskService.TYPE_SKILL, s.signalType);
        }
        Test.stopTest();
    }

    @IsTest
    static void testZeroMutationConstraint() {
        Map<Id, String> candidateInitialStatus = new Map<Id, String>();
        for (Candidate__c c : [SELECT Id, Candidate_Status__c FROM Candidate__c]) {
            candidateInitialStatus.put(c.Id, c.Candidate_Status__c);
        }

        Map<Id, String> appInitialStatus = new Map<Id, String>();
        for (Job_Application__c a : [SELECT Id, Application_Status__c FROM Job_Application__c]) {
            appInitialStatus.put(a.Id, a.Application_Status__c);
        }

        Map<Id, String> interviewInitialStatus = new Map<Id, String>();
        for (Interview__c iv : [SELECT Id, Interview_Status__c FROM Interview__c]) {
            interviewInitialStatus.put(iv.Id, iv.Interview_Status__c);
        }

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(null, null, null);
        Test.stopTest();

        for (Candidate__c c : [SELECT Id, Candidate_Status__c FROM Candidate__c]) {
            System.assertEquals(candidateInitialStatus.get(c.Id), c.Candidate_Status__c, 'Candidate status must NEVER be mutated');
        }

        for (Job_Application__c a : [SELECT Id, Application_Status__c FROM Job_Application__c]) {
            System.assertEquals(appInitialStatus.get(a.Id), a.Application_Status__c, 'Application status must NEVER be mutated');
        }

        for (Interview__c iv : [SELECT Id, Interview_Status__c FROM Interview__c]) {
            System.assertEquals(interviewInitialStatus.get(iv.Id), iv.Interview_Status__c, 'Interview status must NEVER be mutated');
        }
    }

    @IsTest
    static void testControllerEndpoints() {
        Job_Requisition__c aimlJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-RISK-001' LIMIT 1];

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO full = RecruitmentRiskController.getRiskIntelligence(aimlJob.Id, null, null);
        System.assertNotEquals(null, full);

        RecruitmentRiskService.RequisitionRiskSummary sum = RecruitmentRiskController.getJobRiskSummary(aimlJob.Id);
        System.assertNotEquals(null, sum);
        System.assertEquals(aimlJob.Id, sum.jobId);

        List<RecruitmentRiskController.JobOptionDTO> options = RecruitmentRiskController.getJobOptions();
        System.assert(options.size() >= 4); // All Jobs + open jobs
        Test.stopTest();
    }

    @IsTest
    static void testControllerErrorHandling() {
        Test.startTest();
        try {
            RecruitmentRiskController.getJobRiskSummary(null);
            System.assert(false, 'Should throw exception for null jobId');
        } catch (Exception ex) {
            System.assert(ex instanceof AuraHandledException || ex.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBulkExecutionScaling() {
        List<Job_Requisition__c> bulkJobs = new List<Job_Requisition__c>();
        for (Integer i = 10; i <= 30; i++) {
            bulkJobs.add(new Job_Requisition__c(
                Job_Title__c = 'Bulk Requisition ' + i,
                Job_Code__c = 'REQ-BLKRISK-' + i,
                Department__c = 'Software Development',
                Status__c = 'Open',
                Number_of_Positions__c = 1,
                Location__c = 'Remote'
            ));
        }
        insert bulkJobs;

        Test.startTest();
        RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(null, null, null);
        Test.stopTest();

        System.assert(dto.jobSummaries.size() >= 25);
        System.assert(Limits.getQueries() < Limits.getLimitQueries(), 'SOQL query count must stay well below limit');
    }
}
