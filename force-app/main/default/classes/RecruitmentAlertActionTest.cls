/**
 * @description Unit tests for RecruitmentAlertAction invocable Apex action.
 * Tests all query types:
 * - all_alerts
 * - high_attention
 * - why_job_flagged (matching and non-matching)
 * - overdue_interviews
 * - skill_gap_candidates (with specific skill and general)
 * - null/empty request handling
 */
@isTest
private class RecruitmentAlertActionTest {

    @testSetup
    static void setupTestData() {
        // Job Requisition
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Research Scientist',
            Job_Code__c = 'REQ-AIML-99',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Number_of_Positions__c = 1,
            Required_Skills__c = 'Python, PyTorch, LLMs'
        );
        insert job;

        // Candidates
        Candidate__c c1 = new Candidate__c(
            Candidate_Name__c = 'Diana Prince',
            Email__c = 'diana.p@example.com',
            Candidate_Status__c = 'Interviewing',
            Skills__c = 'Python, PyTorch',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'Master Degree',
            Location__c = 'Remote'
        );
        Candidate__c c2 = new Candidate__c(
            Candidate_Name__c = 'Bruce Wayne',
            Email__c = 'bruce.w@example.com',
            Candidate_Status__c = 'Screening',
            Skills__c = 'Java, C++',
            Years_of_Experience__c = 3.0,
            Highest_Qualification__c = 'Bachelor Degree',
            Location__c = 'Gotham'
        );
        insert new List<Candidate__c>{ c1, c2 };

        // Application
        Job_Application__c app = new Job_Application__c(
            Candidate__c = c1.Id,
            Job_Requisition__c = job.Id,
            Application_Status__c = 'Interview Scheduled',
            Application_Date__c = Date.today().addDays(-15)
        );
        insert app;

        // Overdue Interview
        Interview__c overdueInterview = new Interview__c(
            Interview_Name__c = 'Diana Prince - AI Technical Round',
            Job_Application__c = app.Id,
            Candidate__c = c1.Id,
            Interview_Status__c = 'Scheduled',
            Interview_Date__c = Datetime.now().addDays(-2),
            Interview_Type__c = 'Technical'
        );
        insert overdueInterview;

        // Match evaluations
        Candidate_Job_Match__c match1 = new Candidate_Job_Match__c(
            Candidate__c = c1.Id,
            Job_Requisition__c = job.Id,
            Overall_Match_Score__c = 75.0,
            Missing_Skills__c = 'LLMs',
            Recommendation__c = 'Good Match',
            Evaluation_Status__c = 'Completed',
            Match_Key__c = String.valueOf(c1.Id) + '_' + String.valueOf(job.Id),
            Calculated_On__c = Datetime.now()
        );
        Candidate_Job_Match__c match2 = new Candidate_Job_Match__c(
            Candidate__c = c2.Id,
            Job_Requisition__c = job.Id,
            Overall_Match_Score__c = 40.0,
            Missing_Skills__c = 'Python, PyTorch, LLMs',
            Recommendation__c = 'Low Match',
            Evaluation_Status__c = 'Completed',
            Match_Key__c = String.valueOf(c2.Id) + '_' + String.valueOf(job.Id),
            Calculated_On__c = Datetime.now()
        );
        insert new List<Candidate_Job_Match__c>{ match1, match2 };

        // Synchronize alerts so Recruitment_Alert__c records exist
        RecruitmentAlertService.synchronizeAlerts();
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> nullResults = RecruitmentAlertAction.getRecruitmentAlerts(null);
        List<RecruitmentAlertAction.AlertResult> emptyResults = RecruitmentAlertAction.getRecruitmentAlerts(new List<RecruitmentAlertAction.AlertRequest>());
        Test.stopTest();

        System.assertNotEquals(null, nullResults, 'Null request should return default result list');
        System.assertEquals(1, nullResults.size(), 'Should have 1 default response');
        System.assert(nullResults[0].summary.contains('No alert request provided'), 'Should advise no request provided');

        System.assertNotEquals(null, emptyResults, 'Empty request should return default result list');
        System.assertEquals(1, emptyResults.size(), 'Should have 1 default response');
    }

    @isTest
    static void testAllAlertsQuery() {
        RecruitmentAlertAction.AlertRequest req = new RecruitmentAlertAction.AlertRequest();
        req.queryType = 'all_alerts';

        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> results = RecruitmentAlertAction.getRecruitmentAlerts(new List<RecruitmentAlertAction.AlertRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 result');
        RecruitmentAlertAction.AlertResult res = results[0];
        System.assertEquals(true, res.isSuccess, 'Result should be successful');
        System.assert(res.summary.contains('Active Alerts Overview'), 'Summary should contain overview header');
        System.assert(res.responsibleAiNotice.contains('Responsible AI'), 'Responsible AI notice must be present');
    }

    @isTest
    static void testHighAttentionQuery() {
        RecruitmentAlertAction.AlertRequest req = new RecruitmentAlertAction.AlertRequest();
        req.queryType = 'high_attention';

        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> results = RecruitmentAlertAction.getRecruitmentAlerts(new List<RecruitmentAlertAction.AlertRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 result');
        RecruitmentAlertAction.AlertResult res = results[0];
        System.assertEquals(true, res.isSuccess, 'Result should be successful');
        System.assert(res.summary.contains('High-Attention Recruitment Issues'), 'Should contain high attention section');
    }

    @isTest
    static void testWhyJobFlaggedQuery() {
        RecruitmentAlertAction.AlertRequest reqMatch = new RecruitmentAlertAction.AlertRequest();
        reqMatch.queryType = 'why_job_flagged';
        reqMatch.jobTitleOrCode = 'REQ-AIML-99';

        RecruitmentAlertAction.AlertRequest reqNoMatch = new RecruitmentAlertAction.AlertRequest();
        reqNoMatch.queryType = 'why_job_flagged';
        reqNoMatch.jobTitleOrCode = 'NON_EXISTENT_JOB';

        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> results = RecruitmentAlertAction.getRecruitmentAlerts(
            new List<RecruitmentAlertAction.AlertRequest>{ reqMatch, reqNoMatch }
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 results');
        System.assert(results[0].summary.contains('REQ-AIML-99'), 'First result should mention target job');
        System.assert(results[1].summary.contains('No active alerts found matching "NON_EXISTENT_JOB"'), 'Second result should indicate no alerts');
    }

    @isTest
    static void testOverdueInterviewsQuery() {
        RecruitmentAlertAction.AlertRequest req = new RecruitmentAlertAction.AlertRequest();
        req.queryType = 'overdue_interviews';

        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> results = RecruitmentAlertAction.getRecruitmentAlerts(new List<RecruitmentAlertAction.AlertRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 result');
        RecruitmentAlertAction.AlertResult res = results[0];
        System.assert(res.summary.contains('Overdue Scheduled Interviews Guidance'), 'Summary should contain overdue header');
        System.assert(res.summary.contains('Human-in-the-Loop Governance'), 'Must contain human-in-the-loop notice');
    }

    @isTest
    static void testSkillGapCandidatesQuery() {
        RecruitmentAlertAction.AlertRequest reqSkill = new RecruitmentAlertAction.AlertRequest();
        reqSkill.queryType = 'skill_gap_candidates';
        reqSkill.skillName = 'LLMs';

        RecruitmentAlertAction.AlertRequest reqEmptySkill = new RecruitmentAlertAction.AlertRequest();
        reqEmptySkill.queryType = 'skill_gap_candidates';
        reqEmptySkill.skillName = '';

        Test.startTest();
        List<RecruitmentAlertAction.AlertResult> results = RecruitmentAlertAction.getRecruitmentAlerts(
            new List<RecruitmentAlertAction.AlertRequest>{ reqSkill, reqEmptySkill }
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 results');
        System.assert(results[0].summary.contains('Candidate Pool Skill Gap Analysis'), 'Should format skill gap analysis');
        System.assert(results[1].summary.contains('Candidate Pool Skill Gap Analysis'), 'Should format general skill gap analysis');
    }
}
