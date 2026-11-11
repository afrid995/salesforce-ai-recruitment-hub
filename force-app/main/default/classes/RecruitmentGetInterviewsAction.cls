public with sharing class RecruitmentGetInterviewsAction {
    public class Request {
        @InvocableVariable(label='Status Filter' description='Interview status filter: Scheduled, Completed, or all')
        public String statusFilter;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted list of interviews')
        public String result;

        @InvocableVariable(label='Total Found' description='Number of interviews found')
        public Integer totalFound;
    }

    @InvocableMethod(label='Get Interviews' description='Retrieves upcoming or scheduled interviews from Salesforce')
    public static List<Response> getInterviews(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String status = req != null && String.isNotBlank(req.statusFilter) ? req.statusFilter.trim().toLowerCase() : 'scheduled';

            List<Interview__c> allInterviews = [
                SELECT Id, Interview_Name__c, Interview_Date__c, Interview_Type__c, Interview_Status__c,
                       Interview_Feedback__c, Interview_Score__c, Recommendation__c,
                       Candidate__c, Candidate__r.Candidate_Name__c,
                       Job_Application__c, Job_Application__r.Application_Number__c,
                       Job_Application__r.Job_Requisition__r.Job_Title__c,
                       Interviewer__c, Interviewer__r.Name
                FROM Interview__c
                ORDER BY Interview_Date__c ASC
            ];

            List<Interview__c> matched = new List<Interview__c>();
            for (Interview__c inv : allInterviews) {
                if (status == 'all') {
                    matched.add(inv);
                } else if (inv.Interview_Status__c != null && inv.Interview_Status__c.toLowerCase().contains(status)) {
                    matched.add(inv);
                }
            }

            res.totalFound = matched.size();
            if (matched.isEmpty()) {
                res.result = 'No interviews found with status "' + status + '" in Salesforce.';
            } else {
                List<String> lines = new List<String>();
                lines.add('Found ' + matched.size() + ' ' + (status == 'all' ? '' : status + ' ') + 'interview(s):');
                Integer i = 1;
                for (Interview__c inv : matched) {
                    String cand = inv.Candidate__r != null ? inv.Candidate__r.Candidate_Name__c : 'Candidate';
                    String job = (inv.Job_Application__r != null && inv.Job_Application__r.Job_Requisition__r != null)
                        ? inv.Job_Application__r.Job_Requisition__r.Job_Title__c : 'Position';
                    String appNum = inv.Job_Application__r != null ? inv.Job_Application__r.Application_Number__c : '';
                    String interviewerName = inv.Interviewer__r != null ? inv.Interviewer__r.Name : 'Recruitment Team';
                    String dt = inv.Interview_Date__c != null ? inv.Interview_Date__c.format('yyyy-MM-dd HH:mm z') : 'TBD';

                    lines.add(i + '. **' + inv.Interview_Name__c + '**');
                    lines.add('   - Candidate: **' + cand + '** | Job: ' + job + (String.isNotBlank(appNum) ? ' (' + appNum + ')' : ''));
                    lines.add('   - Date & Time: ' + dt);
                    lines.add('   - Type: ' + inv.Interview_Type__c + ' | Status: **' + inv.Interview_Status__c + '**');
                    lines.add('   - Interviewer: ' + interviewerName);
                    if (inv.Interview_Score__c != null) {
                        lines.add('   - Score: ' + inv.Interview_Score__c + ' | Recommendation: ' + inv.Recommendation__c);
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
