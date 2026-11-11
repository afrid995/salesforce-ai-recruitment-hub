@isTest
private class CandidateJobMatchActionTest {

    @testSetup
    static void setupData() {
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'Senior AI Engineer',
            Job_Code__c = 'REQ-ACT-01',
            Department__c = 'Artificial Intelligence',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Bachelor in Computer Science',
            Required_Skills__c = 'Python, PyTorch, LLMs',
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Number_of_Positions__c = 1
        );
        insert job;

        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Alice AI Expert',
            Email__c = 'alice.act@example.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'MS in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs',
            Candidate_Status__c = 'New'
        );
        insert cand;
    }

    @isTest
    static void testEvaluateWithJobTitle() {
        CandidateJobMatchAction.Request req = new CandidateJobMatchAction.Request();
        req.jobTitleOrCode = 'Senior AI Engineer';
        req.topN = 5;
        req.persistRecords = true;

        Test.startTest();
        List<CandidateJobMatchAction.Response> responses = CandidateJobMatchAction.evaluate(new List<CandidateJobMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].totalMatchesFound > 0);
        System.assert(responses[0].result.contains('Alice AI Expert'));
        System.assert(responses[0].result.contains('Decision-Support'));
    }

    @isTest
    static void testEvaluateWithCandidateName() {
        CandidateJobMatchAction.Request req = new CandidateJobMatchAction.Request();
        req.candidateName = 'Alice AI Expert';
        req.topN = 3;
        req.persistRecords = true;

        Test.startTest();
        List<CandidateJobMatchAction.Response> responses = CandidateJobMatchAction.evaluate(new List<CandidateJobMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].totalMatchesFound > 0);
        System.assert(responses[0].result.contains('Senior AI Engineer'));
    }

    @isTest
    static void testEvaluateSinglePair() {
        CandidateJobMatchAction.Request req = new CandidateJobMatchAction.Request();
        req.candidateName = 'Alice AI Expert';
        req.jobTitleOrCode = 'REQ-ACT-01';
        req.persistRecords = true;

        Test.startTest();
        List<CandidateJobMatchAction.Response> responses = CandidateJobMatchAction.evaluate(new List<CandidateJobMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(1, responses[0].totalMatchesFound);
        System.assertEquals(100.00, responses[0].topMatchScore);
        System.assertEquals('Strong Match', responses[0].topRecommendation);
        System.assert(responses[0].result.contains('Decision-Support Score: 100.00%'));
    }

    @isTest
    static void testEvaluateAll() {
        CandidateJobMatchAction.Request req = new CandidateJobMatchAction.Request();
        req.topN = 10;

        Test.startTest();
        List<CandidateJobMatchAction.Response> responses = CandidateJobMatchAction.evaluate(new List<CandidateJobMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].totalMatchesFound > 0);
    }

    @isTest
    static void testNotFoundScenarios() {
        CandidateJobMatchAction.Request req = new CandidateJobMatchAction.Request();
        req.jobTitleOrCode = 'Nonexistent Job 999';

        Test.startTest();
        List<CandidateJobMatchAction.Response> responses = CandidateJobMatchAction.evaluate(new List<CandidateJobMatchAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].result.contains('No job requisition found'));
    }
}
