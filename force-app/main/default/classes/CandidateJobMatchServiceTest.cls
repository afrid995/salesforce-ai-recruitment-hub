@isTest
private class CandidateJobMatchServiceTest {

    @testSetup
    static void setupData() {
        Job_Requisition__c job1 = new Job_Requisition__c(
            Job_Title__c = 'Senior AI Engineer',
            Job_Code__c = 'REQ-AI-01',
            Department__c = 'Artificial Intelligence',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Bachelor of Science in Computer Science',
            Required_Skills__c = 'Python, PyTorch, LLMs, NLP',
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Number_of_Positions__c = 2
        );

        Job_Requisition__c job2 = new Job_Requisition__c(
            Job_Title__c = 'Cloud Developer',
            Job_Code__c = 'REQ-CLOUD-02',
            Department__c = 'Software Development',
            Location__c = 'Remote',
            Experience_Required__c = 3.0,
            Minimum_Qualification__c = 'Bachelor in Information Technology',
            Required_Skills__c = 'Docker, Kubernetes, AWS, Microservices',
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Number_of_Positions__c = 1
        );
        insert new List<Job_Requisition__c>{job1, job2};

        // Candidate 1: Strong Match
        Candidate__c cand1 = new Candidate__c(
            Candidate_Name__c = 'Alice AI Expert',
            Email__c = 'alice.ai@example.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'MS in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs, NLP, LangChain',
            Candidate_Status__c = 'New'
        );

        // Candidate 2: Partial Match
        Candidate__c cand2 = new Candidate__c(
            Candidate_Name__c = 'Bob Intermediate',
            Email__c = 'bob.inter@example.com',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 3.5,
            Highest_Qualification__c = 'BS in Computer Science',
            Skills__c = 'Python, NLP',
            Candidate_Status__c = 'New'
        );

        // Candidate 3: No matching skills
        Candidate__c cand3 = new Candidate__c(
            Candidate_Name__c = 'Charlie Graphic',
            Email__c = 'charlie.g@example.com',
            Location__c = 'Seattle, WA',
            Years_of_Experience__c = 2.0,
            Highest_Qualification__c = 'Associate in Graphic Design',
            Skills__c = 'Photoshop, Illustrator, Figma',
            Candidate_Status__c = 'New'
        );

        // Candidate 4: Empty / Missing Optional Data
        Candidate__c cand4 = new Candidate__c(
            Candidate_Name__c = 'Dana Minimal',
            Email__c = 'dana.min@example.com',
            Candidate_Status__c = 'New'
        );
        insert new List<Candidate__c>{cand1, cand2, cand3, cand4};
    }

    @isTest
    static void testStrongSkillMatch() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Alice AI Expert' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, matchRec, 'Match record should be returned');
        System.assertEquals(100.00, matchRec.Skill_Match_Percent__c, 'Skills match should be 100%');
        System.assertEquals(0.00, matchRec.Skill_Gap_Percent__c, 'Skill gap should be 0%');
        System.assertEquals(100.00, matchRec.Experience_Match_Percent__c, 'Experience match should be 100%');
        System.assertEquals(100.00, matchRec.Qualification_Match_Percent__c, 'Qualification match should be 100%');
        System.assertEquals(100.00, matchRec.Location_Match_Percent__c, 'Location match should be 100%');
        System.assertEquals(100.00, matchRec.Overall_Match_Score__c, 'Overall score should be 100%');
        System.assertEquals('Strong Match', matchRec.Recommendation__c, 'Recommendation should be Strong Match');
        System.assert(matchRec.Explanation__c.contains('Decision-Support Score'), 'Explanation must frame as decision support');
        System.assert(matchRec.Explanation__c.contains('Ethical Decision-Support Guardrail'), 'Explanation must include ethical AI guardrail');
    }

    @isTest
    static void testPartialSkillMatch() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Bob Intermediate' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, matchRec);
        System.assertEquals(50.00, matchRec.Skill_Match_Percent__c, 'Should match 2 out of 4 skills = 50%');
        System.assertEquals(50.00, matchRec.Skill_Gap_Percent__c, 'Skill gap should be 50%');
        System.assert(matchRec.Matched_Skills__c.contains('Python'), 'Matched skills should contain Python');
        System.assert(matchRec.Matched_Skills__c.contains('NLP'), 'Matched skills should contain NLP');
        System.assert(matchRec.Missing_Skills__c.contains('PyTorch'), 'Missing skills should contain PyTorch');
        System.assert(matchRec.Missing_Skills__c.contains('LLMs'), 'Missing skills should contain LLMs');
    }

    @isTest
    static void testMissingSkills() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Charlie Graphic' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, matchRec);
        System.assertEquals(0.00, matchRec.Skill_Match_Percent__c, 'Skills match should be 0%');
        System.assertEquals(100.00, matchRec.Skill_Gap_Percent__c, 'Skill gap should be 100%');
        System.assertEquals('None', matchRec.Matched_Skills__c, 'Matched skills should be None');
        System.assertEquals('Low Match', matchRec.Recommendation__c, 'Recommendation should be Low Match');
    }

    @isTest
    static void testExperienceBelowRequirement() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Charlie Graphic' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assert(matchRec.Experience_Match_Percent__c <= 50.00, 'Experience 2 yrs against 4 yrs required should be <= 50%');
    }

    @isTest
    static void testExperienceAboveRequirement() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Alice AI Expert' LIMIT 1];
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertEquals(100.00, matchRec.Experience_Match_Percent__c, 'Experience 5 yrs above 4 yrs requirement should be 100%');
    }

    @isTest
    static void testCaseInsensitiveAndDelimiters() {
        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Case Insensitive Test',
            Skills__c = 'PYTHON; pytorch / LLMS, nlp',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'Bachelor in CS',
            Location__c = 'San Francisco'
        );

        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertEquals(100.00, matchRec.Skill_Match_Percent__c, 'Should handle mixed casing and semicolons/slashes seamlessly');
    }

    @isTest
    static void testEmptyAndMissingOptionalData() {
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Candidate_Name__c = 'Dana Minimal' LIMIT 1];
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'Open Role No Requirements',
            Job_Code__c = 'REQ-OPEN-01',
            Status__c = 'Open'
        );

        Test.startTest();
        Candidate_Job_Match__c matchRec = CandidateJobMatchService.evaluateMatch(cand, job);
        Test.stopTest();

        System.assertNotEquals(null, matchRec, 'Should calculate successfully with missing optional data');
        System.assertEquals(100.00, matchRec.Skill_Match_Percent__c, 'Job with no required skills gives 100% skill coverage');
        System.assertEquals(100.00, matchRec.Experience_Match_Percent__c, 'Job with no required exp gives 100% exp compatibility');
    }

    @isTest
    static void testInvalidAndUnusualData() {
        Test.startTest();
        List<String> tokens1 = CandidateJobMatchService.parseTokens(null);
        List<String> tokens2 = CandidateJobMatchService.parseTokens('   ,,, ;;; // \n \n   ');
        List<String> tokens3 = CandidateJobMatchService.parseTokens('React, ; Node.js // TypeScript \n GraphQL');
        Test.stopTest();

        System.assertEquals(0, tokens1.size());
        System.assertEquals(0, tokens2.size());
        System.assertEquals(4, tokens3.size());
        System.assertEquals('React', tokens3[0]);
        System.assertEquals('Node.js', tokens3[1]);
        System.assertEquals('TypeScript', tokens3[2]);
        System.assertEquals('GraphQL', tokens3[3]);
    }

    @isTest
    static void testMultipleCandidatesAgainstOneJob() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AI-01' LIMIT 1];

        Test.startTest();
        List<Candidate_Job_Match__c> matches = CandidateJobMatchService.evaluateCandidatesForJob(job.Id, true);
        Test.stopTest();

        System.assert(matches.size() >= 4, 'Should evaluate all 4 setup candidates');
        System.assert(matches[0].Overall_Match_Score__c >= matches[1].Overall_Match_Score__c, 'Should be sorted descending');

        // Verify persisted records
        List<Candidate_Job_Match__c> saved = [SELECT Id, Match_Key__c, Overall_Match_Score__c FROM Candidate_Job_Match__c WHERE Job_Requisition__c = :job.Id];
        System.assertEquals(matches.size(), saved.size(), 'Matches should be persisted');
    }

    @isTest
    static void testEvaluateJobsForCandidateAndAll() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Alice AI Expert' LIMIT 1];

        Test.startTest();
        List<Candidate_Job_Match__c> jobMatches = CandidateJobMatchService.evaluateJobsForCandidate(cand.Id, true);
        List<Candidate_Job_Match__c> allMatches = CandidateJobMatchService.evaluateAll(true);
        Test.stopTest();

        System.assertEquals(2, jobMatches.size(), 'Alice should be evaluated against both open jobs');
        System.assert(allMatches.size() >= 8, 'Should evaluate all candidate-job combinations');
    }

    @isTest
    static void testWeightConfiguration() {
        Test.startTest();
        CandidateJobMatchService.WeightConfig defaultCfg = CandidateJobMatchService.getWeightConfiguration();
        CandidateJobMatchService.WeightConfig customCfg = new CandidateJobMatchService.WeightConfig(40, 30, 20, 10);
        Test.stopTest();

        System.assertNotEquals(null, defaultCfg);
        System.assertEquals(50.00, defaultCfg.skillWeight);
        System.assertEquals(40.00, customCfg.skillWeight);
    }
}
