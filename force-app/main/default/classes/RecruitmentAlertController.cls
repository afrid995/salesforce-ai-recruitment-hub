/**
 * @description Phase 6: Recruiter Action Center Controller.
 * Exposes AuraEnabled endpoints for the recruiterActionCenter Lightning Web Component.
 * Supports operational alert viewing, manual/scheduled synchronization, alert acknowledgement,
 * and human-in-the-loop interview rescheduling.
 */
public with sharing class RecruitmentAlertController {

    @AuraEnabled(cacheable=false)
    public static RecruitmentAlertService.AlertOverviewDTO getActionCenterData(
        String jobId,
        String severityFilter,
        String statusFilter,
        String alertTypeFilter
    ) {
        try {
            return RecruitmentAlertService.getActionCenterAlerts(jobId, severityFilter, statusFilter, alertTypeFilter);
        } catch (Exception ex) {
            throw new AuraHandledException('Error loading Recruiter Action Center data: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static RecruitmentAlertService.AlertOverviewDTO syncAlertsNow() {
        try {
            return RecruitmentAlertService.synchronizeAlerts();
        } catch (Exception ex) {
            throw new AuraHandledException('Error synchronizing recruitment alerts: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static RecruitmentAlertService.ActionCenterResult acknowledgeAlert(Id alertId, String notes) {
        try {
            return RecruitmentAlertService.acknowledgeAlert(alertId, notes);
        } catch (Exception ex) {
            throw new AuraHandledException('Error acknowledging alert: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static RecruitmentAlertService.ActionCenterResult rescheduleInterview(Id interviewId, Datetime newDateTime, String notes) {
        try {
            return RecruitmentAlertService.rescheduleInterview(interviewId, newDateTime, notes);
        } catch (Exception ex) {
            throw new AuraHandledException('Error rescheduling interview: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static RecruitmentAlertService.InterviewDetailDTO getInterviewDetails(Id interviewId) {
        try {
            return RecruitmentAlertService.getInterviewDetails(interviewId);
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching interview details: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getJobOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        options.add(new Map<String, String>{ 'label' => 'All Jobs', 'value' => '' });

        for (Job_Requisition__c j : [
            SELECT Id, Job_Title__c, Job_Code__c
            FROM Job_Requisition__c
            ORDER BY Job_Title__c ASC
        ]) {
            String label = j.Job_Title__c + (String.isNotBlank(j.Job_Code__c) ? ' (' + j.Job_Code__c + ')' : '');
            options.add(new Map<String, String>{ 'label' => label, 'value' => j.Id });
        }
        return options;
    }
}
