/**
 * @description Comprehensive test suite for RecruitmentIntelligenceController.
 * Verifies KPI calculations, pipeline stage metrics, job health rollups,
 * match coverage summaries, skill gap aggregation, interview datetime filtering,
 * recruiter attention alerts, multi-dimensional filtering, bulk performance,
 * and confirms ZERO mutation of candidate or application records.
 */
@IsTest
private class RecruitmentIntelligenceControllerTest {

    @TestSetup
    static void setupTestData() {
        // 1. Create Job Requisitions with valid picklist values
        List<Job_Requisition__c> jobs = new List<Job_Requisition__c>();
        
        // Job 1: Artificial Intelligence Open, 3 positions
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-TEST-001',
            Department__c = 'Artificial Intelligence',
            Status__c = 'Open',
            Number_of_Positions__c = 3,
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 4.0,
            Minimum_Qualification__c = 'Master of Science',
            Required_Skills__c = 'Python, PyTorch, REST APIs, Docker'
        ));

        // Job 2: Software Development Open, 2 positions
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'Full Stack Developer',
            Job_Code__c = 'REQ-TEST-002',
            Department__c = 'Software Development',
            Status__c = 'Open',
            Number_of_Positions__c = 2,
            Location__c = 'Austin, TX',
            Experience_Required__c = 3.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'JavaScript, React, Node.js, Docker, TypeScript'
        ));

        // Job 3: Data Science Closed, 1 position
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'Data Analyst',
            Job_Code__c = 'REQ-TEST-003',
            Department__c = 'Data Science',
            Status__c = 'Closed',
            Closing_Date__c = Date.today(),
            Number_of_Positions__c = 1,
            Location__c = 'Remote',
            Experience_Required__c = 2.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'SQL, Tableau, Excel'
        ));

        // Job 4: IT Open, 4 positions, 0 applications, 0 matches (for empty state and attention alerts)
        jobs.add(new Job_Requisition__c(
            Job_Title__c = 'DevOps Engineer',
            Job_Code__c = 'REQ-TEST-004',
            Department__c = 'IT',
            Status__c = 'Open',
            Number_of_Positions__c = 4,
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 5.0,
            Minimum_Qualification__c = 'Bachelor of Science',
            Required_Skills__c = 'AWS, Kubernetes, Terraform'
        ));

        insert jobs;

        // 2. Create Candidates
        List<Candidate__c> candidates = new List<Candidate__c>();
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Alice Smith',
            Email__c = 'alice.smith@testrec.com',
            Candidate_Status__c = 'Selected',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 5.0,
            Highest_Qualification__c = 'Master of Science',
            Skills__c = 'Python, PyTorch, Docker'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Bob Jones',
            Email__c = 'bob.jones@testrec.com',
            Candidate_Status__c = 'Interviewing',
            Location__c = 'Austin, TX',
            Years_of_Experience__c = 3.5,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'JavaScript, React, Node.js'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Charlie Brown',
            Email__c = 'charlie.brown@testrec.com',
            Candidate_Status__c = 'Shortlisted',
            Location__c = 'Remote',
            Years_of_Experience__c = 2.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'SQL, Tableau'
        ));
        candidates.add(new Candidate__c(
            Candidate_Name__c = 'Diana Prince',
            Email__c = 'diana.prince@testrec.com',
            Candidate_Status__c = 'New',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 1.0,
            Highest_Qualification__c = 'Bachelor of Science',
            Skills__c = 'Python'
        ));

        insert candidates;

        // 3. Create Applications
        List<Job_Application__c> apps = new List<Job_Application__c>();
        // Apps for Job 1
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[0].Id,
            Application_Status__c = 'Selected',
            Application_Date__c = Date.today().addDays(-10)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[1].Id,
            Application_Status__c = 'Interviewed',
            Application_Date__c = Date.today().addDays(-8)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[2].Id,
            Application_Status__c = 'Shortlisted',
            Application_Date__c = Date.today().addDays(-6)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[0].Id,
            Candidate__c = candidates[3].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-2)
        ));

        // Apps for Job 2
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[1].Id,
            Candidate__c = candidates[1].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-5)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[1].Id,
            Candidate__c = candidates[2].Id,
            Application_Status__c = 'Under Review',
            Application_Date__c = Date.today().addDays(-4)
        ));
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[1].Id,
            Candidate__c = candidates[3].Id,
            Application_Status__c = 'Interview Scheduled',
            Application_Date__c = Date.today().addDays(-3)
        ));

        // App for Job 3
        apps.add(new Job_Application__c(
            Job_Requisition__c = jobs[2].Id,
            Candidate__c = candidates[0].Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today().addDays(-1)
        ));

        insert apps;

        // 4. Create Candidate_Job_Match__c records directly
        List<Candidate_Job_Match__c> matches = new List<Candidate_Job_Match__c>();
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[0].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 88.00,
            Skill_Match_Percent__c = 90.00,
            Experience_Match_Percent__c = 100.00,
            Recommendation__c = 'Strong Match',
            Missing_Skills__c = 'REST APIs, Docker'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[1].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 72.00,
            Skill_Match_Percent__c = 70.00,
            Experience_Match_Percent__c = 85.00,
            Recommendation__c = 'Moderate Match',
            Missing_Skills__c = 'REST APIs, Kubernetes'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[2].Id,
            Job_Requisition__c = jobs[0].Id,
            Overall_Match_Score__c = 45.00,
            Skill_Match_Percent__c = 40.00,
            Experience_Match_Percent__c = 50.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'Python, REST APIs'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[1].Id,
            Job_Requisition__c = jobs[1].Id,
            Overall_Match_Score__c = 68.00,
            Skill_Match_Percent__c = 65.00,
            Experience_Match_Percent__c = 80.00,
            Recommendation__c = 'Moderate Match',
            Missing_Skills__c = 'Docker, TypeScript'
        ));
        matches.add(new Candidate_Job_Match__c(
            Candidate__c = candidates[2].Id,
            Job_Requisition__c = jobs[1].Id,
            Overall_Match_Score__c = 35.00,
            Skill_Match_Percent__c = 30.00,
            Experience_Match_Percent__c = 50.00,
            Recommendation__c = 'Low Match',
            Missing_Skills__c = 'Docker, Python, Apex'
        ));

        insert matches;

        // 5. Create Interviews (DateTime semantics)
        List<Interview__c> interviews = new List<Interview__c>();
        // Future scheduled interview (upcoming)
        interviews.add(new Interview__c(
            Interview_Name__c = 'Technical Round 1',
            Job_Application__c = apps[6].Id, // Diana Prince, Job 2
            Candidate__c = candidates[3].Id,
            Interview_Date__c = Datetime.now().addDays(3),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        ));

        // Past scheduled interview (overdue attention item)
        interviews.add(new Interview__c(
            Interview_Name__c = 'HR Discussion',
            Job_Application__c = apps[1].Id, // Bob Jones, Job 1
            Candidate__c = candidates[1].Id,
            Interview_Date__c = Datetime.now().addDays(-2),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'HR'
        ));

        // Past completed interview
        interviews.add(new Interview__c(
            Interview_Name__c = 'Screening Call',
            Job_Application__c = apps[1].Id, // Bob Jones, Job 1
            Candidate__c = candidates[1].Id,
            Interview_Date__c = Datetime.now().addDays(-4),
            Interview_Status__c = 'Completed',
            Interview_Type__c = 'Phone'
        ));

        insert interviews;
    }

    @IsTest
    static void testGetDashboardDataUnfiltered() {
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, data, 'DashboardData should not be null');

        // Verify KPIs
        System.assertNotEquals(null, data.kpis, 'KPIs should not be null');
        System.assertEquals(3, data.kpis.openJobs, 'Should count 3 open jobs');
        System.assertEquals(4, data.kpis.totalCandidates, 'Should count 4 total candidates');
        System.assertEquals(8, data.kpis.totalApplications, 'Should count 8 total applications');
        System.assertEquals(1, data.kpis.shortlistedApplications, 'Should count 1 shortlisted application');
        System.assertEquals(1, data.kpis.interviewedApplications, 'Should count 1 interviewed application');
        System.assertEquals(1, data.kpis.selectedCandidates, 'Should count 1 selected candidate');
        System.assertEquals(1, data.kpis.upcomingInterviews, 'Should count 1 upcoming interview');
        System.assertEquals(61.60, data.kpis.averageCandidateMatchScore, 'Avg match score should be 61.60%');

        // Verify Pipeline Stages
        System.assertEquals(6, data.pipelineStages.size(), 'Should return all 6 pipeline stages');
        for (RecruitmentIntelligenceController.PipelineStageMetric stage : data.pipelineStages) {
            System.assertNotEquals(null, stage.stageName);
            System.assertNotEquals(null, stage.count);
            System.assertNotEquals(null, stage.percentage);
            System.assertNotEquals(null, stage.colorClass);
        }

        // Verify Job Health Table
        System.assertEquals(4, data.jobHealthTable.size(), 'Should return all 4 jobs in health table');
        for (RecruitmentIntelligenceController.JobHealthRow row : data.jobHealthTable) {
            if (row.jobCode == 'REQ-TEST-001') {
                System.assertEquals('AI/ML Engineer', row.jobTitle);
                System.assertEquals(4, row.applicationCount, 'Job 1 has 4 applications');
                System.assertEquals(4, row.candidateCount, 'Job 1 has 4 candidates');
                System.assertEquals(true, row.hasEvaluations);
                System.assertEquals('Evaluated', row.matchStatusText);
                System.assertEquals(88.00, row.highestMatchScore);
                System.assertEquals('Alice Smith', row.highestMatchCandidateName);
                System.assertEquals(1, row.strongMatchCount);
            } else if (row.jobCode == 'REQ-TEST-004') {
                System.assertEquals(false, row.hasEvaluations);
                System.assertEquals('Match evaluation unavailable', row.matchStatusText);
                System.assertEquals(0.00, row.averageMatchScore);
                System.assertEquals(0, row.applicationCount);
            }
        }

        // Verify Match Coverage
        System.assertEquals(5, data.matchCoverage.totalEvaluatedMatches);
        System.assertEquals(1, data.matchCoverage.totalStrongMatches); // 88.00
        System.assertEquals(2, data.matchCoverage.totalGoodMatches);   // 72.00, 68.00
        System.assertEquals(0, data.matchCoverage.totalModerateMatches);
        System.assertEquals(2, data.matchCoverage.totalLowMatches);    // 45.00, 35.00
        System.assert(data.matchCoverage.strongestJobs.size() > 0);
        System.assert(data.matchCoverage.weakestJobs.size() > 0);

        // Verify Skill Gaps
        System.assert(data.skillGaps.size() > 0, 'Skill gaps should be aggregated');
        // Top skill gap should have highest gap count
        System.assert(data.skillGaps[0].gapCount >= data.skillGaps[data.skillGaps.size() - 1].gapCount);

        // Verify Interview Bottlenecks
        System.assertEquals(1, data.interviewBottlenecks.upcomingCount);
        System.assertEquals(1, data.interviewBottlenecks.attentionCount); // 1 overdue
        System.assertEquals(1, data.interviewBottlenecks.completedCount);
        System.assertEquals(2, data.interviewBottlenecks.scheduledCount);
        System.assertEquals(1, data.interviewBottlenecks.upcomingInterviewsList.size());
        System.assertEquals(false, data.interviewBottlenecks.upcomingInterviewsList[0].isOverdue);
        System.assertEquals(1, data.interviewBottlenecks.attentionInterviewsList.size());
        System.assertEquals(true, data.interviewBottlenecks.attentionInterviewsList[0].isOverdue);

        // Verify Recruiter Attention Items
        System.assert(data.recruiterAttentionItems.size() > 0, 'Should generate attention items');
        for (RecruitmentIntelligenceController.AttentionItem item : data.recruiterAttentionItems) {
            System.assert(item.description.contains('Requires recruiter review.'), 'Must include responsible AI standard review phrasing');
            System.assertNotEquals(null, item.severity);
            System.assertNotEquals(null, item.category);
            System.assertNotEquals(null, item.title);
        }

        // Verify Filter Options populated
        System.assert(data.filterOptions.jobs.size() >= 5); // All Jobs + 4 test jobs
        System.assert(data.filterOptions.departments.size() >= 3); // Artificial Intelligence, Software Development, etc.
    }

    @IsTest
    static void testFilterByJobId() {
        Job_Requisition__c targetJob = [SELECT Id FROM Job_Requisition__c WHERE Job_Code__c = 'REQ-TEST-001' LIMIT 1];

        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            targetJob.Id, null, null, null, null
        );
        Test.stopTest();

        System.assertEquals(1, data.jobHealthTable.size(), 'Should filter table to only 1 job');
        System.assertEquals(targetJob.Id, data.jobHealthTable[0].jobId);
        System.assertEquals(4, data.kpis.totalApplications, 'Should only count apps for Job 1');
        System.assertEquals(3, data.matchCoverage.totalEvaluatedMatches, 'Should only count matches for Job 1');
    }

    @IsTest
    static void testFilterByDepartment() {
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, 'Data Science', null, null, null
        );
        Test.stopTest();

        System.assertEquals(1, data.jobHealthTable.size());
        System.assertEquals('Data Science', data.jobHealthTable[0].department);
        System.assertEquals(1, data.kpis.totalApplications);
    }

    @IsTest
    static void testFilterByJobStatus() {
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, null, 'Closed', null, null
        );
        Test.stopTest();

        System.assertEquals(1, data.jobHealthTable.size());
        System.assertEquals('Closed', data.jobHealthTable[0].status);
    }

    @IsTest
    static void testFilterByApplicationStatus() {
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, null, null, 'Selected', null
        );
        Test.stopTest();

        System.assertEquals(1, data.kpis.totalApplications, 'Should return only 1 application with Selected status');
    }

    @IsTest
    static void testFilterByRecommendationTier() {
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, null, null, null, 'Strong Match'
        );
        Test.stopTest();

        System.assertEquals(1, data.matchCoverage.totalEvaluatedMatches, 'Should return only 1 Strong Match record');
        System.assertEquals(88.00, data.kpis.averageCandidateMatchScore);
    }

    @IsTest
    static void testFilterWithNoResults() {
        // Query non-existent department
        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, 'Human Resources', null, null, null
        );
        Test.stopTest();

        System.assertEquals(0, data.jobHealthTable.size(), 'Should return 0 jobs');
        System.assertEquals(0, data.kpis.openJobs);
        System.assertEquals(0, data.kpis.totalApplications);
        System.assertEquals(0.00, data.kpis.averageCandidateMatchScore);
    }

    @IsTest
    static void testZeroMutationOfCandidateAndApplicationRecords() {
        // Capture initial statuses
        Map<Id, String> candidateInitialStatus = new Map<Id, String>();
        for (Candidate__c c : [SELECT Id, Candidate_Status__c FROM Candidate__c]) {
            candidateInitialStatus.put(c.Id, c.Candidate_Status__c);
        }

        Map<Id, String> appInitialStatus = new Map<Id, String>();
        for (Job_Application__c a : [SELECT Id, Application_Status__c FROM Job_Application__c]) {
            appInitialStatus.put(a.Id, a.Application_Status__c);
        }

        Test.startTest();
        // Invoke dashboard
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, null, null, null, null
        );
        Test.stopTest();

        // Verify candidate statuses unchanged
        for (Candidate__c c : [SELECT Id, Candidate_Status__c FROM Candidate__c]) {
            System.assertEquals(
                candidateInitialStatus.get(c.Id),
                c.Candidate_Status__c,
                'Candidate status must NEVER be modified by RecruitmentIntelligenceController'
            );
        }

        // Verify application statuses unchanged
        for (Job_Application__c a : [SELECT Id, Application_Status__c FROM Job_Application__c]) {
            System.assertEquals(
                appInitialStatus.get(a.Id),
                a.Application_Status__c,
                'Job Application status must NEVER be modified by RecruitmentIntelligenceController'
            );
        }
    }

    @IsTest
    static void testBulkExecutionAndLimits() {
        // Add additional job requisitions to test bulk scaling
        List<Job_Requisition__c> bulkJobs = new List<Job_Requisition__c>();
        for (Integer i = 5; i <= 25; i++) {
            bulkJobs.add(new Job_Requisition__c(
                Job_Title__c = 'Bulk Job ' + i,
                Job_Code__c = 'REQ-BULK-' + i,
                Department__c = 'Software Development',
                Status__c = 'Open',
                Number_of_Positions__c = 1,
                Location__c = 'San Francisco, CA'
            ));
        }
        insert bulkJobs;

        Test.startTest();
        RecruitmentIntelligenceController.DashboardData data = RecruitmentIntelligenceController.getDashboardData(
            null, 'Software Development', null, null, null
        );
        Test.stopTest();

        System.assert(data.jobHealthTable.size() >= 21, 'Should handle bulk jobs smoothly');
        System.assert(Limits.getQueries() < Limits.getLimitQueries(), 'SOQL query count must stay well within governor limits');
    }
}
