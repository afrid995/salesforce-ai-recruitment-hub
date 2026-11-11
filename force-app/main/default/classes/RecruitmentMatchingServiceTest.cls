@isTest
private class RecruitmentMatchingServiceTest {

    @testSetup
    static void setupData() {
        Job_Requisition__c job1 = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Specialist',
            Job_Code__c = 'REQ-AI-TEST',
            Department__c = 'Artificial Intelligence',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 3,
            Minimum_Qualification__c = 'Master of Science in Computer Science',
            Required_Skills__c = 'Python, PyTorch, LLMs, NLP',
            Status__c = 'Open',
            Number_of_Positions__c = 2
        );

        Job_Requisition__c job2 = new Job_Requisition__c(
            Job_Title__c = 'Frontend Developer',
            Job_Code__c = 'REQ-FE-TEST',
            Department__c = 'Software Development',
            Location__c = 'Remote',
            Experience_Required__c = 2,
            Minimum_Qualification__c = 'Bachelor in Computer Science',
            Required_Skills__c = 'React, JavaScript, HTML, CSS',
            Status__c = 'Open',
            Number_of_Positions__c = 1
        );
        insert new List<Job_Requisition__c>{job1, job2};

        Candidate__c cand1 = new Candidate__c(
            Candidate_Name__c = 'Alice Smith',
            Email__c = 'alice.smith@example.com',
            Phone__c = '555-1001',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'MS in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs, NLP, LangChain',
            Candidate_Status__c = 'New'
        );

        Candidate__c cand2 = new Candidate__c(
            Candidate_Name__c = 'Bob Jones',
            Email__c = 'bob.jones@example.com',
            Phone__c = '555-1002',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 1.5,
            Highest_Qualification__c = 'BS in Information Technology',
            Skills__c = 'React, JavaScript',
            Candidate_Status__c = 'New'
        );

        Candidate__c cand3 = new Candidate__c(
            Candidate_Name__c = 'Charlie Null',
            Email__c = 'charlie.null@example.com',
            Candidate_Status__c = 'New'
        );
        insert new List<Candidate__c>{cand1, cand2, cand3};

        Job_Application__c app1 = new Job_Application__c(
            Candidate__c = cand1.Id,
            Job_Requisition__c = job1.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today()
        );

        Job_Application__c app2 = new Job_Application__c(
            Candidate__c = cand2.Id,
            Job_Requisition__c = job2.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today()
        );
        insert new List<Job_Application__c>{app1, app2};
    }

    @isTest
    static void testCalculateMatch_StrongMatch() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Email__c, Location__c, Years_of_Experience__c, Highest_Qualification__c, Skills__c FROM Candidate__c WHERE Candidate_Name__c = 'Alice Smith' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c, Experience_Required__c, Minimum_Qualification__c, Required_Skills__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-TEST' LIMIT 1];

        Test.startTest();
        RecruitmentMatchingService.MatchResult mr = RecruitmentMatchingService.calculateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, mr, 'Result should not be null');
        System.assertEquals(100.00, mr.skillPercentage, 'Should have 100% skill match');
        System.assertEquals(50.00, mr.skillScore, 'Skills score should be 50');
        System.assertEquals(25.00, mr.experienceScore, 'Experience score should be 25');
        System.assertEquals(15.00, mr.qualificationScore, 'Qualification score should be 15');
        System.assertEquals(10.00, mr.locationScore, 'Location score should be 10');
        System.assertEquals(100.00, mr.overallScore, 'Overall score should be 100');
        System.assertEquals('Strong Match', mr.fitTier, 'Tier should be Strong Match');
        System.assert(String.isNotBlank(mr.rationale), 'Rationale should be populated');
    }

    @isTest
    static void testCalculateMatch_EdgeCasesAndNulls() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Email__c, Location__c, Years_of_Experience__c, Highest_Qualification__c, Skills__c FROM Candidate__c WHERE Candidate_Name__c = 'Charlie Null' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c, Experience_Required__c, Minimum_Qualification__c, Required_Skills__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-TEST' LIMIT 1];

        Test.startTest();
        RecruitmentMatchingService.MatchResult mr = RecruitmentMatchingService.calculateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, mr, 'Result should not be null');
        System.assertEquals(0.00, mr.skillPercentage, 'Skill match should be 0');
        System.assertEquals(0.00, mr.experienceScore, 'Experience score should be 0');
        System.assertEquals('Low Match', mr.fitTier, 'Fit tier should be Low Match');
        System.assert(mr.missingSkills.size() > 0, 'Missing skills should be listed');
    }

    @isTest
    static void testCalculateMatch_SynonymsAndRemote() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Email__c, Location__c, Years_of_Experience__c, Highest_Qualification__c, Skills__c FROM Candidate__c WHERE Candidate_Name__c = 'Bob Jones' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c, Experience_Required__c, Minimum_Qualification__c, Required_Skills__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-FE-TEST' LIMIT 1];

        Test.startTest();
        RecruitmentMatchingService.MatchResult mr = RecruitmentMatchingService.calculateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, mr, 'Result should not be null');
        System.assertEquals(10.00, mr.locationScore, 'Remote job should grant full 10 location points');
        System.assert(mr.matchedSkills.contains('React'), 'React should be matched');
        System.assert(mr.matchedSkills.contains('JavaScript'), 'JavaScript should be matched');
        System.assert(mr.missingSkills.contains('HTML'), 'HTML should be missing');
        System.assert(mr.missingSkills.contains('CSS'), 'CSS should be missing');
    }

    @isTest
    static void testMatchCandidatesToJob() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-TEST' LIMIT 1];

        Test.startTest();
        List<RecruitmentMatchingService.MatchResult> results = RecruitmentMatchingService.matchCandidatesToJob(job.Id, 2);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return top 2 candidates');
        System.assertEquals('Alice Smith', results[0].candidateName, 'Alice Smith should be top match');
        System.assert(results[0].overallScore >= results[1].overallScore, 'Results should be sorted descending');
    }

    @isTest
    static void testMatchJobsToCandidate() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Alice Smith' LIMIT 1];

        Test.startTest();
        List<RecruitmentMatchingService.MatchResult> results = RecruitmentMatchingService.matchJobsToCandidate(cand.Id, 5);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Results should not be empty');
        System.assertEquals('REQ-AI-TEST', results[0].jobCode, 'AI job should be top match for Alice');
    }

    @isTest
    static void testEvaluateApplicationsAndPersist() {
        Test.startTest();
        List<RecruitmentMatchingService.MatchResult> results = RecruitmentMatchingService.evaluateApplications(null, true);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should evaluate 2 applications');

        Job_Application__c updatedApp = [SELECT Id, Match_Score__c, Skill_Match_Percentage__c, Match_Rationale__c, Missing_Skills__c, Application_Status__c FROM Job_Application__c WHERE Candidate__r.Candidate_Name__c = 'Alice Smith' LIMIT 1];
        System.assertNotEquals(null, updatedApp.Match_Score__c, 'Match score should be persisted');
        System.assertEquals(100.00, updatedApp.Match_Score__c, 'Score should be 100');
        System.assertEquals(100.00, updatedApp.Skill_Match_Percentage__c, 'Skill pct should be 100');
        System.assert(String.isNotBlank(updatedApp.Match_Rationale__c), 'Rationale should be persisted');
        System.assertEquals('Applied', updatedApp.Application_Status__c, 'Status must NOT be modified by matching engine');
    }
}
