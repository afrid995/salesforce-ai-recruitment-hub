import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/RecruitmentIntelligenceController.getDashboardData';

export default class RecruitmentIntelligenceDashboard extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track data = null;
    @track errorMessage = '';

    // Filters
    @track selectedJobId = '';
    @track selectedDepartment = '';
    @track selectedJobStatus = '';
    @track selectedAppStatus = '';
    @track selectedRecommendationTier = '';

    // Recommendation tier options
    recommendationOptions = [
        { label: 'All Recommendation Tiers', value: '' },
        { label: 'Strong Match (>= 80%)', value: 'Strong Match' },
        { label: 'Good Match (>= 65%)', value: 'Good Match' },
        { label: 'Moderate Match (>= 50%)', value: 'Moderate Match' },
        { label: 'Low Match (< 50%)', value: 'Low Match' }
    ];

    connectedCallback() {
        this.fetchDashboard();
    }

    async fetchDashboard() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const res = await getDashboardData({
                jobId: this.selectedJobId,
                department: this.selectedDepartment,
                jobStatus: this.selectedJobStatus,
                appStatus: this.selectedAppStatus,
                recommendationTier: this.selectedRecommendationTier
            });
            this.data = res;
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error loading Recruitment Intelligence data.';
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.fetchDashboard();
    }

    handleFilterChange(event) {
        const field = event.target.dataset.filter;
        const val = event.detail.value;
        if (field === 'jobId') this.selectedJobId = val;
        else if (field === 'department') this.selectedDepartment = val;
        else if (field === 'jobStatus') this.selectedJobStatus = val;
        else if (field === 'appStatus') this.selectedAppStatus = val;
        else if (field === 'recommendationTier') this.selectedRecommendationTier = val;

        this.fetchDashboard();
    }

    handleResetFilters() {
        this.selectedJobId = '';
        this.selectedDepartment = '';
        this.selectedJobStatus = '';
        this.selectedAppStatus = '';
        this.selectedRecommendationTier = '';
        this.fetchDashboard();
    }

    // Getters for options
    get jobOptions() {
        return this.data?.filterOptions?.jobs || [{ label: 'All Jobs', value: '' }];
    }

    get departmentOptions() {
        return this.data?.filterOptions?.departments || [{ label: 'All Departments', value: '' }];
    }

    get jobStatusOptions() {
        return this.data?.filterOptions?.jobStatuses || [{ label: 'All Job Statuses', value: '' }];
    }

    get appStatusOptions() {
        return this.data?.filterOptions?.applicationStatuses || [{ label: 'All Application Statuses', value: '' }];
    }

    get hasData() {
        return !!this.data && !this.isLoading;
    }

    get hasAttentionItems() {
        return this.data?.recruiterAttentionItems && this.data.recruiterAttentionItems.length > 0;
    }

    get attentionItems() {
        return this.data?.recruiterAttentionItems || [];
    }

    get jobHealthRows() {
        return (this.data?.jobHealthTable || []).map(row => {
            let scoreClass = 'badge-unavailable';
            if (row.hasEvaluations) {
                if (row.averageMatchScore >= 80) scoreClass = 'badge-score-strong';
                else if (row.averageMatchScore >= 65) scoreClass = 'badge-score-good';
                else if (row.averageMatchScore >= 50) scoreClass = 'badge-score-moderate';
                else scoreClass = 'badge-score-low';
            }
            return {
                ...row,
                scoreBadgeClass: `slds-badge ${scoreClass}`,
                scoreDisplay: row.hasEvaluations ? `${row.averageMatchScore}%` : 'Unavailable',
                highestScoreDisplay: row.hasEvaluations ? `${row.highestMatchScore}% (${row.highestMatchCandidateName})` : '—'
            };
        });
    }

    get avgScoreBadgeClass() {
        const score = this.data?.kpis?.averageCandidateMatchScore || 0;
        if (score >= 65) return 'slds-badge badge-score-good';
        if (score >= 50) return 'slds-badge badge-score-moderate';
        return 'slds-badge badge-score-low';
    }

    get formattedTotalEvaluations() {
        return this.data?.matchCoverage?.totalEvaluatedMatches || 0;
    }

    // Navigation Methods
    navigateToJobRecord(event) {
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

    navigateToKpi(event) {
        const target = event.currentTarget.dataset.target;
        if (target === 'jobs') {
            this.navigateToList('Job_Requisition__c');
        } else if (target === 'candidates') {
            this.navigateToList('Candidate__c');
        } else if (target === 'applications') {
            this.navigateToList('Job_Application__c');
        } else if (target === 'interviews') {
            this.navigateToList('Interview__c');
        } else if (target === 'matches') {
            this.navigateToTab('Match_Intelligence');
        }
    }

    navigateToList(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'list'
            },
            state: {
                filterName: 'All'
            }
        });
    }

    navigateToTab(tabApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: tabApiName
            }
        });
    }

    handleOpenMatchIntelligence() {
        this.navigateToTab('Match_Intelligence');
    }

    handleOpenCandidateComparison() {
        this.navigateToTab('Candidate_Comparison');
    }

    handleOpenAgentforce() {
        this.navigateToTab('AI_Recruitment_Assistant');
    }

    handleAttentionAction(event) {
        const target = event.currentTarget.dataset.target;
        const recordId = event.currentTarget.dataset.id;

        if (target === 'Job' && recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Job_Requisition__c',
                    actionName: 'view'
                }
            });
        } else if (target === 'Match') {
            this.navigateToTab('Match_Intelligence');
        } else if (target === 'Compare') {
            this.navigateToTab('Candidate_Comparison');
        } else if (target === 'Interview' && recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Interview__c',
                    actionName: 'view'
                }
            });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
