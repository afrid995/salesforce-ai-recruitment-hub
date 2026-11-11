@isTest
private class RecruitmentInvocableActionsTest {

    @testSetup
    static void setupData() {
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'AI/ML Engineer',
            Job_Code__c = 'REQ-INV-001',
            Department__c = 'Artificial Intelligence',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 3,
            Minimum_Qualification__c = 'Bachelor in Computer Science',
            Required_Skills__c = 'Python, PyTorch',
            Status__c = 'Open',
            Number_of_Positions__c = 2
        );
        insert job;

        Candidate__c cand = new Candidate__c(
            Candidate_Name__c = 'Alex Morgan',
            Email__c = 'alex.morgan@example.com',
            Phone__c = '555-0101',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 4.5,
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

        Interview__c inv = new Interview__c(
            Candidate__c = cand.Id,
            Job_Application__c = app.Id,
            Interview_Name__c = 'Technical Interview 1',
            Interview_Date__c = DateTime.now().addDays(2),
            Interview_Type__c = 'Technical',
            Interview_Status__c = 'Scheduled'
        );
        insert inv;
    }

    @isTest
    static void testSearchCandidates() {
        RecruitmentSearchCandidatesAction.Request req1 = new RecruitmentSearchCandidatesAction.Request();
        req1.skills = 'Python';
        req1.minExperience = 2;
        req1.candidateName = 'Alex';
        req1.status = 'New';

        Test.startTest();
        List<RecruitmentSearchCandidatesAction.Response> res1 = RecruitmentSearchCandidatesAction.searchCandidates(new List<RecruitmentSearchCandidatesAction.Request>{req1});

        RecruitmentSearchCandidatesAction.Request reqNotFound = new RecruitmentSearchCandidatesAction.Request();
        reqNotFound.candidateName = 'Nonexistent Candidate';
        List<RecruitmentSearchCandidatesAction.Response> resNotFound = RecruitmentSearchCandidatesAction.searchCandidates(new List<RecruitmentSearchCandidatesAction.Request>{reqNotFound});
        Test.stopTest();

        System.assertEquals(1, res1.size());
        System.assertEquals(1, res1[0].totalFound);
        System.assert(res1[0].result.contains('Alex Morgan'));

        System.assertEquals(0, resNotFound[0].totalFound);
        System.assert(resNotFound[0].result.contains('No candidate found'));
    }

    @isTest
    static void testSearchJobs() {
        RecruitmentSearchJobsAction.Request req1 = new RecruitmentSearchJobsAction.Request();
        req1.searchTerm = 'AI/ML';
        req1.department = 'Intelligence';

        Test.startTest();
        List<RecruitmentSearchJobsAction.Response> res1 = RecruitmentSearchJobsAction.searchJobs(new List<RecruitmentSearchJobsAction.Request>{req1});

        RecruitmentSearchJobsAction.Request reqNotFound = new RecruitmentSearchJobsAction.Request();
        reqNotFound.searchTerm = 'Astronaut';
        List<RecruitmentSearchJobsAction.Response> resNotFound = RecruitmentSearchJobsAction.searchJobs(new List<RecruitmentSearchJobsAction.Request>{reqNotFound});
        Test.stopTest();

        System.assertEquals(1, res1.size());
        System.assertEquals(1, res1[0].totalFound);
        System.assert(res1[0].result.contains('REQ-INV-001'));

        System.assertEquals(0, resNotFound[0].totalFound);
        System.assert(resNotFound[0].result.contains('No open job requisitions found'));
    }

    @isTest
    static void testSearchApplications() {
        RecruitmentSearchApplicationsAction.Request req1 = new RecruitmentSearchApplicationsAction.Request();
        req1.candidateName = 'Alex';
        req1.jobTitleOrCode = 'AI/ML';
        req1.applicationStatus = 'Applied';

        Test.startTest();
        List<RecruitmentSearchApplicationsAction.Response> res1 = RecruitmentSearchApplicationsAction.searchApplications(new List<RecruitmentSearchApplicationsAction.Request>{req1});

        RecruitmentSearchApplicationsAction.Request reqNotFound = new RecruitmentSearchApplicationsAction.Request();
        reqNotFound.candidateName = 'No One';
        List<RecruitmentSearchApplicationsAction.Response> resNotFound = RecruitmentSearchApplicationsAction.searchApplications(new List<RecruitmentSearchApplicationsAction.Request>{reqNotFound});
        Test.stopTest();

        System.assertEquals(1, res1.size());
        System.assertEquals(1, res1[0].totalFound);
        System.assert(res1[0].result.contains('Alex Morgan'));

        System.assertEquals(0, resNotFound[0].totalFound);
        System.assert(resNotFound[0].result.contains('No job application found'));
    }

    @isTest
    static void testGetInterviews() {
        RecruitmentGetInterviewsAction.Request req1 = new RecruitmentGetInterviewsAction.Request();
        req1.statusFilter = 'scheduled';

        Test.startTest();
        List<RecruitmentGetInterviewsAction.Response> res1 = RecruitmentGetInterviewsAction.getInterviews(new List<RecruitmentGetInterviewsAction.Request>{req1});

        RecruitmentGetInterviewsAction.Request reqAll = new RecruitmentGetInterviewsAction.Request();
        reqAll.statusFilter = 'all';
        List<RecruitmentGetInterviewsAction.Response> resAll = RecruitmentGetInterviewsAction.getInterviews(new List<RecruitmentGetInterviewsAction.Request>{reqAll});

        RecruitmentGetInterviewsAction.Request reqNotFound = new RecruitmentGetInterviewsAction.Request();
        reqNotFound.statusFilter = 'Completed';
        List<RecruitmentGetInterviewsAction.Response> resNotFound = RecruitmentGetInterviewsAction.getInterviews(new List<RecruitmentGetInterviewsAction.Request>{reqNotFound});
        Test.stopTest();

        System.assertEquals(1, res1.size());
        System.assertEquals(1, res1[0].totalFound);
        System.assert(res1[0].result.contains('Technical Interview 1'));

        System.assertEquals(1, resAll[0].totalFound);
        System.assertEquals(0, resNotFound[0].totalFound);
    }

    @isTest
    static void testPipelineSummary() {
        RecruitmentPipelineSummaryAction.Request req = new RecruitmentPipelineSummaryAction.Request();
        req.triggerText = 'summary';

        Test.startTest();
        List<RecruitmentPipelineSummaryAction.Response> res = RecruitmentPipelineSummaryAction.getPipelineSummary(new List<RecruitmentPipelineSummaryAction.Request>{req});
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assert(String.isNotBlank(res[0].result));
        System.assert(res[0].result.contains('Recruitment Pipeline Summary'));
        System.assert(res[0].result.contains('Job Requisitions'));
    }
}
