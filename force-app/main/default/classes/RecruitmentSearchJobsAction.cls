public with sharing class RecruitmentSearchJobsAction {
    public class Request {
        @InvocableVariable(label='Search Term' description='Keyword to search by job title, department, or required skills')
        public String searchTerm;

        @InvocableVariable(label='Department' description='Department name')
        public String department;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted list of job requisitions')
        public String result;

        @InvocableVariable(label='Total Found' description='Number of jobs found')
        public Integer totalFound;
    }

    @InvocableMethod(label='Search Job Requisitions' description='Searches open job requisitions in Salesforce by title, department, or skills')
    public static List<Response> searchJobs(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String term = req != null && String.isNotBlank(req.searchTerm) ? req.searchTerm.trim().toLowerCase() : null;
            String dept = req != null && String.isNotBlank(req.department) ? req.department.trim().toLowerCase() : null;

            List<Job_Requisition__c> allOpenJobs = [
                SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c, Employment_Type__c,
                       Number_of_Positions__c, Required_Skills__c, Experience_Required__c, Status__c, Opening_Date__c
                FROM Job_Requisition__c
                WHERE Status__c = 'Open'
                ORDER BY Job_Code__c ASC
            ];

            List<Job_Requisition__c> matched = new List<Job_Requisition__c>();
            for (Job_Requisition__c job : allOpenJobs) {
                Boolean matches = true;

                if (dept != null && (job.Department__c == null || !job.Department__c.toLowerCase().contains(dept))) {
                    matches = false;
                }

                if (term != null) {
                    Boolean termMatch = false;
                    if (job.Job_Title__c != null && job.Job_Title__c.toLowerCase().contains(term)) {
                        termMatch = true;
                    } else if (job.Job_Code__c != null && job.Job_Code__c.toLowerCase().contains(term)) {
                        termMatch = true;
                    } else if (job.Department__c != null && job.Department__c.toLowerCase().contains(term)) {
                        termMatch = true;
                    } else if (job.Required_Skills__c != null && job.Required_Skills__c.toLowerCase().contains(term)) {
                        termMatch = true;
                    }
                    if (!termMatch) {
                        matches = false;
                    }
                }

                if (matches) {
                    matched.add(job);
                }
            }

            res.totalFound = matched.size();
            if (matched.isEmpty()) {
                res.result = 'No open job requisitions found matching the specified criteria.';
            } else {
                List<String> lines = new List<String>();
                lines.add('Found ' + matched.size() + ' open job requisition(s):');
                Integer i = 1;
                for (Job_Requisition__c job : matched) {
                    lines.add(i + '. **' + job.Job_Title__c + '** (' + job.Job_Code__c + ')');
                    lines.add('   - Department: ' + job.Department__c + ' | Location: ' + job.Location__c + ' | Type: ' + job.Employment_Type__c);
                    lines.add('   - Positions: ' + job.Number_of_Positions__c + ' | Exp Required: ' + (job.Experience_Required__c != null ? String.valueOf(job.Experience_Required__c) : 'N/A') + ' yrs');
                    if (String.isNotBlank(job.Required_Skills__c)) {
                        lines.add('   - Required Skills: ' + job.Required_Skills__c);
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
