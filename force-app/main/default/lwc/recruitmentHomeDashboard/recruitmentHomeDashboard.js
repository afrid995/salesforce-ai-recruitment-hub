import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecruitmentKpis from '@salesforce/apex/RecruitmentHomeController.getRecruitmentKpis';
import getUpcomingInterviews from '@salesforce/apex/RecruitmentHomeController.getUpcomingInterviews';
import getReportLinks from '@salesforce/apex/RecruitmentHomeController.getReportLinks';

export default class RecruitmentHomeDashboard extends NavigationMixin(LightningElement) {
    @track kpis = {
        openJobs: 0,
        totalCandidates: 0,
        totalApplications: 0,
        totalInterviews: 0,
        upcomingInterviews: 0,
        selectedCandidates: 0
    };
    @track reportLinks = {};
    @track upcomingInterviewsList = [];
    @track isLoading = true;

    wiredKpisResult;
    wiredInterviewsResult;
    wiredReportsResult;

    samplePrompts = [
        {
            id: '1',
            icon: 'utility:search',
            text: 'Find candidates with Python and Machine Learning skills',
            sub: 'Searches candidate skill profiles across education and experience'
        },
        {
            id: '2',
            icon: 'utility:case',
            text: 'Show open AI/ML jobs',
            sub: 'Lists active requisitions in the Artificial Intelligence department'
        },
        {
            id: '3',
            icon: 'utility:user',
            text: "What is Alex Morgan's application status?",
            sub: 'Retrieves active job applications and current stage'
        },
        {
            id: '4',
            icon: 'utility:event',
            text: 'Show upcoming interviews',
            sub: 'Retrieves scheduled rounds with dates, jobs, and interviewers'
        },
        {
            id: '5',
            icon: 'utility:metrics',
            text: 'Summarize the recruitment pipeline',
            sub: 'Aggregates open headcounts, candidate pool, and applications'
        }
    ];

    @wire(getRecruitmentKpis)
    wiredKpis(result) {
        this.wiredKpisResult = result;
        if (result.data) {
            this.kpis = result.data;
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error fetching KPIs:', result.error);
            this.isLoading = false;
        }
    }

    @wire(getReportLinks)
    wiredReports(result) {
        this.wiredReportsResult = result;
        if (result.data) {
            this.reportLinks = result.data;
        } else if (result.error) {
            console.error('Error fetching report links:', result.error);
        }
    }

    connectedCallback() {
        if (this.wiredKpisResult) {
            refreshApex(this.wiredKpisResult);
        }
        if (this.wiredInterviewsResult) {
            refreshApex(this.wiredInterviewsResult);
        }
    }

    @wire(getUpcomingInterviews)
    wiredInterviews(result) {
        this.wiredInterviewsResult = result;
        if (result.data) {
            const now = new Date();
            this.upcomingInterviewsList = result.data.filter(inv => {
                return inv.interviewDateTime && new Date(inv.interviewDateTime) >= now;
            });
        } else if (result.error) {
            console.error('Error fetching interviews:', result.error);
        }
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredKpisResult),
            refreshApex(this.wiredReportsResult),
            refreshApex(this.wiredInterviewsResult)
        ]).then(() => {
            this.isLoading = false;
            this.showToast('Updated', 'Recruitment metrics refreshed from Salesforce.', 'success');
        }).catch(() => {
            this.isLoading = false;
        });
    }

    // Direct Navigation to AI Assistant Tab
    navigateToAssistant() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'AI_Recruitment_Assistant'
            }
        });
    }

    // Direct Navigation to Dashboard
    navigateToDashboard() {
        if (this.reportLinks && this.reportLinks.dashboardId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.reportLinks.dashboardId,
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Dashboard',
                    actionName: 'home'
                }
            });
        }
    }

    // Direct Navigation to Reports
    navigateToReport(event) {
        const reportKey = event.currentTarget.dataset.report;
        const reportId = this.reportLinks ? this.reportLinks[reportKey] : null;
        if (reportId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: reportId,
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Report',
                    actionName: 'home'
                }
            });
        }
    }

    // Quick Actions
    handleNewJob() {
        this.navigateToNewRecord('Job_Requisition__c');
    }

    handleNewCandidate() {
        this.navigateToNewRecord('Candidate__c');
    }

    handleNewApplication() {
        this.navigateToNewRecord('Job_Application__c');
    }

    handleNewInterview() {
        this.navigateToNewRecord('Interview__c');
    }

    navigateToNewRecord(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'new'
            }
        });
    }

    // Navigation on KPI click
    navigateToJobs() {
        this.navigateToList('Job_Requisition__c');
    }

    navigateToCandidates() {
        this.navigateToList('Candidate__c');
    }

    navigateToApplications() {
        this.navigateToList('Job_Application__c');
    }

    navigateToInterviews() {
        this.navigateToList('Interview__c');
    }

    navigateToList(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'home'
            }
        });
    }

    handleCandidateClick(event) {
        const candidateId = event.currentTarget.dataset.id;
        if (candidateId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: candidateId,
                    actionName: 'view'
                }
            });
        }
    }

    handlePromptClick(event) {
        const promptText = event.currentTarget.dataset.prompt;
        if (navigator.clipboard) {
            navigator.clipboard.writeText(promptText);
            this.showToast('Prompt Copied', `"${promptText}" copied to clipboard. Paste into AI Recruitment Assistant!`, 'info');
        } else {
            this.showToast('Sample Prompt', promptText, 'info');
        }
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
