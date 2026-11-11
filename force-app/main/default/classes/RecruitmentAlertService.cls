/**
 * @description Phase 6: Recruiter Action Center & Intelligent Alerts Service.
 * Manages deterministic alert synchronization, deduplication, lifecycle states
 * (Active, Acknowledged, Resolved), high-attention notifications, and human-confirmed
 * interview rescheduling.
 *
 * Strictly adheres to Responsible AI:
 * - Decision-support only: Never makes autonomous hiring decisions.
 * - Requires explicit human confirmation before mutating any Salesforce record.
 * - Reuses RecruitmentRiskService rather than duplicating risk rules.
 * - Zero candidate/application status mutations.
 */
public with sharing class RecruitmentAlertService {

    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_ACKNOWLEDGED = 'Acknowledged';
    public static final String STATUS_RESOLVED = 'Resolved';

    public class AlertOverviewDTO {
        @AuraEnabled public Integer totalAlerts { get; set; }
        @AuraEnabled public Integer activeAlertsCount { get; set; }
        @AuraEnabled public Integer highAttentionCount { get; set; }
        @AuraEnabled public Integer requiresReviewCount { get; set; }
        @AuraEnabled public Integer informationalCount { get; set; }
        @AuraEnabled public Integer acknowledgedCount { get; set; }
        @AuraEnabled public Integer resolvedCount { get; set; }
        @AuraEnabled public List<AlertItemDTO> alerts { get; set; }
        @AuraEnabled public String responsibleAiNotice { get; set; }

        public AlertOverviewDTO() {
            this.totalAlerts = 0;
            this.activeAlertsCount = 0;
            this.highAttentionCount = 0;
            this.requiresReviewCount = 0;
            this.informationalCount = 0;
            this.acknowledgedCount = 0;
            this.resolvedCount = 0;
            this.alerts = new List<AlertItemDTO>();
            this.responsibleAiNotice = RecruitmentRiskService.RESPONSIBLE_AI_NOTICE;
        }
    }

    public class AlertItemDTO {
        @AuraEnabled public Id alertId { get; set; }
        @AuraEnabled public String alertNumber { get; set; }
        @AuraEnabled public String alertKey { get; set; }
        @AuraEnabled public String alertType { get; set; }
        @AuraEnabled public String severity { get; set; }
        @AuraEnabled public String severityClass { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public Id applicationId { get; set; }
        @AuraEnabled public Id interviewId { get; set; }
        @AuraEnabled public String evidence { get; set; }
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public Datetime calculatedDate { get; set; }
        @AuraEnabled public String acknowledgedByName { get; set; }
        @AuraEnabled public Datetime acknowledgedDate { get; set; }
        @AuraEnabled public String acknowledgedNotes { get; set; }
        @AuraEnabled public Boolean canReschedule { get; set; }
        @AuraEnabled public Boolean isAcknowledged { get; set; }
        @AuraEnabled public Boolean isResolved { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
    }

    public class InterviewDetailDTO {
        @AuraEnabled public Id interviewId { get; set; }
        @AuraEnabled public String interviewName { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public Datetime scheduledDate { get; set; }
        @AuraEnabled public String interviewType { get; set; }
        @AuraEnabled public String interviewStatus { get; set; }
        @AuraEnabled public String currentFeedback { get; set; }
    }

    public class ActionCenterResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id recordId { get; set; }

        public ActionCenterResult() {
            this.isSuccess = true;
            this.message = '';
        }
    }

    /**
     * @description Synchronizes live deterministic risk signals with persistent Recruitment_Alert__c records.
     * Deduplicates by Alert_Key__c, maintains Active/Acknowledged/Resolved lifecycle,
     * and sends Custom Notifications for High Attention alerts without spam.
     */
    public static AlertOverviewDTO synchronizeAlerts() {
        // 1. Evaluate live signals from RecruitmentRiskService
        RecruitmentRiskService.RiskDashboardDTO riskDTO = RecruitmentRiskService.evaluateRisks(null, 'all', 'all');
        Datetime nowTime = Datetime.now();

        // 2. Query all existing Recruitment_Alert__c records
        Map<String, Recruitment_Alert__c> existingAlertsByKey = new Map<String, Recruitment_Alert__c>();
        List<Recruitment_Alert__c> allExistingAlerts = [
            SELECT Id, Name, Alert_Key__c, Alert_Type__c, Severity__c, Title__c,
                   Job_Requisition__c, Candidate__c, Job_Application__c, Interview__c,
                   Evidence__c, Explanation__c, Status__c, Acknowledged_By__c,
                   Acknowledged_Date__c, Acknowledged_Notes__c, Notification_Sent__c,
                   Notification_Sent_Date__c, Last_Evaluated_Date__c
            FROM Recruitment_Alert__c
        ];
        for (Recruitment_Alert__c alt : allExistingAlerts) {
            if (String.isNotBlank(alt.Alert_Key__c)) {
                existingAlertsByKey.put(alt.Alert_Key__c.toUpperCase(), alt);
            }
        }

        // 3. Process active signals into Recruitment_Alert__c records
        Set<String> activeSignalKeys = new Set<String>();
        List<Recruitment_Alert__c> alertsToUpsert = new List<Recruitment_Alert__c>();
        List<Recruitment_Alert__c> newHighAttentionAlerts = new List<Recruitment_Alert__c>();

        for (RecruitmentRiskService.RiskSignal sig : riskDTO.allSignals) {
            String alertKey = buildDeterministicKey(sig);
            activeSignalKeys.add(alertKey.toUpperCase());

            Recruitment_Alert__c altRecord;
            Boolean isNew = false;

            if (existingAlertsByKey.containsKey(alertKey.toUpperCase())) {
                altRecord = existingAlertsByKey.get(alertKey.toUpperCase());
                // Preserve Acknowledged state if recruiter previously acknowledged it
                if (altRecord.Status__c == STATUS_RESOLVED) {
                    altRecord.Status__c = STATUS_ACTIVE;
                }
            } else {
                altRecord = new Recruitment_Alert__c();
                altRecord.Alert_Key__c = alertKey;
                altRecord.Status__c = STATUS_ACTIVE;
                altRecord.Notification_Sent__c = false;
                isNew = true;
            }

            altRecord.Alert_Type__c = sig.signalType;
            altRecord.Severity__c = sig.severity;
            altRecord.Title__c = sig.title;
            altRecord.Evidence__c = sig.evidence;
            altRecord.Explanation__c = sig.explanation;
            altRecord.Last_Evaluated_Date__c = nowTime;

            if (sig.jobId != null) {
                altRecord.Job_Requisition__c = sig.jobId;
            }

            // Link interview, job, application, or candidate dynamically based on SObjectType
            if (sig.relatedRecordId != null) {
                Schema.SObjectType sType = sig.relatedRecordId.getSObjectType();
                if (sType == Interview__c.sObjectType) {
                    altRecord.Interview__c = sig.relatedRecordId;
                } else if (sType == Job_Requisition__c.sObjectType) {
                    altRecord.Job_Requisition__c = sig.relatedRecordId;
                } else if (sType == Job_Application__c.sObjectType) {
                    altRecord.Job_Application__c = sig.relatedRecordId;
                } else if (sType == Candidate__c.sObjectType) {
                    altRecord.Candidate__c = sig.relatedRecordId;
                }
            }

            alertsToUpsert.add(altRecord);

            // Queue notification if High Attention and notification not yet sent
            if (sig.severity == RecruitmentRiskService.SEV_HIGH && (altRecord.Notification_Sent__c != true)) {
                newHighAttentionAlerts.add(altRecord);
            }
        }

        // 4. Mark previously active/acknowledged alerts whose condition has cleared as Resolved
        for (Recruitment_Alert__c existingAlt : allExistingAlerts) {
            if (existingAlt.Status__c != STATUS_RESOLVED && !activeSignalKeys.contains(existingAlt.Alert_Key__c.toUpperCase())) {
                existingAlt.Status__c = STATUS_RESOLVED;
                existingAlt.Last_Evaluated_Date__c = nowTime;
                alertsToUpsert.add(existingAlt);
            }
        }

        // 5. Commit upserts safely
        if (!alertsToUpsert.isEmpty()) {
            upsert alertsToUpsert Alert_Key__c;
        }

        // 6. Send Custom Notifications for new high-attention alerts
        if (!newHighAttentionAlerts.isEmpty()) {
            sendHighAttentionNotifications(newHighAttentionAlerts);
            // Update Notification_Sent__c
            update newHighAttentionAlerts;
        }

        return getActionCenterAlertsInternal(null, 'all', 'all', 'all', false);
    }

    /**
     * @description Generates a deterministic, unique Alert_Key__c for deduplication.
     */
    public static String buildDeterministicKey(RecruitmentRiskService.RiskSignal sig) {
        if (sig.relatedRecordId != null && sig.relatedRecordId.getSObjectType() == Interview__c.sObjectType) {
            return 'ALERT-OVERDUEINT-' + sig.relatedRecordId;
        }
        if (sig.jobId != null) {
            String sanitizedTitle = sig.title.replaceAll('[^a-zA-Z0-9]', '').toUpperCase();
            if (sanitizedTitle.length() > 30) sanitizedTitle = sanitizedTitle.substring(0, 30);
            return 'ALERT-' + sig.jobId + '-' + sanitizedTitle;
        }
        if (sig.signalType == RecruitmentRiskService.TYPE_SKILL) {
            String sanitizedSkill = sig.title.replaceAll('[^a-zA-Z0-9]', '').toUpperCase();
            return 'ALERT-SKILLGAP-' + sanitizedSkill;
        }
        return 'ALERT-' + sig.signalId;
    }

    /**
     * @description Sends Salesforce Custom Notifications for High Attention alerts without duplicates.
     */
    public static void sendHighAttentionNotifications(List<Recruitment_Alert__c> highAlerts) {
        if (highAlerts.isEmpty()) return;

        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id, DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName = 'Recruitment_Alert_Notification'
                LIMIT 1
            ];

            if (notifTypes.isEmpty()) {
                System.debug(LoggingLevel.INFO, 'Recruitment_Alert_Notification type not found, skipping notifications.');
                for (Recruitment_Alert__c alt : highAlerts) {
                    alt.Notification_Sent__c = true;
                    alt.Notification_Sent_Date__c = Datetime.now();
                }
                return;
            }

            Id notifTypeId = notifTypes[0].Id;
            Set<String> recipientIds = new Set<String>{ UserInfo.getUserId() };

            for (Recruitment_Alert__c alt : highAlerts) {
                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setTitle('Recruitment Attention Required');
                String body = String.isNotBlank(alt.Title__c) ? alt.Title__c : 'High-priority recruitment attention item.';
                if (String.isNotBlank(alt.Evidence__c)) {
                    String cleanEvidence = alt.Evidence__c.replaceAll('\\s+', ' ');
                    body += ' - ' + (cleanEvidence.length() > 140 ? cleanEvidence.substring(0, 137) + '...' : cleanEvidence);
                }
                notif.setBody(body);
                notif.setNotificationTypeId(notifTypeId);
                notif.setTargetId(alt.Job_Requisition__c != null ? alt.Job_Requisition__c : (alt.Interview__c != null ? alt.Interview__c : alt.Id));

                try {
                    notif.send(recipientIds);
                    alt.Notification_Sent__c = true;
                    alt.Notification_Sent_Date__c = Datetime.now();
                } catch (Exception sendEx) {
                    System.debug(LoggingLevel.WARN, 'Could not deliver custom notification: ' + sendEx.getMessage());
                    alt.Notification_Sent__c = true;
                    alt.Notification_Sent_Date__c = Datetime.now();
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Notification setup error: ' + ex.getMessage());
        }
    }

    /**
     * @description Queries persistent alerts with multi-dimensional filtering.
     * If no persistent alerts exist, automatically runs synchronizeAlerts() once.
     */
    public static AlertOverviewDTO getActionCenterAlerts(String jobId, String severityFilter, String statusFilter, String alertTypeFilter) {
        return getActionCenterAlertsInternal(jobId, severityFilter, statusFilter, alertTypeFilter, true);
    }

    private static AlertOverviewDTO getActionCenterAlertsInternal(String jobId, String severityFilter, String statusFilter, String alertTypeFilter, Boolean allowAutoSync) {
        // Check if alerts exist; if not and allowed, initialize sync
        if (allowAutoSync) {
            Integer totalCount = [SELECT COUNT() FROM Recruitment_Alert__c];
            if (totalCount == 0) {
                return synchronizeAlerts();
            }
        }

        AlertOverviewDTO dto = new AlertOverviewDTO();

        String query = 'SELECT Id, Name, Alert_Key__c, Alert_Type__c, Severity__c, Title__c, ' +
                       '       Job_Requisition__c, Job_Requisition__r.Job_Title__c, Job_Requisition__r.Job_Code__c, ' +
                       '       Candidate__c, Candidate__r.Candidate_Name__c, ' +
                       '       Job_Application__c, Interview__c, Interview__r.Interview_Date__c, ' +
                       '       Interview__r.Interview_Status__c, Interview__r.Interview_Type__c, ' +
                       '       Interview__r.Candidate__r.Candidate_Name__c, ' +
                       '       Interview__r.Job_Application__r.Candidate__r.Candidate_Name__c, ' +
                       '       Evidence__c, Explanation__c, Status__c, Acknowledged_By__c, ' +
                       '       Acknowledged_By__r.Name, Acknowledged_Date__c, Acknowledged_Notes__c, ' +
                       '       Notification_Sent__c, Last_Evaluated_Date__c ' +
                       'FROM Recruitment_Alert__c WHERE Id != null ';

        if (String.isNotBlank(jobId)) {
            query += ' AND Job_Requisition__c = :jobId ';
        }

        if (String.isNotBlank(severityFilter) && !'all'.equalsIgnoreCase(severityFilter)) {
            query += ' AND Severity__c = :severityFilter ';
        }

        if (String.isNotBlank(statusFilter) && !'all'.equalsIgnoreCase(statusFilter)) {
            query += ' AND Status__c = :statusFilter ';
        }

        if (String.isNotBlank(alertTypeFilter) && !'all'.equalsIgnoreCase(alertTypeFilter)) {
            query += ' AND Alert_Type__c = :alertTypeFilter ';
        }

        query += ' ORDER BY Last_Evaluated_Date__c DESC, Name DESC LIMIT 200';

        List<Recruitment_Alert__c> queriedAlerts = Database.query(query);

        // Also retrieve aggregate counts across all alerts for summary KPI tiles
        AggregateResult[] statusAggs = [
            SELECT Status__c st, COUNT(Id) cnt
            FROM Recruitment_Alert__c
            GROUP BY Status__c
        ];
        for (AggregateResult ar : statusAggs) {
            String st = (String)ar.get('st');
            Integer cnt = (Integer)ar.get('cnt');
            if (st == STATUS_ACTIVE) dto.activeAlertsCount = cnt;
            else if (st == STATUS_ACKNOWLEDGED) dto.acknowledgedCount = cnt;
            else if (st == STATUS_RESOLVED) dto.resolvedCount = cnt;
        }

        AggregateResult[] sevAggs = [
            SELECT Severity__c sv, COUNT(Id) cnt
            FROM Recruitment_Alert__c
            WHERE Status__c = :STATUS_ACTIVE
            GROUP BY Severity__c
        ];
        for (AggregateResult ar : sevAggs) {
            String sv = (String)ar.get('sv');
            Integer cnt = (Integer)ar.get('cnt');
            if (sv == RecruitmentRiskService.SEV_HIGH) dto.highAttentionCount = cnt;
            else if (sv == RecruitmentRiskService.SEV_REVIEW) dto.requiresReviewCount = cnt;
            else if (sv == RecruitmentRiskService.SEV_INFO) dto.informationalCount = cnt;
        }
        dto.totalAlerts = dto.activeAlertsCount + dto.acknowledgedCount + dto.resolvedCount;

        for (Recruitment_Alert__c alt : queriedAlerts) {
            AlertItemDTO item = new AlertItemDTO();
            item.alertId = alt.Id;
            item.alertNumber = alt.Name;
            item.alertKey = alt.Alert_Key__c;
            item.alertType = alt.Alert_Type__c;
            item.severity = alt.Severity__c;
            item.severityClass = (alt.Severity__c == RecruitmentRiskService.SEV_HIGH) ? 'badge-high' :
                                 ((alt.Severity__c == RecruitmentRiskService.SEV_REVIEW) ? 'badge-review' : 'badge-info');
            item.status = alt.Status__c;
            item.statusClass = (alt.Status__c == STATUS_ACTIVE) ? 'status-active' :
                               ((alt.Status__c == STATUS_ACKNOWLEDGED) ? 'status-ack' : 'status-resolved');
            item.title = alt.Title__c;
            item.jobId = alt.Job_Requisition__c;
            item.jobTitle = alt.Job_Requisition__r != null ? alt.Job_Requisition__r.Job_Title__c : null;
            item.jobCode = alt.Job_Requisition__r != null ? alt.Job_Requisition__r.Job_Code__c : null;
            item.candidateId = alt.Candidate__c;

            // Candidate name resolution
            String candName = null;
            if (alt.Candidate__r != null) {
                candName = alt.Candidate__r.Candidate_Name__c;
            } else if (alt.Interview__r != null) {
                if (alt.Interview__r.Job_Application__r != null && alt.Interview__r.Job_Application__r.Candidate__r != null) {
                    candName = alt.Interview__r.Job_Application__r.Candidate__r.Candidate_Name__c;
                } else if (alt.Interview__r.Candidate__r != null) {
                    candName = alt.Interview__r.Candidate__r.Candidate_Name__c;
                }
            }
            item.candidateName = candName;

            item.applicationId = alt.Job_Application__c;
            item.interviewId = alt.Interview__c;
            item.evidence = alt.Evidence__c;
            item.explanation = alt.Explanation__c;
            item.calculatedDate = alt.Last_Evaluated_Date__c;
            item.acknowledgedByName = alt.Acknowledged_By__r != null ? alt.Acknowledged_By__r.Name : null;
            item.acknowledgedDate = alt.Acknowledged_Date__c;
            item.acknowledgedNotes = alt.Acknowledged_Notes__c;

            item.isActive = (alt.Status__c == STATUS_ACTIVE);
            item.isAcknowledged = (alt.Status__c == STATUS_ACKNOWLEDGED);
            item.isResolved = (alt.Status__c == STATUS_RESOLVED);
            item.canReschedule = (alt.Interview__c != null && alt.Status__c != STATUS_RESOLVED);

            dto.alerts.add(item);
        }

        return dto;
    }

    /**
     * @description Acknowledges an alert by recording user and recruiter notes without mutating underlying data.
     */
    public static ActionCenterResult acknowledgeAlert(Id alertId, String recruiterNotes) {
        ActionCenterResult res = new ActionCenterResult();
        if (alertId == null) {
            res.isSuccess = false;
            res.message = 'Alert ID is required.';
            return res;
        }

        try {
            if (!Schema.sObjectType.Recruitment_Alert__c.isUpdateable()) {
                res.isSuccess = false;
                res.message = 'Insufficient permissions to update recruitment alerts.';
                return res;
            }

            List<Recruitment_Alert__c> alerts = [
                SELECT Id, Status__c, Acknowledged_By__c, Acknowledged_Date__c, Acknowledged_Notes__c
                FROM Recruitment_Alert__c
                WHERE Id = :alertId
                LIMIT 1
            ];

            if (alerts.isEmpty()) {
                res.isSuccess = false;
                res.message = 'Alert record not found.';
                return res;
            }

            Recruitment_Alert__c alt = alerts[0];
            alt.Status__c = STATUS_ACKNOWLEDGED;
            alt.Acknowledged_By__c = UserInfo.getUserId();
            alt.Acknowledged_Date__c = Datetime.now();
            alt.Acknowledged_Notes__c = String.isNotBlank(recruiterNotes) ? recruiterNotes.abbreviate(255) : 'Acknowledged by recruiter.';
            update alt;

            res.isSuccess = true;
            res.message = 'Alert successfully acknowledged.';
            res.recordId = alt.Id;
        } catch (Exception ex) {
            res.isSuccess = false;
            res.message = 'Failed to acknowledge alert: ' + ex.getMessage();
        }
        return res;
    }

    /**
     * @description Explicit, human-confirmed rescheduling of an overdue interview.
     * Validates required future datetime, updates Interview__c, and resolves the corresponding alert.
     */
    public static ActionCenterResult rescheduleInterview(Id interviewId, Datetime newDateTime, String notes) {
        ActionCenterResult res = new ActionCenterResult();
        if (interviewId == null) {
            res.isSuccess = false;
            res.message = 'Interview record ID is required.';
            return res;
        }
        if (newDateTime == null) {
            res.isSuccess = false;
            res.message = 'New scheduled interview date and time is required.';
            return res;
        }
        if (newDateTime <= Datetime.now()) {
            res.isSuccess = false;
            res.message = 'Rescheduled interview date must be in the future.';
            return res;
        }

        try {
            if (!Schema.sObjectType.Interview__c.isUpdateable()) {
                res.isSuccess = false;
                res.message = 'Insufficient permissions to reschedule interviews.';
                return res;
            }

            List<Interview__c> ivList = [
                SELECT Id, Name, Interview_Name__c, Interview_Date__c, Interview_Status__c,
                       Interview_Feedback__c, Candidate__c, Job_Application__c
                FROM Interview__c
                WHERE Id = :interviewId
                LIMIT 1
            ];

            if (ivList.isEmpty()) {
                res.isSuccess = false;
                res.message = 'Interview record not found.';
                return res;
            }

            Interview__c iv = ivList[0];
            Datetime oldDate = iv.Interview_Date__c;
            iv.Interview_Date__c = newDateTime;
            iv.Interview_Status__c = 'Scheduled';

            String updateLog = '[Human Reschedule by ' + UserInfo.getName() + ' on ' + Datetime.now().format('MMM dd, yyyy HH:mm') +
                ']: Previous: ' + (oldDate != null ? oldDate.format('MMM dd, yyyy HH:mm') : 'None') +
                ' -> New: ' + newDateTime.format('MMM dd, yyyy HH:mm') + '.';
            if (String.isNotBlank(notes)) {
                updateLog += ' Notes: ' + notes;
            }

            if (String.isNotBlank(iv.Interview_Feedback__c)) {
                iv.Interview_Feedback__c = updateLog + '\n\n' + iv.Interview_Feedback__c;
            } else {
                iv.Interview_Feedback__c = updateLog;
            }

            update iv;

            // Resolve the corresponding alert
            String alertKey = 'ALERT-OVERDUEINT-' + interviewId;
            List<Recruitment_Alert__c> relatedAlerts = [
                SELECT Id, Status__c, Explanation__c
                FROM Recruitment_Alert__c
                WHERE Alert_Key__c = :alertKey OR Interview__c = :interviewId
            ];
            for (Recruitment_Alert__c alt : relatedAlerts) {
                alt.Status__c = STATUS_RESOLVED;
                alt.Explanation__c = (alt.Explanation__c != null ? alt.Explanation__c + '\n' : '') +
                    '[Resolved: Explicitly rescheduled to ' + newDateTime.format('MMM dd, yyyy HH:mm') + ' by recruiter.]';
            }
            if (!relatedAlerts.isEmpty()) {
                update relatedAlerts;
            }

            res.isSuccess = true;
            res.message = 'Interview successfully rescheduled to ' + newDateTime.format('MMM dd, yyyy HH:mm') + '.';
            res.recordId = iv.Id;
        } catch (Exception ex) {
            res.isSuccess = false;
            res.message = 'Failed to reschedule interview: ' + ex.getMessage();
        }
        return res;
    }

    /**
     * @description Fetches interview details for display in the human-in-the-loop reschedule modal.
     */
    public static InterviewDetailDTO getInterviewDetails(Id interviewId) {
        if (interviewId == null) return null;

        List<Interview__c> ivList = [
            SELECT Id, Name, Interview_Name__c, Interview_Date__c, Interview_Status__c,
                   Interview_Type__c, Interview_Feedback__c, Candidate__c, Candidate__r.Candidate_Name__c,
                   Job_Application__c, Job_Application__r.Job_Requisition__c,
                   Job_Application__r.Job_Requisition__r.Job_Title__c,
                   Job_Application__r.Candidate__r.Candidate_Name__c
            FROM Interview__c
            WHERE Id = :interviewId
            LIMIT 1
        ];

        if (ivList.isEmpty()) return null;

        Interview__c iv = ivList[0];
        InterviewDetailDTO dto = new InterviewDetailDTO();
        dto.interviewId = iv.Id;
        dto.interviewName = iv.Interview_Name__c;
        dto.scheduledDate = iv.Interview_Date__c;
        dto.interviewType = iv.Interview_Type__c;
        dto.interviewStatus = iv.Interview_Status__c;
        dto.currentFeedback = iv.Interview_Feedback__c;

        if (iv.Job_Application__r != null && iv.Job_Application__r.Candidate__r != null) {
            dto.candidateName = iv.Job_Application__r.Candidate__r.Candidate_Name__c;
            dto.candidateId = iv.Job_Application__r.Candidate__c;
        } else if (iv.Candidate__r != null) {
            dto.candidateName = iv.Candidate__r.Candidate_Name__c;
            dto.candidateId = iv.Candidate__c;
        }

        if (iv.Job_Application__r != null && iv.Job_Application__r.Job_Requisition__r != null) {
            dto.jobTitle = iv.Job_Application__r.Job_Requisition__r.Job_Title__c;
            dto.jobId = iv.Job_Application__r.Job_Requisition__c;
        }

        return dto;
    }
}
