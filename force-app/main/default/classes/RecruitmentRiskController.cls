/**
 * @description Lightning Controller for Phase 5: Recruitment Risk & Bottleneck Intelligence.
 * Exposes deterministic risk signals, coverage statistics, bottleneck diagnostics,
 * and skill gap intelligence to the recruitmentAttentionPanel LWC and dashboards.
 */
public with sharing class RecruitmentRiskController {

    public class JobOptionDTO {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public JobOptionDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Retrieves the full Risk & Bottleneck Intelligence dashboard data.
     * Supports filtering by Job Requisition, Severity, and Signal Type.
     */
    @AuraEnabled(cacheable=false)
    public static RecruitmentRiskService.RiskDashboardDTO getRiskIntelligence(
        String jobId,
        String severityFilter,
        String signalTypeFilter
    ) {
        try {
            return RecruitmentRiskService.evaluateRisks(jobId, severityFilter, signalTypeFilter);
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to evaluate recruitment risks: ' + ex.getMessage());
        }
    }

    /**
     * @description Retrieves risk summary and signals for a specific Job Requisition.
     */
    @AuraEnabled(cacheable=false)
    public static RecruitmentRiskService.RequisitionRiskSummary getJobRiskSummary(Id jobId) {
        if (jobId == null) {
            throw new AuraHandledException('Job Requisition ID is required.');
        }
        try {
            RecruitmentRiskService.RiskDashboardDTO dto = RecruitmentRiskService.evaluateRisks(String.valueOf(jobId), null, null);
            if (!dto.jobSummaries.isEmpty()) {
                return dto.jobSummaries[0];
            }
            return new RecruitmentRiskService.RequisitionRiskSummary();
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to retrieve job risk summary: ' + ex.getMessage());
        }
    }

    /**
     * @description Returns available active job options for filtering in the UI.
     */
    @AuraEnabled(cacheable=true)
    public static List<JobOptionDTO> getJobOptions() {
        List<JobOptionDTO> options = new List<JobOptionDTO>();
        options.add(new JobOptionDTO('All Jobs', ''));
        for (Job_Requisition__c j : [
            SELECT Id, Job_Title__c, Job_Code__c
            FROM Job_Requisition__c
            WHERE Status__c = 'Open'
            ORDER BY Job_Title__c ASC
        ]) {
            String label = j.Job_Title__c + (String.isNotBlank(j.Job_Code__c) ? ' (' + j.Job_Code__c + ')' : '');
            options.add(new JobOptionDTO(label, j.Id));
        }
        return options;
    }
}
