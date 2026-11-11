@IsTest
private class CandidateJobMatchUIControllerTest {

    @TestSetup
    static void setupTestData() {
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-AIML-001',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Master of Science in Computer Science / AI',
            Required_Skills__c = 'Python, PyTorch, TensorFlow, LLMs, Agentforce'
        );
        insert job;

        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.morgan@test.com',
            Phone__c = '555-010-1001',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'Master of Science in Artificial Intelligence',
            Skills__c = 'Python, PyTorch, LLMs, Agentforce'
        );
        insert cand;

        Candidate__c cand2 = new Candidate__c(
            Candidate_Name__c = 'Jordan Lee',
            Email__c = 'jordan.lee@test.com',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 2.0,
            Highest_Qualification__c = 'Associate Degree',
            Skills__c = 'Java, C++'
        );
        insert cand2;

        // Evaluate and save matches
        CandidateJobMatchService.evaluateAndSaveMatch(cand.Id, job.Id);
        CandidateJobMatchService.evaluateAndSaveMatch(cand2.Id, job.Id);
    }

    @IsTest
    static void testGetWeightConfig() {
        Test.startTest();
        CandidateJobMatchUIController.WeightConfigDTO cfg = CandidateJobMatchUIController.getWeightConfig();
        Test.stopTest();

        System.assertNotEquals(null, cfg, 'Weight config should not be null');
        System.assert(cfg.skillWeight > 0, 'Skill weight should be > 0');
        System.assert(cfg.experienceWeight > 0, 'Experience weight should be > 0');
        System.assert(cfg.qualificationWeight > 0, 'Qualification weight should be > 0');
        System.assert(cfg.locationWeight > 0, 'Location weight should be > 0');
    }

    @IsTest
    static void testGetActiveJobs() {
        Test.startTest();
        List<Job_Requisition__c> jobs = CandidateJobMatchUIController.getActiveJobs();
        Test.stopTest();

        System.assert(!jobs.isEmpty(), 'Active jobs should be returned');
        System.assertEquals('AI/ML Engineer', jobs[0].Job_Title__c);
    }

    @IsTest
    static void testGetMatchDetail() {
        Candidate_Job_Match__c matchRec = [
            SELECT Id, Candidate__r.Candidate_Name__c, Job_Requisition__r.Job_Title__c
            FROM Candidate_Job_Match__c
            WHERE Candidate__r.Candidate_Name__c = 'Alex Morgan'
            LIMIT 1
        ];

        Test.startTest();
        CandidateJobMatchUIController.MatchDetailDTO detail = CandidateJobMatchUIController.getMatchDetail(matchRec.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Detail DTO should not be null');
        System.assertEquals('Alex Morgan', detail.candidateName);
        System.assertEquals('AI/ML Engineer', detail.jobTitle);
        System.assert(detail.overallScore > 0, 'Overall score should be > 0');
        System.assertNotEquals(null, detail.skillContribution, 'Skill contribution should be calculated');
        System.assert(!detail.matchedSkillsList.isEmpty(), 'Matched skills list should be parsed');
        System.assert(!detail.missingSkillsList.isEmpty(), 'Missing skills list should be parsed');
        System.assert(!detail.recruiterAttentionPoints.isEmpty(), 'Recruiter attention points should be derived');
        System.assert(detail.responsibleAiNotice.contains('Decision-support only'), 'Responsible AI notice should be present');
    }

    @IsTest
    static void testGetMatchesForJob() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c LIMIT 1];

        Test.startTest();
        List<CandidateJobMatchUIController.MatchSummaryDTO> matches = CandidateJobMatchUIController.getMatchesForJob(job.Id);
        Test.stopTest();

        System.assertEquals(2, matches.size(), 'Should return 2 matches for job');
        System.assertEquals(1, matches[0].rank, 'Top match should have rank 1');
        System.assert(matches[0].overallScore >= matches[1].overallScore, 'Matches should be ordered descending by score');
    }

    @IsTest
    static void testGetInitialContextWithDifferentRecordTypes() {
        Candidate_Job_Match__c matchRec = [SELECT Id FROM Candidate_Job_Match__c LIMIT 1];
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c LIMIT 1];
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

        Test.startTest();
        // Context with match record ID
        CandidateJobMatchUIController.InitialContextDTO ctxMatch = CandidateJobMatchUIController.getInitialContext(matchRec.Id);
        System.assertEquals(matchRec.Id, ctxMatch.selectedMatchId);

        // Context with job record ID
        CandidateJobMatchUIController.InitialContextDTO ctxJob = CandidateJobMatchUIController.getInitialContext(job.Id);
        System.assertEquals(job.Id, ctxJob.selectedJobId);

        // Context with candidate record ID
        CandidateJobMatchUIController.InitialContextDTO ctxCand = CandidateJobMatchUIController.getInitialContext(cand.Id);
        System.assertNotEquals(null, ctxCand.selectedMatchId);

        // Context with null record ID (Home/Tab view)
        CandidateJobMatchUIController.InitialContextDTO ctxNull = CandidateJobMatchUIController.getInitialContext(null);
        System.assertNotEquals(null, ctxNull.selectedJobId);
        System.assert(!ctxNull.activeJobs.isEmpty());
        Test.stopTest();
    }

    @IsTest
    static void testRecalculateMatchAndRecalculateJobMatches() {
        Candidate_Job_Match__c matchRec = [SELECT Id, Job_Requisition__c FROM Candidate_Job_Match__c LIMIT 1];

        Test.startTest();
        CandidateJobMatchUIController.MatchDetailDTO refreshed = CandidateJobMatchUIController.recalculateMatch(matchRec.Id);
        System.assertNotEquals(null, refreshed);

        List<CandidateJobMatchUIController.MatchSummaryDTO> jobMatches = CandidateJobMatchUIController.recalculateJobMatches(matchRec.Job_Requisition__c);
        System.assert(!jobMatches.isEmpty());
        Test.stopTest();
    }

    @IsTest
    static void testParseSkillListAndDeriveAttentionPoints() {
        Test.startTest();
        List<String> parsed = CandidateJobMatchUIController.parseSkillList('Python; PyTorch, LLMs • TensorFlow\nAgentforce');
        System.assertEquals(5, parsed.size(), 'Should parse 5 skills across multiple delimiters');

        List<String> emptyParsed = CandidateJobMatchUIController.parseSkillList('None');
        System.assertEquals(0, emptyParsed.size(), 'None should parse to empty list');

        // Test attention points for a candidate with gaps
        CandidateJobMatchUIController.MatchDetailDTO gapDto = new CandidateJobMatchUIController.MatchDetailDTO();
        gapDto.missingSkillsList = new List<String>{'TensorFlow'};
        gapDto.candidateExperience = 2.0;
        gapDto.jobExperienceRequired = 5.0;
        gapDto.locationScore = 40.0;
        gapDto.candidateLocation = 'Boston, MA';
        gapDto.jobLocation = 'San Francisco, CA';
        gapDto.qualificationScore = 50.0;
        gapDto.candidateQualification = 'High School';
        gapDto.jobMinimumQualification = 'Master of Science';
        List<String> points = CandidateJobMatchUIController.deriveRecruiterAttentionPoints(gapDto);
        System.assertEquals(4, points.size(), 'Should generate 4 attention points for all gaps');

        // Test attention points for a candidate with no gaps
        CandidateJobMatchUIController.MatchDetailDTO perfectDto = new CandidateJobMatchUIController.MatchDetailDTO();
        perfectDto.missingSkillsList = new List<String>();
        perfectDto.candidateExperience = 6.0;
        perfectDto.jobExperienceRequired = 4.0;
        perfectDto.locationScore = 100.0;
        perfectDto.qualificationScore = 100.0;
        List<String> noGapPoints = CandidateJobMatchUIController.deriveRecruiterAttentionPoints(perfectDto);
        System.assertEquals(1, noGapPoints.size());
        System.assert(noGapPoints[0].contains('meets or exceeds'));
        Test.stopTest();
    }

    @IsTest
    static void testNullAndErrorHandling() {
        Test.startTest();
        System.assertEquals(null, CandidateJobMatchUIController.getMatchDetail(null));
        System.assertEquals(0, CandidateJobMatchUIController.getMatchesForJob(null).size());

        try {
            CandidateJobMatchUIController.recalculateMatch(null);
            System.assert(false, 'Should have thrown exception on null match ID');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Match ID is required') || ex instanceof AuraHandledException);
        }

        try {
            CandidateJobMatchUIController.recalculateJobMatches(null);
            System.assert(false, 'Should have thrown exception on null job ID');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Job Requisition ID is required') || ex instanceof AuraHandledException);
        }
        Test.stopTest();
    }
}
