@isTest
private class RecruitmentSecurityTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Job Requisitions
        Job_Requisition__c job1 = new Job_Requisition__c(
            Job_Title__c = 'Security Lead Engineer',
            Job_Code__c = 'REQ-SEC-01',
            Department__c = 'Software Development',
            Location__c = 'San Francisco, CA',
            Experience_Required__c = 5.0,
            Minimum_Qualification__c = 'Bachelor in Computer Science',
            Required_Skills__c = 'Apex, SOQL, Security, OAuth',
            Status__c = 'Open',
            Employment_Type__c = 'Full-Time',
            Number_of_Positions__c = 1
        );
        insert job1;

        // 2. Create Candidate with phone PII
        Candidate__c cand1 = new Candidate__c(
            Candidate_Name__c = 'Samantha Securi',
            Email__c = 'samantha.sec@example.com',
            Phone__c = '415-555-1234',
            Location__c = 'San Francisco, CA',
            Years_of_Experience__c = 6.0,
            Highest_Qualification__c = 'Bachelor in Computer Science',
            Skills__c = 'Apex, SOQL, Security, OAuth, LWC',
            Candidate_Status__c = 'Interviewing'
        );
        insert cand1;

        // 3. Create Candidate Job Match
        Candidate_Job_Match__c match1 = new Candidate_Job_Match__c(
            Candidate__c = cand1.Id,
            Job_Requisition__c = job1.Id,
            Match_Key__c = cand1.Id + '_' + job1.Id,
            Overall_Match_Score__c = 92.50,
            Skill_Match_Percent__c = 95.00,
            Experience_Match_Percent__c = 90.00,
            Qualification_Match_Percent__c = 100.00,
            Location_Match_Percent__c = 100.00,
            Recommendation__c = 'Strong Match',
            Evaluation_Status__c = 'Completed',
            Calculated_On__c = Datetime.now()
        );
        insert match1;

        // 4. Create Job Application
        Job_Application__c app1 = new Job_Application__c(
            Candidate__c = cand1.Id,
            Job_Requisition__c = job1.Id,
            Application_Status__c = 'Applied',
            Application_Date__c = Date.today()
        );
        insert app1;

        // 5. Create Interview
        Interview__c iv1 = new Interview__c(
            Interview_Name__c = 'Technical Security Round',
            Job_Application__c = app1.Id,
            Candidate__c = cand1.Id,
            Interview_Date__c = Datetime.now().addDays(2),
            Interview_Status__c = 'Scheduled',
            Interview_Type__c = 'Technical'
        );
        insert iv1;

        // 6. Create Recruitment Alert
        Recruitment_Alert__c alt1 = new Recruitment_Alert__c(
            Alert_Key__c = 'ALERT-TEST-SEC-01',
            Alert_Type__c = 'Risk Signal',
            Severity__c = 'Medium',
            Title__c = 'Test Security Alert',
            Job_Requisition__c = job1.Id,
            Candidate__c = cand1.Id,
            Status__c = 'Active',
            Last_Evaluated_Date__c = Datetime.now()
        );
        insert alt1;
    }

    private static User createRoleUser(String alias, String permSetName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName = 'RoleTest',
            LastName = alias,
            Email = alias + uniqueSuffix + '@testsecurity.com',
            Username = alias + uniqueSuffix + '@testsecurityrecruitment.com',
            Alias = alias.length() > 8 ? alias.substring(0, 8) : alias,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        if (String.isNotBlank(permSetName)) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
            insert new PermissionSetAssignment(
                AssigneeId = u.Id,
                PermissionSetId = ps.Id
            );
        }
        return u;
    }

    @isTest
    static void testRecruiterRoleCapabilities() {
        User recruiter = createRoleUser('recrtr', 'Recruitment_Recruiter');
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c LIMIT 1];
        Candidate_Job_Match__c matchRec = [SELECT Id FROM Candidate_Job_Match__c LIMIT 1];
        Recruitment_Alert__c alertRec = [SELECT Id FROM Recruitment_Alert__c LIMIT 1];

        System.runAs(recruiter) {
            // Recruiter can view detail with unmasked candidate phone
            CandidateJobMatchUIController.MatchDetailDTO detail = CandidateJobMatchUIController.getMatchDetail(matchRec.Id);
            System.assertNotEquals(null, detail, 'Recruiter should be able to query match detail');
            System.assertEquals('415-555-1234', detail.candidatePhone, 'Recruiter should have access to candidate phone PII');

            // Recruiter can acknowledge alerts
            RecruitmentAlertService.ActionCenterResult ackRes = RecruitmentAlertController.acknowledgeAlert(alertRec.Id, 'Reviewed by recruiter');
            System.assertEquals(true, ackRes.isSuccess, 'Recruiter should be able to acknowledge alerts');
        }
    }

    @isTest
    static void testHiringManagerRoleRestrictionsAndPiiProtection() {
        User hiringManager = createRoleUser('hrmgr', 'Recruitment_Hiring_Manager');
        Candidate_Job_Match__c matchRec = [SELECT Id, Job_Requisition__c FROM Candidate_Job_Match__c LIMIT 1];
        Interview__c interviewRec = [SELECT Id, Interview_Feedback__c, Interview_Score__c FROM Interview__c LIMIT 1];

        System.runAs(hiringManager) {
            // 1. Hiring manager can view match detail but phone PII is protected/masked
            CandidateJobMatchUIController.MatchDetailDTO detail = CandidateJobMatchUIController.getMatchDetail(matchRec.Id);
            System.assertNotEquals(null, detail, 'Hiring Manager should be able to query match detail');
            System.assertEquals('[Protected - Contact Recruiter]', detail.candidatePhone, 'Candidate phone PII must be masked for Hiring Manager');

            // 2. Hiring manager can submit interview feedback & score
            interviewRec.Interview_Feedback__c = 'Candidate demonstrated solid architecture knowledge.';
            interviewRec.Interview_Score__c = 88.0;
            update interviewRec;

            Interview__c updatedIv = [SELECT Interview_Score__c FROM Interview__c WHERE Id = :interviewRec.Id];
            System.assertEquals(88.0, updatedIv.Interview_Score__c, 'Hiring Manager must be able to update interview evaluation');

            // 3. Hiring manager CANNOT create new Job Requisitions
            System.assertEquals(false, Schema.sObjectType.Job_Requisition__c.isCreateable(),
                'Hiring Manager must NOT have permission to create job requisitions');
        }
    }

    @isTest
    static void testAgentUserLeastPrivilegeBoundaries() {
        User agentUser = createRoleUser('agentusr', 'Recruitment_Agent_User');
        Job_Requisition__c job = [SELECT Id, Job_Title__c FROM Job_Requisition__c LIMIT 1];

        System.runAs(agentUser) {
            // Agent user has NO delete permissions on recruitment records
            System.assertEquals(false, Schema.sObjectType.Job_Requisition__c.isDeletable(),
                'Agent user must NOT have delete permission on Job_Requisition__c');
            System.assertEquals(false, Schema.sObjectType.Candidate__c.isDeletable(),
                'Agent user must NOT have delete permission on Candidate__c');
            System.assertEquals(false, Schema.sObjectType.Job_Application__c.isDeletable(),
                'Agent user must NOT have delete permission on Job_Application__c');

            // Agent user can execute Invocable search and match actions
            RecruitmentSearchJobsAction.Request jobReq = new RecruitmentSearchJobsAction.Request();
            jobReq.searchTerm = 'Security';
            List<RecruitmentSearchJobsAction.Response> jobRes = RecruitmentSearchJobsAction.searchJobs(
                new List<RecruitmentSearchJobsAction.Request>{ jobReq }
            );
            System.assertEquals(1, jobRes.size(), 'Agent should execute search jobs action');
            System.assert(jobRes[0].result.contains('Security Lead Engineer'), 'Result should return matching job');
        }
    }

    @isTest
    static void testInputValidationAndGuardrails() {
        Job_Requisition__c job = [SELECT Id FROM Job_Requisition__c LIMIT 1];
        Interview__c iv = [SELECT Id FROM Interview__c LIMIT 1];

        // 1. Candidate Comparison Input Validation: Less than 2 matches
        Boolean threwUnderflow = false;
        try {
            CandidateComparisonController.getComparisonData(job.Id, new List<Id>());
        } catch (AuraHandledException e) {
            threwUnderflow = true;
        }
        System.assertEquals(true, threwUnderflow, 'Should reject comparison with under 2 candidates');

        // 2. Candidate Comparison Input Validation: Null Job ID
        Boolean threwNullJob = false;
        try {
            CandidateComparisonController.getComparisonData(null, new List<Id>{ job.Id, iv.Id });
        } catch (AuraHandledException e) {
            threwNullJob = true;
        }
        System.assertEquals(true, threwNullJob, 'Should reject comparison with null job ID');

        // 3. Recruiter Action Center: Past date reschedule validation
        RecruitmentAlertService.ActionCenterResult pastDateRes = RecruitmentAlertController.rescheduleInterview(
            iv.Id,
            Datetime.now().addDays(-1),
            'Past date attempt'
        );
        System.assertEquals(false, pastDateRes.isSuccess, 'Reschedule to past date must be rejected');
        System.assert(pastDateRes.message.contains('future'), 'Error message must specify future requirement');

        // 4. Recruiter Action Center: Null interview ID
        RecruitmentAlertService.ActionCenterResult nullIvRes = RecruitmentAlertController.rescheduleInterview(
            null,
            Datetime.now().addDays(1),
            'Null ID attempt'
        );
        System.assertEquals(false, nullIvRes.isSuccess, 'Reschedule with null interview ID must be rejected');
    }
}
