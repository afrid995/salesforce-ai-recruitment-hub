public with sharing class RecruitmentHomeController {

    public class KpiSummary {
        @AuraEnabled public Integer openJobs { get; set; }
        @AuraEnabled public Integer totalCandidates { get; set; }
        @AuraEnabled public Integer totalApplications { get; set; }
        @AuraEnabled public Integer totalInterviews { get; set; }
        @AuraEnabled public Integer upcomingInterviews { get; set; }
        @AuraEnabled public Integer selectedCandidates { get; set; }
    }

    public class ReportLinks {
        @AuraEnabled public String dashboardId { get; set; }
        @AuraEnabled public String openJobsReportId { get; set; }
        @AuraEnabled public String candidatesReportId { get; set; }
        @AuraEnabled public String applicationsReportId { get; set; }
        @AuraEnabled public String selectedCandidatesReportId { get; set; }
        @AuraEnabled public String upcomingInterviewsReportId { get; set; }
    }

    public class InterviewItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public String candidateId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String interviewType { get; set; }
        @AuraEnabled public Datetime interviewDateTime { get; set; }
        @AuraEnabled public String formattedDateTime { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String interviewerName { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static KpiSummary getRecruitmentKpis() {
        KpiSummary kpi = new KpiSummary();
        Datetime now = Datetime.now();
        kpi.openJobs = [SELECT count() FROM Job_Requisition__c WHERE Status__c = 'Open'];
        kpi.totalCandidates = [SELECT count() FROM Candidate__c];
        kpi.totalApplications = [SELECT count() FROM Job_Application__c];
        kpi.totalInterviews = [SELECT count() FROM Interview__c];
        kpi.upcomingInterviews = [SELECT count() FROM Interview__c WHERE Interview_Status__c = 'Scheduled' AND Interview_Date__c >= :now];
        kpi.selectedCandidates = [SELECT count() FROM Candidate__c WHERE Candidate_Status__c = 'Selected'];
        return kpi;
    }

    @AuraEnabled(cacheable=true)
    public static ReportLinks getReportLinks() {
        ReportLinks links = new ReportLinks();
        List<Dashboard> dashboards = [SELECT Id FROM Dashboard WHERE DeveloperName = 'Recruitment_Dashboard' LIMIT 1];
        if (!dashboards.isEmpty()) {
            links.dashboardId = dashboards[0].Id;
        }
        for (Report r : [
            SELECT Id, DeveloperName 
            FROM Report 
            WHERE DeveloperName IN (
                'Open_Job_Requisitions', 'Candidates_by_Status', 'Applications_by_Status',
                'Selected_Candidates', 'Upcoming_Interviews'
            )
        ]) {
            if (r.DeveloperName == 'Open_Job_Requisitions') {
                links.openJobsReportId = r.Id;
            } else if (r.DeveloperName == 'Candidates_by_Status') {
                links.candidatesReportId = r.Id;
            } else if (r.DeveloperName == 'Applications_by_Status') {
                links.applicationsReportId = r.Id;
            } else if (r.DeveloperName == 'Selected_Candidates') {
                links.selectedCandidatesReportId = r.Id;
            } else if (r.DeveloperName == 'Upcoming_Interviews') {
                links.upcomingInterviewsReportId = r.Id;
            }
        }
        return links;
    }

    @AuraEnabled(cacheable=true)
    public static List<InterviewItem> getUpcomingInterviews() {
        List<InterviewItem> items = new List<InterviewItem>();
        Datetime now = Datetime.now();
        List<Interview__c> interviews = [
            SELECT Id, Interview_Name__c, Candidate__c, Candidate__r.Candidate_Name__c,
                   Job_Application__r.Job_Requisition__r.Job_Title__c,
                   Interview_Type__c, Interview_Date__c, Interview_Status__c, Interviewer__r.Name
            FROM Interview__c
            WHERE Interview_Status__c = 'Scheduled' AND Interview_Date__c >= :now
            ORDER BY Interview_Date__c ASC
            LIMIT 10
        ];

        for (Interview__c i : interviews) {
            InterviewItem item = new InterviewItem();
            item.id = i.Id;
            item.name = i.Interview_Name__c;
            item.candidateId = i.Candidate__c;
            item.candidateName = i.Candidate__r != null ? i.Candidate__r.Candidate_Name__c : 'N/A';
            item.jobTitle = (i.Job_Application__r != null && i.Job_Application__r.Job_Requisition__r != null)
                ? i.Job_Application__r.Job_Requisition__r.Job_Title__c : 'N/A';
            item.interviewType = i.Interview_Type__c;
            item.interviewDateTime = i.Interview_Date__c;
            item.formattedDateTime = i.Interview_Date__c != null 
                ? i.Interview_Date__c.format('MMM dd, yyyy h:mm a') : 'TBD';
            item.status = i.Interview_Status__c;
            item.interviewerName = i.Interviewer__r != null ? i.Interviewer__r.Name : 'Unassigned';
            items.add(item);
        }
        return items;
    }
}
