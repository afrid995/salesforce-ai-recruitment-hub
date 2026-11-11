public with sharing class RecruitmentSearchApplicationsAction {
    public class Request {
        @InvocableVariable(label='Candidate Name' description='Candidate name to search')
        public String candidateName;

        @InvocableVariable(label='Job Title or Code' description='Job title or job code')
        public String jobTitleOrCode;

        @InvocableVariable(label='Application Number' description='Application number, e.g. APP-00001')
        public String applicationNumber;

        @InvocableVariable(label='Application Status' description='Filter by status, e.g. Selected, Shortlisted, Applied, Interview Scheduled')
        public String applicationStatus;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted application details')
        public String result;

        @InvocableVariable(label='Total Found' description='Number of applications found')
        public Integer totalFound;
    }

    @InvocableMethod(label='Search Job Applications' description='Searches job applications by application number or status (e.g. APP-00001, Shortlisted, Applied). Do not use for match scores or candidate comparisons.')
    public static List<Response> searchApplications(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String candName = req != null && String.isNotBlank(req.candidateName) ? req.candidateName.trim().toLowerCase() : null;
            String jobQuery = req != null && String.isNotBlank(req.jobTitleOrCode) ? req.jobTitleOrCode.trim().toLowerCase() : null;
            String appNum = req != null && String.isNotBlank(req.applicationNumber) ? req.applicationNumber.trim().toUpperCase() : null;
            String statusQuery = req != null && String.isNotBlank(req.applicationStatus) ? req.applicationStatus.trim().toLowerCase() : null;

            List<Job_Application__c> allApps = [
                SELECT Id, Application_Number__c, Application_Date__c, Application_Status__c,
                       Screening_Score__c, Recruiter_Notes__c, Rejection_Reason__c,
                       Candidate__c, Candidate__r.Candidate_Name__c, Candidate__r.Email__c,
                       Job_Requisition__c, Job_Requisition__r.Job_Title__c, Job_Requisition__r.Job_Code__c
                FROM Job_Application__c
                ORDER BY Application_Number__c ASC
            ];

            List<Job_Application__c> matched = new List<Job_Application__c>();
            for (Job_Application__c app : allApps) {
                Boolean matches = true;

                if (candName != null) {
                    if (app.Candidate__r == null || app.Candidate__r.Candidate_Name__c == null ||
                        !app.Candidate__r.Candidate_Name__c.toLowerCase().contains(candName)) {
                        matches = false;
                    }
                }

                if (jobQuery != null) {
                    Boolean jobMatch = false;
                    if (app.Job_Requisition__r != null) {
                        if (app.Job_Requisition__r.Job_Title__c != null && app.Job_Requisition__r.Job_Title__c.toLowerCase().contains(jobQuery)) {
                            jobMatch = true;
                        } else if (app.Job_Requisition__r.Job_Code__c != null && app.Job_Requisition__r.Job_Code__c.toLowerCase().contains(jobQuery)) {
                            jobMatch = true;
                        }
                    }
                    if (!jobMatch) {
                        matches = false;
                    }
                }

                if (appNum != null) {
                    if (app.Application_Number__c == null || !app.Application_Number__c.toUpperCase().contains(appNum)) {
                        matches = false;
                    }
                }

                if (statusQuery != null) {
                    if (app.Application_Status__c == null || !app.Application_Status__c.toLowerCase().contains(statusQuery)) {
                        matches = false;
                    }
                }

                if (matches) {
                    matched.add(app);
                }
            }

            res.totalFound = matched.size();
            if (matched.isEmpty()) {
                if (candName != null) {
                    res.result = 'No job application found for candidate "' + req.candidateName + '" in Salesforce.';
                } else if (jobQuery != null) {
                    res.result = 'No applications found for job requisition "' + req.jobTitleOrCode + '".';
                } else if (appNum != null) {
                    res.result = 'No application found with number "' + req.applicationNumber + '".';
                } else if (statusQuery != null) {
                    res.result = 'No applications found with status "' + req.applicationStatus + '".';
                } else {
                    res.result = 'No applications found matching the specified criteria.';
                }
            } else {
                List<String> lines = new List<String>();
                lines.add('Found ' + matched.size() + ' application(s):');
                Integer i = 1;
                for (Job_Application__c app : matched) {
                    String cand = app.Candidate__r != null ? app.Candidate__r.Candidate_Name__c : 'Unknown Candidate';
                    String jobTitle = app.Job_Requisition__r != null ? app.Job_Requisition__r.Job_Title__c : 'Unknown Requisition';
                    String jobCode = app.Job_Requisition__r != null ? app.Job_Requisition__r.Job_Code__c : '';
                    String appDate = app.Application_Date__c != null ? String.valueOf(app.Application_Date__c) : 'N/A';
                    String score = app.Screening_Score__c != null ? String.valueOf(app.Screening_Score__c) : 'Pending';

                    lines.add(i + '. **' + app.Application_Number__c + '** — ' + cand);
                    lines.add('   - Requisition: ' + jobTitle + (String.isNotBlank(jobCode) ? ' (' + jobCode + ')' : ''));
                    lines.add('   - Status: **' + app.Application_Status__c + '** | Applied: ' + appDate);
                    lines.add('   - Screening Score: ' + score);
                    if (String.isNotBlank(app.Recruiter_Notes__c)) {
                        lines.add('   - Recruiter Notes: ' + app.Recruiter_Notes__c);
                    }
                    i++;
                }
                res.result = String.join(lines, '\n');
            }
            responses.add(res);
        }
        return responses;
    }
}
