public with sharing class RecruitmentPipelineSummaryAction {
    public class Request {
        @InvocableVariable(label='Trigger' description='Optional prompt trigger')
        public String triggerText;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted recruitment pipeline summary')
        public String result;
    }

    @InvocableMethod(label='Get Recruitment Pipeline Summary' description='Calculates recruitment metrics across open jobs, candidates, applications, and interviews')
    public static List<Response> getPipelineSummary(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();

            // 1. Open Job Requisitions and Positions
            List<Job_Requisition__c> openJobs = [
                SELECT Id, Job_Title__c, Job_Code__c, Department__c, Number_of_Positions__c
                FROM Job_Requisition__c
                WHERE Status__c = 'Open'
            ];
            Integer openJobCount = openJobs.size();
            Decimal totalPositions = 0;
            for (Job_Requisition__c j : openJobs) {
                if (j.Number_of_Positions__c != null) {
                    totalPositions += j.Number_of_Positions__c;
                }
            }

            // 2. Candidate Status breakdown
            List<AggregateResult> candStats = [
                SELECT Candidate_Status__c status, COUNT(Id) cnt
                FROM Candidate__c
                GROUP BY Candidate_Status__c
            ];
            Map<String, Integer> candMap = new Map<String, Integer>();
            Integer totalCandidates = 0;
            for (AggregateResult ar : candStats) {
                String st = (String)ar.get('status');
                Integer cnt = (Integer)ar.get('cnt');
                candMap.put(st, cnt);
                totalCandidates += cnt;
            }

            // 3. Application Status breakdown
            List<AggregateResult> appStats = [
                SELECT Application_Status__c status, COUNT(Id) cnt
                FROM Job_Application__c
                GROUP BY Application_Status__c
            ];
            Map<String, Integer> appMap = new Map<String, Integer>();
            Integer totalApplications = 0;
            for (AggregateResult ar : appStats) {
                String st = (String)ar.get('status');
                Integer cnt = (Integer)ar.get('cnt');
                appMap.put(st, cnt);
                totalApplications += cnt;
            }

            // 4. Interviews
            Integer scheduledInterviews = [
                SELECT COUNT()
                FROM Interview__c
                WHERE Interview_Status__c = 'Scheduled'
            ];
            Integer completedInterviews = [
                SELECT COUNT()
                FROM Interview__c
                WHERE Interview_Status__c = 'Completed'
            ];

            List<String> lines = new List<String>();
            lines.add('### 📊 Recruitment Pipeline Summary');
            lines.add('');
            lines.add('**Job Requisitions:**');
            lines.add('- Open Positions: ' + openJobCount + ' job requisition(s) with ' + totalPositions.intValue() + ' total open headcounts.');
            lines.add('');
            lines.add('**Candidate Pool (' + totalCandidates + ' total):**');
            lines.add('- New: ' + (candMap.containsKey('New') ? candMap.get('New') : 0));
            lines.add('- Screening: ' + (candMap.containsKey('Screening') ? candMap.get('Screening') : 0));
            lines.add('- Shortlisted: ' + (candMap.containsKey('Shortlisted') ? candMap.get('Shortlisted') : 0));
            lines.add('- Interviewing: ' + (candMap.containsKey('Interviewing') ? candMap.get('Interviewing') : 0));
            lines.add('- Selected: ' + (candMap.containsKey('Selected') ? candMap.get('Selected') : 0));
            lines.add('- Rejected: ' + (candMap.containsKey('Rejected') ? candMap.get('Rejected') : 0));
            lines.add('- Hired: ' + (candMap.containsKey('Hired') ? candMap.get('Hired') : 0));
            lines.add('');
            lines.add('**Job Applications (' + totalApplications + ' total):**');
            lines.add('- Applied: ' + (appMap.containsKey('Applied') ? appMap.get('Applied') : 0));
            lines.add('- Under Review: ' + (appMap.containsKey('Under Review') ? appMap.get('Under Review') : 0));
            lines.add('- Shortlisted: ' + (appMap.containsKey('Shortlisted') ? appMap.get('Shortlisted') : 0));
            lines.add('- Interview Scheduled: ' + (appMap.containsKey('Interview Scheduled') ? appMap.get('Interview Scheduled') : 0));
            lines.add('- Interviewed: ' + (appMap.containsKey('Interviewed') ? appMap.get('Interviewed') : 0));
            lines.add('- Selected: ' + (appMap.containsKey('Selected') ? appMap.get('Selected') : 0));
            lines.add('- Rejected: ' + (appMap.containsKey('Rejected') ? appMap.get('Rejected') : 0));
            lines.add('- Hired: ' + (appMap.containsKey('Hired') ? appMap.get('Hired') : 0));
            lines.add('');
            lines.add('**Interviews:**');
            lines.add('- Scheduled Upcoming: ' + scheduledInterviews);
            lines.add('- Completed: ' + completedInterviews);

            res.result = String.join(lines, '\n');
            responses.add(res);
        }
        return responses;
    }
}
