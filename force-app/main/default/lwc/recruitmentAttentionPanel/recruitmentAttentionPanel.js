import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRiskIntelligence from '@salesforce/apex/RecruitmentRiskController.getRiskIntelligence';
import getJobOptions from '@salesforce/apex/RecruitmentRiskController.getJobOptions';

export default class RecruitmentAttentionPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api isEmbedded = false;

    @track selectedJobId = '';
    @track selectedCategory = 'all';
    @track selectedSeverity = '';
    @track isLoading = true;
    @track errorMessage = '';

    @track data = {
        totalHighAttentionCount: 0,
        totalRequiresReviewCount: 0,
        totalInformationalCount: 0,
        totalOverdueInterviews: 0,
        totalJobsNeedingAttention: 0,
        allSignals: [],
        requisitionSignals: [],
        pipelineSignals: [],
        skillGapSignals: [],
        interviewSignals: [],
        recurringSkillGaps: [],
        responsibleAiNotice: ''
    };

    @track jobOptions = [{ label: 'All Jobs', value: '' }];

    severityOptions = [
        { label: 'All Severities', value: '' },
        { label: 'High Attention', value: 'High Attention' },
        { label: 'Requires Recruiter Review', value: 'Requires Recruiter Review' },
        { label: 'Informational', value: 'Informational' }
    ];

    categoryTabs = [
        { id: 'all', label: 'All Signals', count: 0, tabClass: 'slds-tabs_default__item slds-is-active' },
        { id: 'Requisition Attention', label: 'Requisition Attention', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Pipeline Bottlenecks', label: 'Pipeline Bottlenecks', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Skill Gaps', label: 'Skill Gaps', count: 0, tabClass: 'slds-tabs_default__item' },
        { id: 'Interview Attention', label: 'Interview Attention', count: 0, tabClass: 'slds-tabs_default__item' }
    ];

    connectedCallback() {
        if (this.recordId) {
            this.selectedJobId = this.recordId;
        }
        this.loadJobFilterOptions();
        this.fetchData();
    }

    loadJobFilterOptions() {
        getJobOptions()
            .then(result => {
                if (result && result.length > 0) {
                    this.jobOptions = result;
                }
            })
            .catch(error => {
                console.error('Error fetching job options:', error);
            });
    }

    @api
    refresh() {
        this.fetchData();
    }

    fetchData() {
        this.isLoading = true;
        this.errorMessage = '';

        const sevParam = this.selectedSeverity || null;
        const catParam = (this.selectedCategory !== 'all') ? this.selectedCategory : null;

        getRiskIntelligence({
            jobId: this.selectedJobId || null,
            severityFilter: sevParam,
            signalTypeFilter: catParam
        })
            .then(result => {
                this.data = result;
                if (this.data && this.data.allSignals) {
                    this.data.allSignals = this.data.allSignals.map(sig => {
                        let cClass = 'signal-card slds-p-around_medium ';
                        let bClass = 'slds-badge slds-m-right_x-small ';
                        if (sig.severity === 'High Attention') {
                            cClass += 'signal-high';
                            bClass += 'badge-high';
                        } else if (sig.severity === 'Requires Recruiter Review') {
                            cClass += 'signal-review';
                            bClass += 'badge-review';
                        } else {
                            cClass += 'signal-info';
                            bClass += 'badge-info';
                        }
                        return {
                            ...sig,
                            cardClass: cClass,
                            badgeClass: bClass
                        };
                    });
                }
                this.updateCategoryCounts();
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : error.message;
                this.isLoading = false;
                this.showToast('Error Loading Attention Signals', this.errorMessage, 'error');
            });
    }

    updateCategoryCounts() {
        const reqCount = this.data.requisitionSignals ? this.data.requisitionSignals.length : 0;
        const pipeCount = this.data.pipelineSignals ? this.data.pipelineSignals.length : 0;
        const skillCount = this.data.skillGapSignals ? this.data.skillGapSignals.length : 0;
        const intCount = this.data.interviewSignals ? this.data.interviewSignals.length : 0;
        const total = (this.data.allSignals ? this.data.allSignals.length : 0);

        this.categoryTabs = [
            { id: 'all', label: 'All Signals (' + total + ')', count: total, tabClass: 'slds-tabs_default__item' + (this.selectedCategory === 'all' ? ' slds-is-active' : '') },
            { id: 'Requisition Attention', label: 'Requisition Attention (' + reqCount + ')', count: reqCount, tabClass: 'slds-tabs_default__item' + (this.selectedCategory === 'Requisition Attention' ? ' slds-is-active' : '') },
            { id: 'Pipeline Bottlenecks', label: 'Pipeline Bottlenecks (' + pipeCount + ')', count: pipeCount, tabClass: 'slds-tabs_default__item' + (this.selectedCategory === 'Pipeline Bottlenecks' ? ' slds-is-active' : '') },
            { id: 'Skill Gaps', label: 'Skill Gaps (' + skillCount + ')', count: skillCount, tabClass: 'slds-tabs_default__item' + (this.selectedCategory === 'Skill Gaps' ? ' slds-is-active' : '') },
            { id: 'Interview Attention', label: 'Interview Attention (' + intCount + ')', count: intCount, tabClass: 'slds-tabs_default__item' + (this.selectedCategory === 'Interview Attention' ? ' slds-is-active' : '') }
        ];
    }

    // Filter Change Handlers
    handleJobChange(event) {
        this.selectedJobId = event.detail.value;
        this.fetchData();
    }

    handleSeverityChange(event) {
        this.selectedSeverity = event.detail.value;
        this.fetchData();
    }

    handleTabSelect(event) {
        const tabId = event.currentTarget.dataset.id;
        this.selectedCategory = tabId;
        this.updateCategoryCounts();
        this.fetchData();
    }

    handleReset() {
        this.selectedJobId = this.recordId || '';
        this.selectedCategory = 'all';
        this.selectedSeverity = '';
        this.fetchData();
    }

    // Drill-down Action Handlers
    handleViewJob(event) {
        const jId = event.currentTarget.dataset.jobid;
        if (jId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: jId,
                    actionName: 'view'
                }
            });
        }
    }

    handleMatchIntelligence(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Match_Intelligence'
            }
        });
    }

    handleCandidateComparison(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Candidate_Comparison'
            }
        });
    }

    handleViewInterview(event) {
        const ivId = event.currentTarget.dataset.ivid;
        if (ivId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: ivId,
                    actionName: 'view'
                }
            });
        }
    }

    handleAskCopilot(event) {
        const promptContext = event.currentTarget.dataset.title || 'Recruitment Risk Review';
        this.dispatchEvent(new CustomEvent('launchcopilot', {
            bubbles: true,
            composed: true,
            detail: { prompt: promptContext }
        }));

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'AI_Recruitment_Assistant'
            }
        });
    }

    // Getters
    get hasSignals() {
        return this.data && this.data.allSignals && this.data.allSignals.length > 0;
    }

    get displaySignals() {
        return this.data ? this.data.allSignals : [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
