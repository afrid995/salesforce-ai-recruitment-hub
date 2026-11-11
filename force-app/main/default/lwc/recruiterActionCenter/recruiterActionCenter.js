import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActionCenterData from '@salesforce/apex/RecruitmentAlertController.getActionCenterData';
import syncAlertsNow from '@salesforce/apex/RecruitmentAlertController.syncAlertsNow';
import acknowledgeAlert from '@salesforce/apex/RecruitmentAlertController.acknowledgeAlert';
import rescheduleInterview from '@salesforce/apex/RecruitmentAlertController.rescheduleInterview';
import getInterviewDetails from '@salesforce/apex/RecruitmentAlertController.getInterviewDetails';
import getJobOptions from '@salesforce/apex/RecruitmentAlertController.getJobOptions';

export default class RecruiterActionCenter extends NavigationMixin(LightningElement) {
    @track selectedJobId = '';
    @track selectedStatus = 'Active';
    @track selectedSeverity = '';
    @track selectedCategory = 'all';

    @track isLoading = true;
    @track errorMessage = '';

    @track data = {
        totalAlerts: 0,
        activeAlertsCount: 0,
        highAttentionCount: 0,
        requiresReviewCount: 0,
        informationalCount: 0,
        acknowledgedCount: 0,
        resolvedCount: 0,
        alerts: [],
        responsibleAiNotice: ''
    };

    @track jobOptions = [{ label: 'All Jobs', value: '' }];

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Active', value: 'Active' },
        { label: 'Acknowledged', value: 'Acknowledged' },
        { label: 'Resolved', value: 'Resolved' }
    ];

    severityOptions = [
        { label: 'All Severities', value: '' },
        { label: 'High Attention', value: 'High Attention' },
        { label: 'Requires Recruiter Review', value: 'Requires Recruiter Review' },
        { label: 'Informational', value: 'Informational' }
    ];

    @track categoryTabs = [
        { id: 'all', label: 'All Signals', count: 0, tabClass: 'slds-tabs_default__item slds-is-active' },
        { id: 'Requisition Attention', label: 'Requisition Attention', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Pipeline Bottlenecks', label: 'Pipeline Bottlenecks', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Skill Gaps', label: 'Skill Gaps', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Interview Attention', label: 'Interview Attention', count: 0, tabClass: 'slds-tabs_default__item' }
    ];

    // Reschedule Modal State
    @track showRescheduleModal = false;
    @track modalLoading = false;
    @track currentInterview = {};
    @track newRescheduleDateTime = '';
    @track rescheduleNotes = '';

    // Acknowledge Modal State
    @track showAckModal = false;
    @track ackAlertId = '';
    @track ackAlertTitle = '';
    @track ackNotes = '';

    connectedCallback() {
        this.loadJobFilterOptions();
        this.fetchAlerts();
    }

    loadJobFilterOptions() {
        getJobOptions()
            .then(result => {
                if (result && result.length > 0) {
                    this.jobOptions = result;
                }
            })
            .catch(error => {
                console.error('Error loading job options:', error);
            });
    }

    fetchAlerts() {
        this.isLoading = true;
        this.errorMessage = '';

        getActionCenterData({
            jobId: this.selectedJobId || null,
            severityFilter: this.selectedSeverity || null,
            statusFilter: this.selectedStatus || null,
            alertTypeFilter: (this.selectedCategory !== 'all') ? this.selectedCategory : null
        })
            .then(result => {
                this.processAlertData(result);
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error && error.body ? error.body.message : 'Error loading alerts.';
                this.isLoading = false;
            });
    }

    processAlertData(result) {
        if (!result) return;
        this.data = result;

        if (this.data.alerts) {
            this.data.alerts = this.data.alerts.map(alt => {
                let cardClass = 'alert-card slds-p-around_medium ';
                let badgeClass = 'slds-badge slds-m-right_x-small ';
                let statusBadgeClass = 'slds-badge slds-m-right_x-small ';

                if (alt.severity === 'High Attention') {
                    cardClass += 'card-high';
                    badgeClass += 'badge-high';
                } else if (alt.severity === 'Requires Recruiter Review') {
                    cardClass += 'card-review';
                    badgeClass += 'badge-review';
                } else {
                    cardClass += 'card-info';
                    badgeClass += 'badge-info';
                }

                if (alt.status === 'Active') {
                    statusBadgeClass += 'badge-active';
                } else if (alt.status === 'Acknowledged') {
                    statusBadgeClass += 'badge-ack';
                } else {
                    statusBadgeClass += 'badge-resolved';
                }

                let formattedDate = alt.calculatedDate ? new Date(alt.calculatedDate).toLocaleString() : '';
                let formattedAckDate = alt.acknowledgedDate ? new Date(alt.acknowledgedDate).toLocaleString() : '';

                return {
                    ...alt,
                    cardClass: cardClass,
                    badgeClass: badgeClass,
                    statusBadgeClass: statusBadgeClass,
                    formattedDate: formattedDate,
                    formattedAckDate: formattedAckDate
                };
            });
        }

        this.updateTabCounts();
    }

    updateTabCounts() {
        const alerts = this.data.alerts || [];
        this.categoryTabs = this.categoryTabs.map(tab => {
            let count = 0;
            if (tab.id === 'all') {
                count = alerts.length;
            } else {
                count = alerts.filter(a => a.alertType === tab.id).length;
            }
            const isActive = tab.id === this.selectedCategory;
            return {
                ...tab,
                count: count,
                tabClass: isActive ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item'
            };
        });
    }

    get hasNoAlerts() {
        return !this.data || !this.data.alerts || this.data.alerts.length === 0;
    }

    get highAttentionList() {
        return (this.data.alerts || []).filter(a => a.severity === 'High Attention');
    }

    get hasHighAttentionAlerts() {
        return this.highAttentionList.length > 0;
    }

    get reviewList() {
        return (this.data.alerts || []).filter(a => a.severity === 'Requires Recruiter Review');
    }

    get hasReviewAlerts() {
        return this.reviewList.length > 0;
    }

    get infoList() {
        return (this.data.alerts || []).filter(a => a.severity === 'Informational' || a.status === 'Resolved');
    }

    get hasInfoAlerts() {
        return this.infoList.length > 0;
    }

    // Filter Change Handlers
    handleJobChange(event) {
        this.selectedJobId = event.detail.value;
        this.fetchAlerts();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.fetchAlerts();
    }

    handleSeverityChange(event) {
        this.selectedSeverity = event.detail.value;
        this.fetchAlerts();
    }

    handleCategoryTabClick(event) {
        this.selectedCategory = event.currentTarget.dataset.tab;
        this.categoryTabs = this.categoryTabs.map(tab => {
            return {
                ...tab,
                tabClass: (tab.id === this.selectedCategory)
                    ? 'slds-tabs_default__item slds-is-active'
                    : 'slds-tabs_default__item'
            };
        });
        this.fetchAlerts();
    }

    handleClearFilters() {
        this.selectedJobId = '';
        this.selectedStatus = 'Active';
        this.selectedSeverity = '';
        this.selectedCategory = 'all';
        this.fetchAlerts();
    }

    handleRefresh() {
        this.fetchAlerts();
    }

    handleSyncNow() {
        this.isLoading = true;
        syncAlertsNow()
            .then(result => {
                this.processAlertData(result);
                this.isLoading = false;
                this.showToast('Success', 'Recruitment alerts synchronized with live data.', 'success');
            })
            .catch(error => {
                this.errorMessage = error && error.body ? error.body.message : 'Error syncing alerts.';
                this.isLoading = false;
            });
    }

    // Reschedule Modal Methods
    handleOpenRescheduleModal(event) {
        const interviewId = event.currentTarget.dataset.id;
        this.modalLoading = true;
        this.showRescheduleModal = true;
        this.newRescheduleDateTime = '';
        this.rescheduleNotes = '';

        getInterviewDetails({ interviewId: interviewId })
            .then(result => {
                if (result) {
                    this.currentInterview = {
                        ...result,
                        formattedDate: result.scheduledDate ? new Date(result.scheduledDate).toLocaleString() : 'Not Set'
                    };
                }
                this.modalLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Could not load interview details: ' + (error.body ? error.body.message : error), 'error');
                this.modalLoading = false;
                this.showRescheduleModal = false;
            });
    }

    handleCloseRescheduleModal() {
        this.showRescheduleModal = false;
    }

    handleRescheduleDateChange(event) {
        this.newRescheduleDateTime = event.detail.value;
    }

    handleRescheduleNotesChange(event) {
        this.rescheduleNotes = event.detail.value;
    }

    get isRescheduleDisabled() {
        if (!this.newRescheduleDateTime) return true;
        const selected = new Date(this.newRescheduleDateTime);
        return selected <= new Date();
    }

    handleConfirmReschedule() {
        if (!this.newRescheduleDateTime) {
            this.showToast('Error', 'Please select a new interview date and time.', 'error');
            return;
        }

        const selectedDate = new Date(this.newRescheduleDateTime);
        if (selectedDate <= new Date()) {
            this.showToast('Error', 'Rescheduled interview date must be in the future.', 'error');
            return;
        }

        this.modalLoading = true;
        rescheduleInterview({
            interviewId: this.currentInterview.interviewId,
            newDateTime: this.newRescheduleDateTime,
            notes: this.rescheduleNotes
        })
            .then(result => {
                this.modalLoading = false;
                this.showRescheduleModal = false;
                if (result.isSuccess) {
                    this.showToast('Rescheduled', result.message, 'success');
                    this.fetchAlerts();
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                this.modalLoading = false;
                this.showToast('Error', error && error.body ? error.body.message : 'Rescheduling failed.', 'error');
            });
    }

    // Acknowledge Modal Methods
    handleOpenAcknowledgeModal(event) {
        this.ackAlertId = event.currentTarget.dataset.id;
        this.ackAlertTitle = event.currentTarget.dataset.title;
        this.ackNotes = '';
        this.showAckModal = true;
    }

    handleCloseAckModal() {
        this.showAckModal = false;
    }

    handleAckNotesChange(event) {
        this.ackNotes = event.detail.value;
    }

    get isAckDisabled() {
        return !this.ackNotes || this.ackNotes.trim().length === 0;
    }

    handleConfirmAcknowledge() {
        acknowledgeAlert({
            alertId: this.ackAlertId,
            notes: this.ackNotes
        })
            .then(result => {
                this.showAckModal = false;
                if (result.isSuccess) {
                    this.showToast('Acknowledged', result.message, 'success');
                    this.fetchAlerts();
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error && error.body ? error.body.message : 'Acknowledgement failed.', 'error');
            });
    }

    // Navigation Handlers
    handleNavigateJob(event) {
        const jobId = event.currentTarget.dataset.id;
        if (jobId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: jobId,
                    objectApiName: 'Job_Requisition__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleNavigateMatch() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Match_Intelligence'
            }
        });
    }

    handleNavigateCompare() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Candidate_Comparison'
            }
        });
    }

    handleOpenCopilot() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'AI_Recruitment_Assistant'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
