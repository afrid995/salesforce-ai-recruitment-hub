import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getInitialContext from '@salesforce/apex/CandidateJobMatchUIController.getInitialContext';
import getMatchesForJob from '@salesforce/apex/CandidateJobMatchUIController.getMatchesForJob';
import getMatchDetail from '@salesforce/apex/CandidateJobMatchUIController.getMatchDetail';
import recalculateJobMatches from '@salesforce/apex/CandidateJobMatchUIController.recalculateJobMatches';

export default class CandidateJobMatchPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    @track isLoading = true;
    @track activeJobs = [];
    @track selectedJobId = null;
    @track selectedMatchId = null;
    @track matchDetail = null;
    @track rawRankedCandidates = [];
    @track weights = {
        skillWeight: 50.00,
        experienceWeight: 25.00,
        qualificationWeight: 15.00,
        locationWeight: 10.00,
        totalWeight: 100.00
    };

    @track isExplainOpen = false;
    @track viewMode = 'split'; // 'split', 'list-only', 'detail-only'
    @track isComparisonMode = false;
    @track selectedCompareMatchIds = [];

    connectedCallback() {
        this.loadInitialData();
    }

    loadInitialData() {
        this.isLoading = true;
        getInitialContext({ recordId: this.recordId })
            .then((context) => {
                if (context) {
                    this.activeJobs = context.activeJobs || [];
                    if (context.weights) {
                        this.weights = context.weights;
                    }
                    this.selectedJobId = context.selectedJobId;
                    this.selectedMatchId = context.selectedMatchId;
                    this.matchDetail = context.matchDetail;
                    this.rawRankedCandidates = context.rankedCandidates || [];
                }
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error loading initial match intelligence context:', error);
                this.showToast('Error Loading Data', this.getErrorMessage(error), 'error');
            });
    }

    // =========================================================================
    // COMPUTED GETTERS
    // =========================================================================

    get jobOptions() {
        if (!this.activeJobs || this.activeJobs.length === 0) {
            return [];
        }
        return this.activeJobs.map((job) => {
            const codeStr = job.Job_Code__c ? ` (${job.Job_Code__c})` : '';
            return {
                label: `${job.Job_Title__c}${codeStr}`,
                value: job.Id
            };
        });
    }

    get selectedJobTitle() {
        if (!this.selectedJobId || !this.activeJobs) {
            return 'Select a Job';
        }
        const job = this.activeJobs.find(j => j.Id === this.selectedJobId);
        return job ? job.Job_Title__c : 'Job Requisition';
    }

    get selectedJobCode() {
        if (!this.selectedJobId || !this.activeJobs) {
            return '';
        }
        const job = this.activeJobs.find(j => j.Id === this.selectedJobId);
        return job && job.Job_Code__c ? job.Job_Code__c : 'Active';
    }

    get hasMatchDetail() {
        return !!this.matchDetail;
    }

    get rankedCandidatesCount() {
        return this.rawRankedCandidates ? this.rawRankedCandidates.length : 0;
    }

    get rankedCandidates() {
        if (!this.rawRankedCandidates) {
            return [];
        }
        return this.rawRankedCandidates.map((cand) => {
            const isSelected = cand.matchId === this.selectedMatchId;
            const isCompareSelected = this.selectedCompareMatchIds.includes(cand.matchId);
            return {
                ...cand,
                isSelected: isSelected,
                isCompareSelected: isCompareSelected,
                rowClass: isSelected ? 'candidate-row selected-row' : 'candidate-row',
                overallScoreFormatted: cand.overallScore != null ? cand.overallScore.toFixed(2) : '0.00',
                badgeClass: this.getBadgeClass(cand.recommendation),
                scoreClass: this.getScoreClass(cand.recommendation)
            };
        });
    }

    get selectedCompareCount() {
        return this.selectedCompareMatchIds ? this.selectedCompareMatchIds.length : 0;
    }

    get isCompareDisabled() {
        return this.selectedCompareCount < 2;
    }

    get compareButtonLabel() {
        if (this.selectedCompareCount >= 2) {
            return `Compare (${this.selectedCompareCount})`;
        }
        return 'Compare (Select 2-5)';
    }

    get hasMatchedSkills() {
        return this.matchDetail && this.matchDetail.matchedSkillsList && this.matchDetail.matchedSkillsList.length > 0;
    }

    get hasMissingSkills() {
        return this.matchDetail && this.matchDetail.missingSkillsList && this.matchDetail.missingSkillsList.length > 0;
    }

    get matchedSkillsCount() {
        return this.hasMatchedSkills ? this.matchDetail.matchedSkillsList.length : 0;
    }

    get missingSkillsCount() {
        return this.hasMissingSkills ? this.matchDetail.missingSkillsList.length : 0;
    }

    // Styles for Progress Bars
    get skillBarStyle() {
        const val = this.matchDetail && this.matchDetail.skillScore != null ? this.matchDetail.skillScore : 0;
        return `width: ${val}%;`;
    }

    get expBarStyle() {
        const val = this.matchDetail && this.matchDetail.experienceScore != null ? this.matchDetail.experienceScore : 0;
        return `width: ${val}%;`;
    }

    get qualBarStyle() {
        const val = this.matchDetail && this.matchDetail.qualificationScore != null ? this.matchDetail.qualificationScore : 0;
        return `width: ${val}%;`;
    }

    get locBarStyle() {
        const val = this.matchDetail && this.matchDetail.locationScore != null ? this.matchDetail.locationScore : 0;
        return `width: ${val}%;`;
    }

    // Badge styling helpers
    get detailBadgeClass() {
        return this.getBadgeClass(this.matchDetail ? this.matchDetail.recommendation : '');
    }

    get scoreBadgeStyle() {
        const rec = this.matchDetail ? this.matchDetail.recommendation : '';
        return `score-badge ${this.getBadgeClass(rec)}`;
    }

    getBadgeClass(recommendation) {
        if (!recommendation) return 'slds-badge slds-badge_lightest';
        if (recommendation === 'Strong Match') {
            return 'slds-badge badge-strong';
        } else if (recommendation === 'Good Match') {
            return 'slds-badge badge-good';
        } else if (recommendation === 'Moderate Match') {
            return 'slds-badge badge-moderate';
        }
        return 'slds-badge badge-low';
    }

    getScoreClass(recommendation) {
        if (!recommendation) return 'score-text';
        if (recommendation === 'Strong Match') return 'score-text text-strong';
        if (recommendation === 'Good Match') return 'score-text text-good';
        if (recommendation === 'Moderate Match') return 'score-text text-moderate';
        return 'score-text text-low';
    }

    // Layout Classes
    get listColumnClass() {
        if (this.viewMode === 'list-only') {
            return 'slds-col slds-size_1-of-1';
        } else if (this.viewMode === 'detail-only') {
            return 'slds-hide';
        }
        return 'slds-col slds-size_1-of-1 slds-medium-size_12-of-12 slds-large-size_4-of-12 slds-m-bottom_medium';
    }

    get detailColumnClass() {
        if (this.viewMode === 'detail-only') {
            return 'slds-col slds-size_1-of-1';
        } else if (this.viewMode === 'list-only') {
            return 'slds-hide';
        }
        return 'slds-col slds-size_1-of-1 slds-medium-size_12-of-12 slds-large-size_8-of-12';
    }

    get explainButtonLabel() {
        return this.isExplainOpen ? 'Hide Formula' : 'Explain Score';
    }

    get explainButtonIcon() {
        return this.isExplainOpen ? 'utility:chevrondown' : 'utility:formula';
    }

    get viewModeIcon() {
        if (this.viewMode === 'split') return 'utility:side_list';
        if (this.viewMode === 'detail-only') return 'utility:expand_alt';
        return 'utility:contract_alt';
    }

    get viewModeTitle() {
        if (this.viewMode === 'split') return 'Switch to Full Detail View';
        if (this.viewMode === 'detail-only') return 'Switch to Candidate List View';
        return 'Switch to Split View';
    }

    // =========================================================================
    // EVENT HANDLERS
    // =========================================================================

    handleJobChange(event) {
        const jobId = event.detail.value;
        if (!jobId || jobId === this.selectedJobId) {
            return;
        }
        this.selectedJobId = jobId;
        this.selectedCompareMatchIds = [];
        this.isComparisonMode = false;
        this.loadJobCandidates(jobId);
    }

    loadJobCandidates(jobId) {
        this.isLoading = true;
        getMatchesForJob({ jobId: jobId })
            .then((matches) => {
                this.rawRankedCandidates = matches || [];
                if (this.rawRankedCandidates.length > 0) {
                    this.selectedMatchId = this.rawRankedCandidates[0].matchId;
                    this.loadSelectedMatchDetail(this.selectedMatchId);
                } else {
                    this.selectedMatchId = null;
                    this.matchDetail = null;
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error loading candidates for job:', error);
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    handleSelectCandidate(event) {
        event.stopPropagation();
        const matchId = event.currentTarget.dataset.matchId;
        if (matchId && matchId !== this.selectedMatchId) {
            this.selectedMatchId = matchId;
            this.loadSelectedMatchDetail(matchId);
        }
    }

    handleSelectCandidateRow(event) {
        const matchId = event.currentTarget.dataset.matchId;
        if (matchId && matchId !== this.selectedMatchId) {
            this.selectedMatchId = matchId;
            this.loadSelectedMatchDetail(matchId);
        }
    }

    handleCandidateCheckbox(event) {
        event.stopPropagation();
        const matchId = event.target.dataset.matchId;
        const isChecked = event.target.checked;
        if (isChecked) {
            if (this.selectedCompareMatchIds.length >= 5) {
                event.target.checked = false;
                this.showToast('Maximum 5 Candidates', 'Comparison is limited to a maximum of 5 candidates. Please deselect a candidate first.', 'warning');
                return;
            }
            if (!this.selectedCompareMatchIds.includes(matchId)) {
                this.selectedCompareMatchIds = [...this.selectedCompareMatchIds, matchId];
            }
        } else {
            this.selectedCompareMatchIds = this.selectedCompareMatchIds.filter(id => id !== matchId);
        }
    }

    handleStopPropagation(event) {
        event.stopPropagation();
    }

    handleOpenComparison() {
        if (this.selectedCompareMatchIds.length < 2) {
            this.showToast('Select Candidates', 'Please select at least 2 candidates using the checkboxes to compare.', 'info');
            return;
        }
        if (this.selectedCompareMatchIds.length > 5) {
            this.showToast('Maximum 5 Candidates', 'Comparison is limited to a maximum of 5 candidates. Please select between 2 and 5 candidates.', 'warning');
            return;
        }
        this.isComparisonMode = true;
    }

    handleCloseComparison() {
        this.isComparisonMode = false;
    }

    loadSelectedMatchDetail(matchId) {
        this.isLoading = true;
        getMatchDetail({ matchId: matchId })
            .then((detail) => {
                this.matchDetail = detail;
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error loading match detail:', error);
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    handleToggleExplainScore() {
        this.isExplainOpen = !this.isExplainOpen;
    }

    handleToggleViewMode() {
        if (this.viewMode === 'split') {
            this.viewMode = 'detail-only';
        } else if (this.viewMode === 'detail-only') {
            this.viewMode = 'list-only';
        } else {
            this.viewMode = 'split';
        }
    }

    handleRecalculateJob() {
        if (!this.selectedJobId) {
            this.showToast('No Job Selected', 'Please select a job requisition to re-evaluate.', 'warning');
            return;
        }
        this.isLoading = true;
        recalculateJobMatches({ jobId: this.selectedJobId })
            .then((matches) => {
                this.rawRankedCandidates = matches || [];
                if (this.rawRankedCandidates.length > 0) {
                    const activeMatchId = this.selectedMatchId || this.rawRankedCandidates[0].matchId;
                    this.selectedMatchId = activeMatchId;
                    this.loadSelectedMatchDetail(activeMatchId);
                } else {
                    this.isLoading = false;
                }
                this.showToast('Calculation Complete', 'Match intelligence successfully refreshed for all candidates.', 'success');
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error recalculating job matches:', error);
                this.showToast('Recalculation Failed', this.getErrorMessage(error), 'error');
            });
    }

    // =========================================================================
    // NAVIGATION
    // =========================================================================

    handleNavigateCandidate(event) {
        event.stopPropagation();
        const candId = event.currentTarget.dataset.id;
        if (candId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: candId,
                    actionName: 'view'
                }
            });
        }
    }

    handleNavigateJob(event) {
        event.stopPropagation();
        const jobId = event.currentTarget.dataset.id;
        if (jobId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: jobId,
                    actionName: 'view'
                }
            });
        }
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    getErrorMessage(error) {
        if (!error) return 'An unexpected error occurred.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
