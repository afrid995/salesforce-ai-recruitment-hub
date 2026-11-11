/**
 * @description Unit tests for RecruitmentRiskAction Invocable Action used by Agentforce Copilot.
 */
@IsTest
private class RecruitmentRiskActionTest {

    @TestSetup
    static void setupTestData() {
        // Create Job Requisition
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-ACT-001',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Number_of_Positions__c = 3,
            Location__c = 'San Francisco, CA'
        );
        insert job;

        // Create Candidate
        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.m@acttest.com',
            Candidate_Status__c = 'Interviewing'
        );
        insert cand;

        // Create Application
        Job_Application__c app = new Job_Application__c(
            Job_Requisition__c = job.Id,
            Candidate__c = cand.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-3)
        );
        insert app;

        // Create Match
        Candidate_Job_Match__c match = new Candidate_Job_Match__c(
            Candidate__c = cand.Id,
            Job_Requisition__c = job.Id,
            Overall_Match_Score__c = 75.00,
            Recommendation__c = 'Good Match',
            Missing_Skills__c = 'REST APIs, Docker'
        );
        insert match;

        // Create Overdue Interview
        Interview__c iv = new Interview__c(
            Interview_Name__c = 'Technical Screen',
            Job_Application__c = app.Id,
            Candidate__c = cand.Id,
            Interview_Date__c = Datetime.now().addDays(-2),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        );
        insert iv;
    }

    @IsTest
    static void testGeneralRiskOverview() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.queryType = 'all';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assert(res.summary.contains('Recruitment Risk & Bottleneck Intelligence Overview'));
        System.assert(res.summary.contains('Responsible AI Operational Notice'));
    }

    @IsTest
    static void testWhyJobNeedsAttention() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.jobTitleOrCode = 'AI/ML Engineer';
        req.queryType = 'why_job_needs_attention';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assert(res.summary.contains('Recruitment Attention Analysis: AI/ML Engineer'));
        System.assert(res.summary.contains('Required Headcount'));
        System.assert(res.summary.contains('Good or Higher Matches'));
    }

    @IsTest
    static void testOverdueInterviewsQuery() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.queryType = 'overdue_interviews';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assertEquals(1, res.overdueInterviewsCount);
        System.assert(res.summary.contains('Overdue Scheduled Interviews'));
        System.assert(res.summary.contains('Alex Morgan'));
    }

    @IsTest
    static void testSkillGapsQuery() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.queryType = 'skill_gaps';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assert(res.summary.contains('Top Recurring Skill Shortages'));
        System.assert(res.summary.contains('REST APIs'));
    }

    @IsTest
    static void testPipelineBottlenecksQuery() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.queryType = 'pipeline_bottlenecks';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assert(res.summary.contains('Current Recruitment Pipeline Bottlenecks'));
    }

    @IsTest
    static void testRequisitionAttentionQuery() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.queryType = 'requisition_attention';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(true, res.isSuccess);
        System.assert(res.summary.contains('Requisition Attention & Candidate Coverage Summary'));
    }

    @IsTest
    static void testNonExistentJob() {
        RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
        req.jobTitleOrCode = 'NonExistentRoleXYZ999';

        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        RecruitmentRiskAction.RiskResult res = results[0];
        System.assertEquals(false, res.isSuccess);
        System.assert(res.errorMessage.contains('No job requisition found matching'));
    }

    @IsTest
    static void testEmptyRequests() {
        Test.startTest();
        List<RecruitmentRiskAction.RiskResult> emptyResults = RecruitmentRiskAction.getRiskIntelligence(
            new List<RecruitmentRiskAction.RiskRequest>()
        );
        List<RecruitmentRiskAction.RiskResult> nullResults = RecruitmentRiskAction.getRiskIntelligence(null);
        Test.stopTest();

        System.assertEquals(0, emptyResults.size());
        System.assertEquals(0, nullResults.size());
    }
}
