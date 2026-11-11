# Metadata Inventory
## Salesforce AI-Powered Recruitment Intelligence & Candidate Decision-Support Platform

**Project Root**: `force-app/main/default`  
**Manifest**: `manifest/package.xml`  
**API Version**: `67.0` (Source) / `68.0` (Org)  
**Total Verified Metadata Files**: 204 items across 14 directories  

---

## 1. Verified Metadata Inventory Table

| Metadata Type | Directory | Count | Status | Deployment Scope | Key Dependencies & Considerations |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **ApexClass** | `classes/` | 36 | Present | Core Package | 21 production classes + 15 test classes. Requires custom objects and fields. All classes declare `with sharing`. |
| **CustomObject** | `objects/` | 8 | Present | Core Package | 6 Custom Objects + 2 Custom Metadata Types. Must be deployed first. |
| **CustomField** | `objects/*/fields/` | 91 | Present | Core Package | 91 custom fields across objects (lookups, formulas, rollups, picklists, text, numbers). |
| **CustomMetadata (Records)** | `customMetadata/` | 11 | Present | Core Package | 1 record for `Match_Weight_Configuration` + 10 records for `Recruitment_Alert_Threshold`. |
| **LightningComponentBundle** | `lwc/` | 7 | Present | Core Package | 7 LWC UI bundles (21 files total: js, html, js-meta.xml). Depends on Apex controllers. |
| **Flow** | `flows/` | 8 | Present | Core Package | 4 record-triggered flows + 4 agent autolaunched flows. Must be activated post-deployment. |
| **PermissionSet** | `permissionsets/` | 4 | Present | Core Package | `Recruitment_Admin`, `Recruitment_Recruiter`, `Recruitment_Hiring_Manager`, `Recruitment_Agent_User`. |
| **CustomTab** | `tabs/` | 11 | Present | Core Package | 6 standard object tabs + 5 custom Lightning component tabs. |
| **CustomApplication** | `applications/` | 1 | Present | Core Package | `AI_Recruitment_Hub` Lightning App. Configures navigation bar and tab visibility. |
| **Layout** | `layouts/` | 4 | Present | Core Package | Page layouts for Candidate, Job Requisition, Application, Interview. Required before FlexiPages. |
| **FlexiPage** | `flexipages/` | 2 | Present | Core Package | `AI_Recruitment_Hub_Home` + `Candidate_Record_Page`. |
| **Report** | `reports/` | 6 | Present | Core Package | 5 recruitment analytics reports + 1 flow prebuilt report in `unfiled$public`. |
| **Dashboard** | `dashboards/` | 1 | Present | Core Package | `Recruitment_Dashboard` (plus `Recruitment_Dashboards-meta.xml` folder definition). |
| **AiAuthoringBundle** | `aiAuthoringBundles/` | 1 | Present | Core Package | `AI_Recruitment_Assistant` Agentforce agent bundle (`.agent` and `.bundle-meta.xml`). |
| **Settings** | `settings/` | 1 | Present | **EXCLUDED** | `Bot.settings-meta.xml`. Excluded from package manifest due to legal terms acceptance dependency. |

---

## 2. Detailed Metadata Component Breakdown

### 2.1 Apex Classes (36 Total)

#### Production Classes (21)
1. `CandidateComparisonAction.cls`: Invocable action for multi-candidate comparison.
2. `CandidateComparisonController.cls`: `@AuraEnabled` controller for candidate comparison LWC.
3. `CandidateJobMatchAction.cls`: Invocable action for single/batch match evaluation.
4. `CandidateJobMatchService.cls`: Authoritative scoring engine across skills, experience, education, location.
5. `CandidateJobMatchUIController.cls`: `@AuraEnabled` controller for match intelligence LWC.
6. `RecruitmentAgentChatController.cls`: `@AuraEnabled` bridge to Agentforce Invocable API.
7. `RecruitmentAlertAction.cls`: Invocable action for operational risk alerts.
8. `RecruitmentAlertController.cls`: `@AuraEnabled` controller for Recruiter Action Center LWC.
9. `RecruitmentAlertService.cls`: Risk detection, alert generation, and rescheduling engine.
10. `RecruitmentGetInterviewsAction.cls`: Invocable action for retrieving scheduled interviews.
11. `RecruitmentHomeController.cls`: `@AuraEnabled` controller for recruitment summary KPI cards.
12. `RecruitmentIntelligenceController.cls`: `@AuraEnabled` controller for organization-wide pipeline analytics.
13. `RecruitmentMatchAction.cls`: Invocable action for job application evaluation.
14. `RecruitmentMatchingService.cls`: Legacy/application-level matching calculation service.
15. `RecruitmentPipelineSummaryAction.cls`: Invocable action for stage-by-stage pipeline summary.
16. `RecruitmentRiskAction.cls`: Invocable action for job requisition risk analysis.
17. `RecruitmentRiskController.cls`: `@AuraEnabled` controller for risk intelligence LWC.
18. `RecruitmentRiskService.cls`: Deterministic risk and bottleneck evaluation service.
19. `RecruitmentSearchApplicationsAction.cls`: Invocable action for job application queries.
20. `RecruitmentSearchCandidatesAction.cls`: Invocable action for candidate search with PII masking.
21. `RecruitmentSearchJobsAction.cls`: Invocable action for open job requisition search.

#### Test Classes (15)
1. `CandidateComparisonControllerTest.cls`
2. `CandidateJobMatchActionTest.cls`
3. `CandidateJobMatchServiceTest.cls`
4. `CandidateJobMatchUIControllerTest.cls`
5. `RecruitmentAgentChatControllerTest.cls`
6. `RecruitmentAlertActionTest.cls`
7. `RecruitmentAlertServiceTest.cls`
8. `RecruitmentGetInterviewsActionTest` (in `RecruitmentInvocableActionsTest.cls`)
9. `RecruitmentHomeControllerTest.cls`
10. `RecruitmentIntelligenceControllerTest.cls`
11. `RecruitmentInvocableActionsTest.cls`
12. `RecruitmentMatchActionTest.cls`
13. `RecruitmentMatchingServiceTest.cls`
14. `RecruitmentRiskActionTest.cls`
15. `RecruitmentRiskServiceTest.cls`
16. `RecruitmentSecurityTest.cls` (Specialized security and RBAC validation suite)

---

### 2.2 Custom Objects and Custom Metadata Types (8)

1. **`Job_Requisition__c`**: Headcount, job codes, departments, required skills, required experience, minimum qualifications. (15 custom fields)
2. **`Candidate__c`**: Candidate profiles, experience, education, skills, location, masked phone PII. (11 custom fields)
3. **`Job_Application__c`**: Candidate applications linked to requisitions, status stages, screening scores. (14 custom fields)
4. **`Interview__c`**: Scheduled interviews, rounds, interviewer assignment, feedback, score, recommendation. (10 custom fields)
5. **`Candidate_Job_Match__c`**: Persistent match intelligence records, factor scores, gap percentages, explanations. (15 custom fields)
6. **`Recruitment_Alert__c`**: Operational risk attention items, evidence, severity, recruiter acknowledgment trail. (17 custom fields)
7. **`Match_Weight_Configuration__mdt`**: System scoring weights: Skill (50%), Experience (25%), Qualification (15%), Location (10%). (4 custom fields)
8. **`Recruitment_Alert_Threshold__mdt`**: Operational risk thresholds: overdue hours, coverage deficits, skill gap frequencies. (5 custom fields)

---

### 2.3 Custom Metadata Records (11)

1. `Match_Weight_Configuration.Default_Weight`: Configures 50/25/15/10 factor weights.
2. `Recruitment_Alert_Threshold.Good_Match_Score`: Threshold for good candidate matches (75.0%).
3. `Recruitment_Alert_Threshold.Interview_Decision_Backlog`: Max days an interview can stay completed without decision (3 days).
4. `Recruitment_Alert_Threshold.Low_Match_Concentration`: Alert when 0 good matches exist for active job.
5. `Recruitment_Alert_Threshold.Low_Match_Score`: Threshold for low match score warning (50.0%).
6. `Recruitment_Alert_Threshold.Overdue_Interview_Hours`: Hours past scheduled time before interview is flagged overdue (2 hours).
7. `Recruitment_Alert_Threshold.Pool_Average_Score`: Minimum average pool threshold (60.0%).
8. `Recruitment_Alert_Threshold.Screening_Backlog`: Max days an application can remain in screening (5 days).
9. `Recruitment_Alert_Threshold.Systemic_Skill_Gap_Evals`: Minimum evaluations to flag systemic skill deficit (3).
10. `Recruitment_Alert_Threshold.Systemic_Skill_Gap_Jobs`: Minimum jobs with missing skill to flag systemic deficit (2).
11. `Recruitment_Alert_Threshold.Under_Review_Backlog`: Max days an application can remain under review (7 days).

---

### 2.4 Lightning Web Components (7)

1. **`candidateJobMatchPanel`**: Visualizes match score radial gauge, factor breakdown tiles, matched vs missing skills, and recruiter guidance.
2. **`candidateComparisonPanel`**: Side-by-side comparison for 2 to 5 candidates with cross-candidate skill matrix and tie-handling.
3. **`recruiterActionCenter`**: Operational triage console for alerts, filter tabs, acknowledgment modals, and interview rescheduling.
4. **`recruitmentAiAssistantPanel`**: Embedded Lightning chat interface interacting with Agentforce via invocable actions.
5. **`recruitmentAttentionPanel`**: Highlights active risk signals and jobs needing immediate recruiter attention.
6. **`recruitmentHomeDashboard`**: High-level KPI summary tiles, quick report links, and upcoming interview schedule widget.
7. **`recruitmentIntelligenceDashboard`**: Interactive organization-wide analytics dashboard with pipeline funnel and bottleneck insights.

---

### 2.5 Flows (8)

1. **`New_Job_Application`**: `RecordBeforeSave` flow setting default application numbers and initial statuses.
2. **`Application_Shortlisted`**: `RecordAfterSave` flow cascading status update to `Candidate__c` (`Candidate_Status__c = 'Interviewing'`).
3. **`Candidate_Selected`**: `RecordAfterSave` flow cascading status update to `Candidate__c` (`Candidate_Status__c = 'Selected'`).
4. **`Interview_Completed`**: `RecordAfterSave` flow updating related application status to review.
5. **`Recruitment_Create_Application`**: `AutoLaunchedFlow` invoked by Agentforce to create job applications.
6. **`Recruitment_Create_Candidate`**: `AutoLaunchedFlow` invoked by Agentforce to register new candidates.
7. **`Recruitment_Create_Job`**: `AutoLaunchedFlow` invoked by Agentforce to draft new job requisitions.
8. **`Recruitment_Update_Application`**: `AutoLaunchedFlow` invoked by Agentforce to update application stages.

---

### 2.6 Permission Sets (4)

1. **`Recruitment_Admin`**: Full administrator privileges across all objects, fields, tabs, and classes.
2. **`Recruitment_Recruiter`**: Full daily recruiting CRUD (no delete privileges) on Candidates, Jobs, Applications, and Interviews.
3. **`Recruitment_Hiring_Manager`**: Read-only job and match visibility; update access restricted to interview feedback; phone PII masked.
4. **`Recruitment_Agent_User`**: Least-privilege profile for Agentforce bot identity; zero delete privileges; phone PII masked.

---

## 3. Included vs. Excluded Metadata

| Component | Manifest Status | Exclusion Reason / Handling |
| :--- | :---: | :--- |
| **`Bot.settings-meta.xml`** | **EXCLUDED** | Deploying `BotSettings` requires manual pre-acceptance of Einstein Bots Legal Terms in the destination org Setup. Excluded from `package.xml` to ensure clean automated deployments. |
| **`package.xml`** | **EXCLUDED** | Listed in `.forceignore` so that the deployment manifest is not treated as Salesforce source code. |
| **`Candidate_Record_Page`** | **INCLUDED** | Included in `package.xml`. If deployed in an environment lacking layout assignment, layout must be deployed first. |
| **`Recruitment_Dashboard`** | **INCLUDED** | Included in `package.xml`. Running user specifies `skafrid246.bd97a9cd1a82@agentforce.com`; destination orgs remap running user post-install. |
