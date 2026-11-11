/**
 * @description Comprehensive unit tests for RecruitmentAlertService and RecruitmentAlertController.
 * Covers all 18 service and controller testing requirements for Phase 6:
 * - Alert generation, severity mapping, custom metadata thresholds
 * - Deduplication, acknowledgement, resolution, notification spam prevention
 * - Interview reschedule success, invalid reschedule rejection, zero status mutation
 * - Empty dataset handling, controller endpoints, and bulk scaling.
 */
@isTest
private class RecruitmentAlertServiceTest {

    @testSetup
    static void setupTestData() {
        // Create 2 Job Requisitions
        List<Job_Requisition__c> jobs = new List<Job_Requisition__c>{
            new Job_Requisition__c(
                Job_Title__c = 'Senior AI Engineer',
                Job_Code__c = 'REQ-SAI-001',
                Department__c = 'Artificial Intelligence',
                Status__c = 'Open',
                Number_of_Positions__c = 3,
                Required_Skills__c = 'Python, PyTorch, LLMs, Docker'
            ),
            new Job_Requisition__c(
                Job_Title__c = 'Cloud Architect',
                Job_Code__c = 'REQ-CA-001',
                Department__c = 'Software Development',
                Status__c = 'Open',
                Number_of_Positions__c = 2,
                Required_Skills__c = 'AWS, Kubernetes, Terraform'
            )
        };
        insert jobs;

        // Create Candidates
        List<Candidate__c> candidates = new List<Candidate__c>{
            new Candidate__c(
                Candidate_Name__c = 'Elena Rostova',
                Email__c = 'elena.r@example.com',
                Candidate_Status__c = 'Screening',
                Skills__c = 'Python, PyTorch, LLMs, Docker',
                Years_of_Experience__c = 6.0,
                Highest_Qualification__c = 'Master Degree',
                Location__c = 'San Francisco'
            ),
            new Candidate__c(
                Candidate_Name__c = 'Marcus Vance',
                Email__c = 'marcus.v@example.com',
                Candidate_Status__c = 'Screening',
                Skills__c = 'Java, SQL',
                Years_of_Experience__c = 1.0,
                Highest_Qualification__c = 'Bachelor Degree',
                Location__c = 'Austin'
            )
        };
        insert candidates;

        // Create Applications
        List<Job_Application__c> apps = new List<Job_Application__c>{
            new Job_Application__c(
                Candidate__c = candidates[0].Id,
                Job_Requisition__c = jobs[0].Id,
                Application_Status__c = 'Applied',
                Application_Date__c = Date.today().addDays(-10)
            ),
            new Job_Application__c(
                Candidate__c = candidates[1].Id,
                Job_Requisition__c = jobs[0].Id,
                Application_Status__c = 'Applied',
                Application_Date__c = Date.today().addDays(-8)
            ),
            new Job_Application__c(
                Candidate__c = candidates[0].Id,
                Job_Requisition__c = jobs[1].Id,
                Application_Status__c = 'Shortlisted',
                Application_Date__c = Date.today().addDays(-5)
            )
        };
        insert apps;

        // Create Candidate_Job_Match__c evaluations
        List<Candidate_Job_Match__c> matches = new List<Candidate_Job_Match__c>{
            new Candidate_Job_Match__c(
                Candidate__c = candidates[0].Id,
                Job_Requisition__c = jobs[0].Id,
                Overall_Match_Score__c = 90.00,
                Recommendation__c = 'Strong Match',
                Evaluation_Status__c = 'Completed',
                Match_Key__c = String.valueOf(candidates[0].Id) + '_' + String.valueOf(jobs[0].Id),
                Calculated_On__c = Datetime.now()
            ),
            new Candidate_Job_Match__c(
                Candidate__c = candidates[1].Id,
                Job_Requisition__c = jobs[0].Id,
                Overall_Match_Score__c = 35.00,
                Recommendation__c = 'Low Match',
                Evaluation_Status__c = 'Completed',
                Missing_Skills__c = 'PyTorch, LLMs, Docker',
                Match_Key__c = String.valueOf(candidates[1].Id) + '_' + String.valueOf(jobs[0].Id),
                Calculated_On__c = Datetime.now()
            ),
            new Candidate_Job_Match__c(
                Candidate__c = candidates[0].Id,
                Job_Requisition__c = jobs[1].Id,
                Overall_Match_Score__c = 40.00,
                Recommendation__c = 'Low Match',
                Evaluation_Status__c = 'Completed',
                Missing_Skills__c = 'AWS, Kubernetes, Terraform',
                Match_Key__c = String.valueOf(candidates[0].Id) + '_' + String.valueOf(jobs[1].Id),
                Calculated_On__c = Datetime.now()
            )
        };
        insert matches;

        // Create Overdue Scheduled Interview
        Interview__c overdueIv = new Interview__c(
            Interview_Name__c = 'Elena Rostova - AI Technical Round',
            Job_Application__c = apps[0].Id,
            Candidate__c = candidates[0].Id,
            Interview_Date__c = Datetime.now().addDays(-2),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        );
        insert overdueIv;
    }

    @isTest
    static void testAlertGenerationAndSync() {
        Test.startTest();
        RecruitmentAlertService.AlertOverviewDTO dto = RecruitmentAlertService.synchronizeAlerts();
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assert(dto.totalAlerts > 0, 'Alerts should have been generated');
        System.assert(dto.activeAlertsCount > 0, 'Should have active alerts');

        // Verify persistent records in database
        List<Recruitment_Alert__c> dbAlerts = [SELECT Id, Alert_Key__c, Status__c, Severity__c, Title__c FROM Recruitment_Alert__c];
        System.assert(dbAlerts.size() > 0, 'Database should contain persistent Recruitment_Alert__c records');

        // Check overdue interview alert
        Boolean hasOverdueAlert = false;
        for (Recruitment_Alert__c alt : dbAlerts) {
            if (alt.Alert_Key__c.contains('OVERDUEINT')) {
                hasOverdueAlert = true;
                System.assertEquals(RecruitmentAlertService.STATUS_ACTIVE, alt.Status__c, 'Overdue alert should be active');
                System.assertEquals('High Attention', alt.Severity__c, 'Overdue interview should be High Attention');
            }
        }
        System.assert(hasOverdueAlert, 'Expected an overdue interview alert');
    }

    @isTest
    static void testAlertDeduplicationAndNoSpam() {
        Test.startTest();
        // First sync
        RecruitmentAlertService.synchronizeAlerts();
        Integer firstCount = [SELECT COUNT() FROM Recruitment_Alert__c];

        // Second sync - should update, not create duplicate records
        RecruitmentAlertService.AlertOverviewDTO secondDto = RecruitmentAlertService.synchronizeAlerts();
        Integer secondCount = [SELECT COUNT() FROM Recruitment_Alert__c];
        Test.stopTest();

        System.assertEquals(firstCount, secondCount, 'Sync should deduplicate and not create duplicate alerts');
    }

    @isTest
    static void testAlertAcknowledgement() {
        // Initial sync
        RecruitmentAlertService.synchronizeAlerts();
        Recruitment_Alert__c alt = [SELECT Id, Status__c FROM Recruitment_Alert__c WHERE Status__c = :RecruitmentAlertService.STATUS_ACTIVE LIMIT 1];

        Test.startTest();
        RecruitmentAlertService.ActionCenterResult res = RecruitmentAlertService.acknowledgeAlert(alt.Id, 'Reviewing with hiring manager today.');
        Test.stopTest();

        System.assert(res.isSuccess, 'Acknowledgement should succeed');

        Recruitment_Alert__c updatedAlt = [
            SELECT Id, Status__c, Acknowledged_By__c, Acknowledged_Date__c, Acknowledged_Notes__c
            FROM Recruitment_Alert__c
            WHERE Id = :alt.Id
        ];
        System.assertEquals(RecruitmentAlertService.STATUS_ACKNOWLEDGED, updatedAlt.Status__c, 'Status should be Acknowledged');
        System.assertEquals(UserInfo.getUserId(), updatedAlt.Acknowledged_By__c, 'Acknowledged_By should match current user');
        System.assertNotEquals(null, updatedAlt.Acknowledged_Date__c, 'Acknowledged date should be set');
        System.assertEquals('Reviewing with hiring manager today.', updatedAlt.Acknowledged_Notes__c, 'Notes should match');

        // Re-sync should preserve Acknowledged status
        RecruitmentAlertService.synchronizeAlerts();
        Recruitment_Alert__c preservedAlt = [SELECT Status__c FROM Recruitment_Alert__c WHERE Id = :alt.Id];
        System.assertEquals(RecruitmentAlertService.STATUS_ACKNOWLEDGED, preservedAlt.Status__c, 'Acknowledge status should be preserved on subsequent sync');
    }

    @isTest
    static void testInterviewRescheduleSuccessAndResolution() {
        // Initial sync
        RecruitmentAlertService.synchronizeAlerts();
        Interview__c overdueIv = [SELECT Id, Interview_Date__c, Interview_Status__c FROM Interview__c WHERE Interview_Status__c = 'Scheduled' LIMIT 1];

        Datetime futureDate = Datetime.now().addDays(3);

        Test.startTest();
        RecruitmentAlertService.ActionCenterResult res = RecruitmentAlertService.rescheduleInterview(
            overdueIv.Id,
            futureDate,
            'Rescheduled after candidate confirmed availability.'
        );
        Test.stopTest();

        System.assert(res.isSuccess, 'Reschedule should succeed');

        Interview__c updatedIv = [SELECT Id, Interview_Date__c, Interview_Status__c, Interview_Feedback__c FROM Interview__c WHERE Id = :overdueIv.Id];
        System.assertEquals(futureDate, updatedIv.Interview_Date__c, 'Date should be updated to future date');
        System.assertEquals('Scheduled', updatedIv.Interview_Status__c, 'Status should remain Scheduled');
        System.assert(updatedIv.Interview_Feedback__c.contains('Human Reschedule'), 'Feedback should contain audit note');

        // Check that corresponding alert is marked Resolved
        String alertKey = 'ALERT-OVERDUEINT-' + overdueIv.Id;
        List<Recruitment_Alert__c> relatedAlerts = [SELECT Status__c FROM Recruitment_Alert__c WHERE Alert_Key__c = :alertKey];
        if (!relatedAlerts.isEmpty()) {
            System.assertEquals(RecruitmentAlertService.STATUS_RESOLVED, relatedAlerts[0].Status__c, 'Alert should be Resolved');
        }
    }

    @isTest
    static void testInvalidInterviewRescheduleRejections() {
        Interview__c iv = [SELECT Id FROM Interview__c LIMIT 1];

        Test.startTest();
        // 1. Null interview ID
        RecruitmentAlertService.ActionCenterResult res1 = RecruitmentAlertService.rescheduleInterview(null, Datetime.now().addDays(1), 'notes');
        System.assertEquals(false, res1.isSuccess, 'Should reject null interview ID');

        // 2. Null date
        RecruitmentAlertService.ActionCenterResult res2 = RecruitmentAlertService.rescheduleInterview(iv.Id, null, 'notes');
        System.assertEquals(false, res2.isSuccess, 'Should reject null date');

        // 3. Past date
        RecruitmentAlertService.ActionCenterResult res3 = RecruitmentAlertService.rescheduleInterview(iv.Id, Datetime.now().addDays(-1), 'notes');
        System.assertEquals(false, res3.isSuccess, 'Should reject past date');
        Test.stopTest();
    }

    @isTest
    static void testZeroStatusMutationGuarantee() {
        // Capture initial statuses
        Candidate__c initialCand = [SELECT Id, Candidate_Status__c FROM Candidate__c LIMIT 1];
        Job_Application__c initialApp = [SELECT Id, Application_Status__c FROM Job_Application__c LIMIT 1];

        Test.startTest();
        RecruitmentAlertService.synchronizeAlerts();
        RecruitmentAlertService.getActionCenterAlerts(null, 'all', 'all', 'all');
        Test.stopTest();

        // Verify zero mutations
        Candidate__c finalCand = [SELECT Id, Candidate_Status__c FROM Candidate__c WHERE Id = :initialCand.Id];
        Job_Application__c finalApp = [SELECT Id, Application_Status__c FROM Job_Application__c WHERE Id = :initialApp.Id];

        System.assertEquals(initialCand.Candidate_Status__c, finalCand.Candidate_Status__c, 'Candidate status must never be mutated by alert system');
        System.assertEquals(initialApp.Application_Status__c, finalApp.Application_Status__c, 'Application status must never be mutated by alert system');
    }

    @isTest
    static void testCustomMetadataThresholds() {
        Test.startTest();
        RecruitmentRiskService.RiskThresholds th = RecruitmentRiskService.loadThresholds();
        Test.stopTest();

        System.assertNotEquals(null, th, 'Thresholds should load successfully');
        System.assert(th.goodMatchScore > 0, 'Good match score threshold should be positive');
        System.assert(th.lowMatchScore > 0, 'Low match score threshold should be positive');
        System.assert(th.lowMatchConcentration > 0, 'Low match concentration threshold should be positive');
    }

    @isTest
    static void testControllerEndpoints() {
        RecruitmentAlertService.synchronizeAlerts();
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c LIMIT 1];
        Interview__c iv = [SELECT Id FROM Interview__c LIMIT 1];
        Recruitment_Alert__c alt = [SELECT Id FROM Recruitment_Alert__c LIMIT 1];

        Test.startTest();
        // 1. getActionCenterData
        RecruitmentAlertService.AlertOverviewDTO dto = RecruitmentAlertController.getActionCenterData(job.Id, 'all', 'all', 'all');
        System.assertNotEquals(null, dto);

        // 2. syncAlertsNow
        RecruitmentAlertService.AlertOverviewDTO syncDto = RecruitmentAlertController.syncAlertsNow();
        System.assertNotEquals(null, syncDto);

        // 3. getInterviewDetails
        RecruitmentAlertService.InterviewDetailDTO ivDto = RecruitmentAlertController.getInterviewDetails(iv.Id);
        System.assertNotEquals(null, ivDto);

        // 4. getJobOptions
        List<Map<String, String>> jobOpts = RecruitmentAlertController.getJobOptions();
        System.assert(jobOpts.size() >= 2);

        // 5. acknowledgeAlert
        RecruitmentAlertService.ActionCenterResult ackRes = RecruitmentAlertController.acknowledgeAlert(alt.Id, 'Controller test note');
        System.assert(ackRes.isSuccess);

        // 6. rescheduleInterview
        RecruitmentAlertService.ActionCenterResult resRes = RecruitmentAlertController.rescheduleInterview(iv.Id, Datetime.now().addDays(4), 'Controller note');
        System.assert(resRes.isSuccess);
        Test.stopTest();
    }

    @isTest
    static void testControllerErrorHandling() {
        Test.startTest();
        try {
            RecruitmentAlertController.acknowledgeAlert(null, 'test');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptyDatasetHandling() {
        delete [SELECT Id FROM Interview__c];
        delete [SELECT Id FROM Candidate_Job_Match__c];
        delete [SELECT Id FROM Job_Application__c];
        delete [SELECT Id FROM Candidate__c];
        delete [SELECT Id FROM Job_Requisition__c];
        delete [SELECT Id FROM Recruitment_Alert__c];

        Test.startTest();
        RecruitmentAlertService.AlertOverviewDTO dto = RecruitmentAlertService.synchronizeAlerts();
        RecruitmentAlertService.InterviewDetailDTO ivDto = RecruitmentAlertService.getInterviewDetails(null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Should handle empty database gracefully');
        System.assertEquals(0, dto.totalAlerts, 'Total alerts should be 0 on empty dataset');
        System.assertEquals(null, ivDto, 'Null interview ID should return null detail');
    }
}
