import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getComparisonData from '@salesforce/apex/CandidateComparisonController.getComparisonData';
import getComparisonByCandidateIds from '@salesforce/apex/CandidateComparisonController.getComparisonByCandidateIds';

export default class CandidateComparisonPanel extends NavigationMixin(LightningElement) {
    @api jobId;
    @api matchIds;
    @api candidateIds;

    @track isLoading = true;
    @track errorMessage = '';
    @track comparisonData = null;

    connectedCallback() {
        this.loadComparison();
    }

    @api
    refreshComparison() {
        this.loadComparison();
    }

    loadComparison() {
        this.isLoading = true;
        this.errorMessage = '';

        if (!this.jobId) {
            this.errorMessage = 'Job Requisition ID is required for comparison.';
            this.isLoading = false;
            return;
        }

        if (this.matchIds && this.matchIds.length >= 2) {
            getComparisonData({ jobId: this.jobId, matchIds: this.matchIds })
                .then((data) => {
                    this.comparisonData = data;
                    this.isLoading = false;
                })
                .catch((error) => {
                    this.isLoading = false;
                    this.errorMessage = this.extractErrorMessage(error);
                });
        } else if (this.candidateIds && this.candidateIds.length >= 2) {
            getComparisonByCandidateIds({ jobId: this.jobId, candidateIds: this.candidateIds })
                .then((data) => {
                    this.comparisonData = data;
                    this.isLoading = false;
                })
                .catch((error) => {
                    this.isLoading = false;
                    this.errorMessage = this.extractErrorMessage(error);
                });
        } else {
            this.errorMessage = 'Please select at least 2 candidates to compare.';
            this.isLoading = false;
        }
    }

    // =========================================================================
    // COMPUTED GETTERS
    // =========================================================================

    get hasData() {
        return !!this.comparisonData && this.candidates && this.candidates.length >= 2;
    }

    get candidateCount() {
        return this.candidates ? this.candidates.length : 0;
    }

    get totalColumns() {
        return this.candidateCount + 1;
    }

    get jobTitle() {
        return this.comparisonData ? this.comparisonData.jobTitle : 'Role';
    }

    get jobCode() {
        return this.comparisonData && this.comparisonData.jobCode ? this.comparisonData.jobCode : 'REQ';
    }

    get jobExperienceRequired() {
        return this.comparisonData && this.comparisonData.jobExperienceRequired != null ? this.comparisonData.jobExperienceRequired : 0;
    }

    get weights() {
        return this.comparisonData && this.comparisonData.weights ? this.comparisonData.weights : {
            skillWeight: 50.00,
            experienceWeight: 25.00,
            qualificationWeight: 15.00,
            locationWeight: 10.00
        };
    }

    get highestScoreText() {
        return this.comparisonData ? this.comparisonData.highestScoreText : '';
    }

    get responsibleAiNotice() {
        return this.comparisonData ? this.comparisonData.responsibleAiNotice : 'Decision-support only.';
    }

    get candidates() {
        if (!this.comparisonData || !this.comparisonData.candidates) {
            return [];
        }

        return this.comparisonData.candidates.map((cand) => {
            const hasMatched = cand.matchedSkillsList && cand.matchedSkillsList.length > 0;
            const hasMissing = cand.missingSkillsList && cand.missingSkillsList.length > 0;
            const isHighest = cand.isHighestScore === true;

            return {
                ...cand,
                hasMatchedSkills: hasMatched,
                hasMissingSkills: hasMissing,
                badgeClass: this.getBadgeClass(cand.recommendation),
                columnHeaderClass: isHighest ? 'cand-col-header highest-score-col' : 'cand-col-header',
                skillBarStyle: `width: ${cand.skillScore || 0}%;`,
                expBarStyle: `width: ${cand.experienceScore || 0}%;`,
                qualBarStyle: `width: ${cand.qualificationScore || 0}%;`,
                locBarStyle: `width: ${cand.locationScore || 0}%;`
            };
        });
    }

    get skillMatrixCandidates() {
        return (this.comparisonData && this.comparisonData.skillMatrix) ? this.comparisonData.skillMatrix.candidateNames : [];
    }

    get skillMatrixRows() {
        return (this.comparisonData && this.comparisonData.skillMatrix) ? this.comparisonData.skillMatrix.rows : [];
    }

    getBadgeClass(recommendation) {
        if (!recommendation) return 'slds-badge slds-badge_lightest';
        if (recommendation === 'Strong Match') return 'slds-badge badge-strong';
        if (recommendation === 'Good Match') return 'slds-badge badge-good';
        if (recommendation === 'Moderate Match') return 'slds-badge badge-moderate';
        return 'slds-badge badge-low';
    }

    // =========================================================================
    // EVENT HANDLERS
    // =========================================================================

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNavigateCandidate(event) {
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

    extractErrorMessage(error) {
        if (!error) return 'An unexpected error occurred during candidate comparison.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
