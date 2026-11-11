@IsTest
private class CandidateComparisonControllerTest {

    @TestSetup
    static void setupTestData() {
        Job_Requisition__c job1 = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-AIML-001',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Master of Science in Computer Science / AI',
            Required_Skills__c = 'Python, PyTorch, TensorFlow, LLMs, LangChain, Agentforce'
        );
        insert job1;

        Job_Requisition__c job2 = new Job_Requisition__c(
            Job_Title__c = 'Cloud Architect',
            Job_Code__c = 'REQ-CA-002',
            Department__c = 'IT',
            Status__c = 'Open',
            Location__c = 'Austin, TX',
            Experience_Required__c = 5.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'AWS, Kubernetes, Terraform'
        );
        insert job2;

        List<Candidate__c> candidates = new List<Candidate__c>();
        // Candidate 1: Alex Morgan (Strong AI skills)
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.morgan@test.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'Master of Science in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs, Agentforce'
        ));

        // Candidate 2: Carlos Ray (Different skills)
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Carlos Ray',
            Email__c = 'carlos.ray@test.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 4.5,
            Highest_Qualification__c = 'Master of Science in Computer Science',
            Skills__c = 'Python, TensorFlow, LangChain, REST APIs'
        ));

        // Candidate 3: Fiona Gallagher
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Fiona Gallagher',
            Email__c = 'fiona.g@test.com',
            Location__c = 'Boston, MA',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'Bachelor of Science in Information Technology',
            Skills__c = 'Python, PyTorch'
        ));

        // Candidate 4: David Kim
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'David Kim',
            Email__c = 'david.kim@test.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 3.0,
            Highest_Qualification__c = 'Master of Science',
            Skills__c = 'Python, LLMs'
        ));

        // Candidate 5: Elena Rostova
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Elena Rostova',
            Email__c = 'elena.r@test.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 4.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'Python, TensorFlow'
        ));

        // Candidate 6: Frank Castle (6th candidate for testing > 5 limit)
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Frank Castle',
            Email__c = 'frank.c@test.com',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 6.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'Python'
        ));

        // Candidate 7: Unrelated candidate with no skills
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Grace Hopper',
            Email__c = 'grace.h@test.com',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 0.0,
            Highest_Qualification__c = '',
            Skills__c = ''
        ));

        insert candidates;

        // Evaluate job1 against candidates 1 to 6
        for (Integer i = 0; i < 6; i++) {
            CandidateJobMatchService.evaluateAndSaveMatch(candidates[i].Id, job1.Id);
        }

        // Evaluate job2 against Candidate 1 (to test cross-job validation)
        CandidateJobMatchService.evaluateAndSaveMatch(candidates[0].Id, job2.Id);

        // Also create a sample application to verify application status is NEVER altered
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidates[0].Id,
            Job_Requisition__c = job1.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today()
        );
        insert app;
    }

    @IsTest
    static void testTwoCandidateComparison() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 2
        ];

        Test.startTest();
        CandidateComparisonController.ComparisonResultDTO res = CandidateComparisonController.getComparisonData(
            job.Id,
            new List<Id>{ matches[0].Id, matches[1].Id }
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(2, res.candidates.size(), 'Should return 2 candidates');
        System.assertNotEquals(null, res.highestScoreText, 'Highest score text should be populated');
        System.assertNotEquals(null, res.skillMatrix, 'Skill matrix should be generated');
        System.assert(res.responsibleAiNotice.contains('explicit job-relevant criteria'), 'Responsible AI text must be present');
    }

    @IsTest
    static void testThreeAndFiveCandidateComparison() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 5
        ];

        Test.startTest();
        // 3 Candidates
        CandidateComparisonController.ComparisonResultDTO res3 = CandidateComparisonController.getComparisonData(
            job.Id,
            new List<Id>{ matches[0].Id, matches[1].Id, matches[2].Id }
        );
        System.assertEquals(3, res3.candidates.size());

        // 5 Candidates
        List<Id> fiveIds = new List<Id>();
        for (Candidate_Job_Match__c m : matches) fiveIds.add(m.Id);
        CandidateComparisonController.ComparisonResultDTO res5 = CandidateComparisonController.getComparisonData(
            job.Id,
            fiveIds
        );
        System.assertEquals(5, res5.candidates.size());
        Test.stopTest();
    }

    @IsTest
    static void testMoreThanFiveCandidatesRejected() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 6
        ];

        List<Id> sixIds = new List<Id>();
        for (Candidate_Job_Match__c m : matches) sixIds.add(m.Id);

        Test.startTest();
        try {
            CandidateComparisonController.getComparisonData(job.Id, sixIds);
            System.assert(false, 'Should throw exception when more than 5 candidates are requested');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('maximum of 5 candidates') || ex instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testFewerThanTwoCandidatesRejected() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 1
        ];

        Test.startTest();
        try {
            CandidateComparisonController.getComparisonData(job.Id, new List<Id>{ matches[0].Id });
            System.assert(false, 'Should throw exception when fewer than 2 candidates are requested');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('at least 2 candidates') || ex instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testCandidateFromWrongJobRejected() {
        Job_Requisition__c job1 = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        Job_Requisition__c job2 = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-CA-002' LIMIT 1];

        Candidate_Job_Match__c matchJob1 = [SELECT Id FROM Candidate_Job_Match__c WHERE Job_Requisition__c = :job1.Id LIMIT 1];
        Candidate_Job_Match__c matchJob2 = [SELECT Id FROM Candidate_Job_Match__c WHERE Job_Requisition__c = :job2.Id LIMIT 1];

        Test.startTest();
        try {
            // Attempt to compare a match from job1 and job2 against job1
            CandidateComparisonController.getComparisonData(job1.Id, new List<Id>{ matchJob1.Id, matchJob2.Id });
            System.assert(false, 'Should throw exception when candidate from wrong job is included');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('must belong to the selected job requisition') || ex instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testMissingMatchRecordHandled() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        Candidate__c candEvaluated = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Alex Morgan' LIMIT 1];
        Candidate__c candMissing = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Grace Hopper' LIMIT 1];

        Test.startTest();
        try {
            CandidateComparisonController.getComparisonByCandidateIds(job.Id, new List<Id>{ candEvaluated.Id, candMissing.Id });
            System.assert(false, 'Should throw exception stating match evaluation is not available');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Match evaluation not available') || ex instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testTiedHighestScoreIdentification() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id, Overall_Match_Score__c FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 2
        ];

        // Force a tie for testing
        matches[0].Overall_Match_Score__c = 80.00;
        matches[1].Overall_Match_Score__c = 80.00;
        update matches;

        Test.startTest();
        CandidateComparisonController.ComparisonResultDTO res = CandidateComparisonController.getComparisonData(
            job.Id,
            new List<Id>{ matches[0].Id, matches[1].Id }
        );
        Test.stopTest();

        System.assertEquals(true, res.isHighestScoreTied, 'Tie must be identified');
        System.assert(res.highestScoreText.contains('Tied'), 'Tie label must be used');
        System.assert(res.highestScoreText.startsWith('Highest Match Score'), 'Must use Highest Match Score phrasing');
        System.assertEquals(true, res.candidates[0].isHighestScore);
        System.assertEquals(true, res.candidates[1].isHighestScore);
    }

    @IsTest
    static void testSkillMatrixDifferencesAndEmptySkills() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        Candidate__c candAlex = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Alex Morgan' LIMIT 1];
        Candidate__c candCarlos = [SELECT Id FROM Candidate__c WHERE Candidate_Name__c = 'Carlos Ray' LIMIT 1];

        Candidate_Job_Match__c matchAlex = [SELECT Id FROM Candidate_Job_Match__c WHERE Job_Requisition__c = :job.Id AND Candidate__c = :candAlex.Id LIMIT 1];
        Candidate_Job_Match__c matchCarlos = [SELECT Id FROM Candidate_Job_Match__c WHERE Job_Requisition__c = :job.Id AND Candidate__c = :candCarlos.Id LIMIT 1];

        Test.startTest();
        CandidateComparisonController.ComparisonResultDTO res = CandidateComparisonController.getComparisonData(
            job.Id,
            new List<Id>{ matchAlex.Id, matchCarlos.Id }
        );
        Test.stopTest();

        System.assertNotEquals(null, res.skillMatrix);
        System.assert(!res.skillMatrix.rows.isEmpty(), 'Skill matrix rows should be populated with required skills');

        // Check cross-candidate skill presence
        Boolean foundDifferentiatingSkill = false;
        for (CandidateComparisonController.SkillMatrixRowDTO row : res.skillMatrix.rows) {
            Boolean hasAlex = false;
            Boolean hasCarlos = false;
            for (CandidateComparisonController.SkillCellDTO cell : row.cells) {
                if (cell.candidateName == 'Alex Morgan' && cell.hasSkill) hasAlex = true;
                if (cell.candidateName == 'Carlos Ray' && cell.hasSkill) hasCarlos = true;
            }
            if (hasAlex != hasCarlos) {
                foundDifferentiatingSkill = true;
            }
        }
        System.assert(foundDifferentiatingSkill, 'Should identify differentiating skills (e.g. PyTorch vs TensorFlow)');
    }

    @IsTest
    static void testInvocableActionAndAgentforceSupport() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 2
        ];

        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.jobId = job.Id;
        req.matchIds = new List<Id>{ matches[0].Id, matches[1].Id };

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertNotEquals(null, results[0].comparisonSummary);
        System.assertNotEquals(null, results[0].skillDifferences);
        System.assertNotEquals(null, results[0].experienceComparison);
        System.assertNotEquals(null, results[0].factorBreakdown);
    }

    @IsTest
    static void testInvocableActionWithCandidateNamesAndJobTitle() {
        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.jobTitle = 'AI/ML Engineer';
        req.candidateNames = 'Alex Morgan, Carlos Ray, and Fiona Gallagher';

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals('Alex Morgan', results[0].highestScoreCandidate);
        System.assert(results[0].comparisonSummary.contains('Alex Morgan'));
        System.assert(results[0].comparisonSummary.contains('Carlos Ray'));
        System.assert(results[0].comparisonSummary.contains('Fiona Gallagher'));
        System.assertNotEquals(null, results[0].skillDifferences);
        System.assertNotEquals(null, results[0].factorBreakdown);
    }

    @IsTest
    static void testInvocableActionWithTopN() {
        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.jobTitle = 'REQ-AIML-001';
        req.topN = 3;

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals('Alex Morgan', results[0].highestScoreCandidate);
        System.assertNotEquals(null, results[0].comparisonSummary);
    }

    @IsTest
    static void testInvocableActionSingleCandidateFallback() {
        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.jobTitle = 'AI/ML Engineer';
        req.candidateNames = 'Alex Morgan';

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals('Alex Morgan', results[0].highestScoreCandidate);
    }

    @IsTest
    static void testInvocableActionOmittedJobTitleInferred() {
        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.candidateNames = 'Alex Morgan and Carlos Ray';

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals('Alex Morgan', results[0].highestScoreCandidate);
    }

    @IsTest
    static void testInvocableActionInvalidJob() {
        CandidateComparisonAction.CompareRequest req = new CandidateComparisonAction.CompareRequest();
        req.jobTitle = 'Nonexistent Job 9999';
        // No candidates provided so cannot infer
        req.matchIds = null;
        req.candidateIds = null;
        req.candidateNames = null;

        Test.startTest();
        List<CandidateComparisonAction.CompareResult> results = CandidateComparisonAction.compare(
            new List<CandidateComparisonAction.CompareRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess);
    }

    @IsTest
    static void testNoStatusMutationIntegrity() {
        Job_Application__c appBefore = [SELECT Id, Application_Status__c FROM Job_Application__c LIMIT 1];
        System.assertEquals('Applied', appBefore.Application_Status__c);

        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-AIML-001' LIMIT 1];
        List<Candidate_Job_Match__c> matches = [
            SELECT Id FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :job.Id
            LIMIT 2
        ];

        Test.startTest();
        CandidateComparisonController.getComparisonData(job.Id, new List<Id>{ matches[0].Id, matches[1].Id });
        Test.stopTest();

        Job_Application__c appAfter = [SELECT Id, Application_Status__c FROM Job_Application__c WHERE Id = :appBefore.Id];
        System.assertEquals('Applied', appAfter.Application_Status__c, 'Application status MUST NOT be altered by comparison');
    }
}
