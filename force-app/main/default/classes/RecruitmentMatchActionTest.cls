@isTest
private class RecruitmentMatchActionTest {

    @testSetup
    static void setupData() {
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-MATCH-01',
            Department__c = 'Artificial Intelligence',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 3,
            Minimum_Qualification__c = 'Bachelor in Computer Science',
            Required_Skills__c = 'Python, PyTorch, LLMs',
            Status__c = 'Open',
            Number_of_Positions__c = 1
        );
        insert job;

        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.morgan@example.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'MS in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs',
            Candidate_Status__c = 'New'
        );
        insert cand;

        Job_Application__c app = new Job_Application__c(
            Candidate__c = cand.Id,
            Job_Requisition__c = job.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today()
        );
        insert app;
    }

    @isTest
    static void testMatchJobTitle() {
        RecruitmentMatchAction.Request req = new RecruitmentMatchAction.Request();
        req.jobTitleOrCode = 'AI/ML Engineer';
        req.topN = 5;

        Test.startTest();
        List<RecruitmentMatchAction.Response> responses = RecruitmentMatchAction.match(new List<RecruitmentMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return 1 response');
        System.assert(responses[0].totalMatchesFound > 0, 'Should find matches');
        System.assert(responses[0].result.contains('Alex Morgan'), 'Should recommend Alex Morgan');
        System.assert(responses[0].result.contains('Decision Support Only'), 'Must include safety disclaimer');
    }

    @isTest
    static void testMatchCandidateName() {
        RecruitmentMatchAction.Request req = new RecruitmentMatchAction.Request();
        req.candidateName = 'Alex Morgan';
        req.topN = 3;

        Test.startTest();
        List<RecruitmentMatchAction.Response> responses = RecruitmentMatchAction.match(new List<RecruitmentMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return 1 response');
        System.assert(responses[0].totalMatchesFound > 0, 'Should find matches');
        System.assert(responses[0].result.contains('AI/ML Engineer'), 'Should recommend AI/ML Engineer');
    }

    @isTest
    static void testMatchPair() {
        RecruitmentMatchAction.Request req = new RecruitmentMatchAction.Request();
        req.jobTitleOrCode = 'REQ-MATCH-01';
        req.candidateName = 'Alex Morgan';
        req.persistScores = true;

        Test.startTest();
        List<RecruitmentMatchAction.Response> responses = RecruitmentMatchAction.match(new List<RecruitmentMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return 1 response');
        System.assertEquals(1, responses[0].totalMatchesFound, 'Should match 1 pair');
        System.assert(responses[0].result.contains('Overall Fit'), 'Should have overall fit details');
    }

    @isTest
    static void testMatchAllApplications() {
        RecruitmentMatchAction.Request req = new RecruitmentMatchAction.Request();
        req.topN = 10;
        req.persistScores = true;

        Test.startTest();
        List<RecruitmentMatchAction.Response> responses = RecruitmentMatchAction.match(new List<RecruitmentMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return 1 response');
        System.assert(responses[0].totalMatchesFound > 0, 'Should evaluate applications');
        System.assert(responses[0].result.contains('Current Job Applications Match Ranking'), 'Should show rankings');
    }

    @isTest
    static void testNotFoundHandling() {
        RecruitmentMatchAction.Request req = new RecruitmentMatchAction.Request();
        req.jobTitleOrCode = 'Nonexistent Job XYZ';

        Test.startTest();
        List<RecruitmentMatchAction.Response> responses = RecruitmentMatchAction.match(new List<RecruitmentMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return 1 response');
        System.assert(responses[0].result.contains('No open job requisition found'), 'Should report not found');
    }
}
