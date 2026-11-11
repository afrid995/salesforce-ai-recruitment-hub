@isTest
private class RecruitmentHomeControllerTest {

    @isTest
    static void testRecruitmentHomeControllerWithData() {
        Job_Requisition__c job = new Job_Requisition__c(
            Job_Title__c = 'Senior AI Engineer',
            Status__c = 'Open'
        );
        insert job;

        Candidate__c candidate = new Candidate__c(
            Candidate_Name__c = 'Alice Doe',
            Email__c = 'alice.doe@example.com',
            Candidate_Status__c = 'Selected'
        );
        insert candidate;

        Job_Application__c app = new Job_Application__c(
            Name = 'APP-Test-001',
            Candidate__c = candidate.Id,
            Job_Requisition__c = job.Id,
            Application_Status__c = 'Interview Scheduled'
        );
        insert app;

        // 1. Future interview (2 days ahead) - Scheduled -> Should be included
        Interview__c interview1 = new Interview__c(
            Candidate__c = candidate.Id,
            Job_Application__c = app.Id,
            Interview_Name__c = 'Technical Assessment',
            Interview_Type__c = 'Technical',
            Interview_Status__c = 'Scheduled',
            Interview_Date__c = Datetime.now().addDays(2),
            Interviewer__c = UserInfo.getUserId()
        );
        insert interview1;

        // 2. Future interview (5 hours ahead) - Scheduled -> Should be included
        Interview__c interview2 = new Interview__c(
            Job_Application__c = app.Id,
            Interview_Name__c = 'Screening Call',
            Interview_Type__c = 'HR',
            Interview_Status__c = 'Scheduled',
            Interview_Date__c = Datetime.now().addHours(5)
        );
        insert interview2;

        // 3. Past interview (2 hours ago) - Scheduled -> Should be excluded because scheduled time has passed
        Interview__c pastHoursInterview = new Interview__c(
            Job_Application__c = app.Id,
            Interview_Name__c = 'Earlier Today Screen',
            Interview_Type__c = 'Technical',
            Interview_Status__c = 'Scheduled',
            Interview_Date__c = Datetime.now().addHours(-2)
        );
        insert pastHoursInterview;

        // 4. Past interview (3 days ago) - Scheduled -> Should be excluded because date has passed
        Interview__c pastDaysInterview = new Interview__c(
            Job_Application__c = app.Id,
            Interview_Name__c = 'Last Week Interview',
            Interview_Type__c = 'Technical',
            Interview_Status__c = 'Scheduled',
            Interview_Date__c = Datetime.now().addDays(-3)
        );
        insert pastDaysInterview;

        // 5. Future interview (1 day ahead) - Completed -> Should be excluded because status is Completed
        Interview__c completedInterview = new Interview__c(
            Job_Application__c = app.Id,
            Interview_Name__c = 'Completed Architecture Review',
            Interview_Type__c = 'Final',
            Interview_Status__c = 'Completed',
            Interview_Date__c = Datetime.now().addDays(1)
        );
        insert completedInterview;

        Test.startTest();
        RecruitmentHomeController.KpiSummary kpi = RecruitmentHomeController.getRecruitmentKpis();
        RecruitmentHomeController.ReportLinks reportLinks = RecruitmentHomeController.getReportLinks();
        List<RecruitmentHomeController.InterviewItem> interviews = RecruitmentHomeController.getUpcomingInterviews();
        Test.stopTest();

        System.assertNotEquals(null, kpi, 'KPI summary should not be null');
        System.assertEquals(1, kpi.openJobs, 'Should have 1 open job');
        System.assertEquals(1, kpi.totalCandidates, 'Should have 1 candidate');
        System.assertEquals(1, kpi.totalApplications, 'Should have 1 application');
        System.assertEquals(5, kpi.totalInterviews, 'Should have 5 interviews total regardless of status or date');
        System.assertEquals(2, kpi.upcomingInterviews, 'Should have exactly 2 upcoming interviews whose scheduled time has not passed');
        System.assertEquals(1, kpi.selectedCandidates, 'Should have 1 selected candidate');

        System.assertNotEquals(null, reportLinks, 'ReportLinks should not be null');

        System.assertNotEquals(null, interviews, 'Interviews list should not be null');
        System.assertEquals(2, interviews.size(), 'Should return only the 2 future scheduled interviews');
        System.assertEquals('Screening Call', interviews[0].name, 'First upcoming interview should be Screening Call (addHours(5))');
        System.assertEquals('Technical Assessment', interviews[1].name, 'Second upcoming interview should be Technical Assessment (addDays(2))');
    }

    @isTest(SeeAllData=true)
    static void testGetReportLinksWithOrgReports() {
        Test.startTest();
        RecruitmentHomeController.ReportLinks reportLinks = RecruitmentHomeController.getReportLinks();
        Test.stopTest();

        System.assertNotEquals(null, reportLinks, 'Report links should not be null');
    }
}
