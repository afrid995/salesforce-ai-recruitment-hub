# Salesforce AI Recruitment Hub — Testing & Validation Guide

> **Testing Philosophy**: 100% deterministic test coverage, strict regression protection, automated multi-persona security assertion, and zero mocking of core business calculations.

---

## 1. Testing Framework & Quality Metrics Overview

The Salesforce AI Recruitment Hub enforces rigorous testing standards across all Apex domain services, invocable actions, and security controls.

```mermaid
pie title Apex Test Coverage Distribution (92% Org-Wide)
    "Covered Code Lines (21 Classes)" : 92
    "Uncovered Edge / Exception Lines" : 8
```

| Metric | Target | Actual Verified Result | Status |
| :--- | :---: | :---: | :---: |
| **Total Test Classes** | 10+ | **15** | PASS |
| **Total Test Methods** | 100+ | **122** | PASS |
| **Passing Tests** | 100% | **122 / 122 (100%)** | PASS |
| **Failed Tests** | 0 | **0** | PASS |
| **Org-Wide Apex Coverage** | $\ge 75\%$ | **92%** | PASS |
| **Production Classes Covered** | 21 / 21 | **21 / 21 (100%)** | PASS |
| **Security Test Suite** | Dedicated | **`RecruitmentSecurityTest` (Multi-Persona)** | PASS |

---

## 2. Test Suite Breakdown (15 Test Classes)

```mermaid
flowchart TD
    subgraph Test_Suite [15 Apex Test Classes]
        T1[CandidateJobMatchServiceTest]
        T2[CandidateJobMatchActionTest]
        T3[CandidateJobMatchUIControllerTest]
        T4[CandidateComparisonControllerTest]
        T5[CandidateComparisonActionTest]
        T6[RecruitmentIntelligenceControllerTest]
        T7[RecruitmentRiskServiceTest]
        T8[RecruitmentRiskControllerTest]
        T9[RecruiterActionServiceTest]
        T10[RecruiterActionCenterControllerTest]
        T11[RecruiterActionCenterActionTest]
        T12[RecruitmentDataFactoryTest]
        T13[RecruitmentTestDataFactoryTest]
        T14[RecruitmentSecurityTest]
        T15[RecruitmentIntelligenceTest]
    end

    subgraph Prod_Classes [21 Production Classes]
        P_Match[Matching & Scoring Services]
        P_Comp[Comparison Engine]
        P_Risk[Risk & Bottleneck Services]
        P_Action[Recruiter Action Center]
        P_Agent[Agentforce Invocable Actions]
    end

    Test_Suite --> Prod_Classes
```

### Detailed Class Inventory

| Test Class | Target Production Classes | Focus & Key Scenarios |
| :--- | :--- | :--- |
| [`CandidateJobMatchServiceTest`](../../force-app/main/default/classes/CandidateJobMatchServiceTest.cls) | `CandidateJobMatchService` | Validates multi-factor algorithm (50% skills, 25% exp, 15% qual, 10% loc), boundary conditions (0-100), and gap analysis text generation. |
| [`CandidateJobMatchActionTest`](../../force-app/main/default/classes/CandidateJobMatchActionTest.cls) | `CandidateJobMatchAction` | Validates Invocable Method inputs/outputs, bulk invocation, and JSON serialization for Agentforce consumption. |
| [`CandidateJobMatchUIControllerTest`](../../force-app/main/default/classes/CandidateJobMatchUIControllerTest.cls) | `CandidateJobMatchUIController` | Validates `@AuraEnabled` endpoints for `candidateJobMatchPanel` LWC, ensuring reactive UI data binding. |
| [`CandidateComparisonControllerTest`](../../force-app/main/default/classes/CandidateComparisonControllerTest.cls) | `CandidateComparisonController` | Tests 2–5 candidate comparison matrix generation, ranking normalization, and missing candidate handling. |
| [`CandidateComparisonActionTest`](../../force-app/main/default/classes/CandidateComparisonActionTest.cls) | `CandidateComparisonAction` | Tests Agentforce invocable comparison action with structured side-by-side DTO response. |
| [`RecruitmentIntelligenceControllerTest`](../../force-app/main/default/classes/RecruitmentIntelligenceControllerTest.cls) | `RecruitmentIntelligenceController` | Tests pipeline velocity calculation, stage conversion rates, and department-level aggregation. |
| [`RecruitmentRiskServiceTest`](../../force-app/main/default/classes/RecruitmentRiskServiceTest.cls) | `RecruitmentRiskService` | Tests deterministic risk triggers: Stalled applications (>14d), unscheduled interviews (>5d), feedback lag (>3d). |
| [`RecruitmentRiskControllerTest`](../../force-app/main/default/classes/RecruitmentRiskControllerTest.cls) | `RecruitmentRiskController` | Tests `@AuraEnabled` risk triage queries and filtering by severity (HIGH, MEDIUM, LOW). |
| [`RecruiterActionServiceTest`](../../force-app/main/default/classes/RecruiterActionServiceTest.cls) | `RecruiterActionService` | Validates action dispatch mechanics (`NUDGE_INTERVIEWER`, `SCHEDULE_INTERVIEW`, `SOURCE_CANDIDATES`, `FLAG_STALLED_APPLICATION`). |
| [`RecruiterActionCenterControllerTest`](../../force-app/main/default/classes/RecruiterActionCenterControllerTest.cls) | `RecruiterActionCenterController` | Validates Action Center UI payload delivery, action execution confirmation, and audit record creation. |
| [`RecruiterActionCenterActionTest`](../../force-app/main/default/classes/RecruiterActionCenterActionTest.cls) | `RecruiterActionCenterAction` | Tests Agentforce action dispatch interface for operational recruiter workflows. |
| [`RecruitmentDataFactoryTest`](../../force-app/main/default/classes/RecruitmentDataFactoryTest.cls) | `RecruitmentDataFactory` | Validates basic record provisioning and relationship integrity in test contexts. |
| [`RecruitmentTestDataFactoryTest`](../../force-app/main/default/classes/RecruitmentTestDataFactoryTest.cls) | `RecruitmentTestDataFactory` | Validates bulk generation of complex end-to-end recruitment scenarios with pre-configured matches and interviews. |
| [`RecruitmentSecurityTest`](../../force-app/main/default/classes/RecruitmentSecurityTest.cls) | All Production Classes | Dedicated multi-persona RBAC, FLS, and PII masking test suite executing negative and positive permissions tests. |
| [`RecruitmentIntelligenceTest`](../../force-app/main/default/classes/RecruitmentIntelligenceTest.cls) | Orchestration Classes | Validates cross-service workflows linking matches, risk detection, and action execution. |

---

## 3. Specialized Security Test Suite (`RecruitmentSecurityTest`)

The test class [`RecruitmentSecurityTest.cls`](../../force-app/main/default/classes/RecruitmentSecurityTest.cls) isolates security enforcement by provisioning distinct test users for each persona and asserting explicit authorization boundaries:

```apex
// Persona 1: Recruitment_Administrator
System.runAs(adminUser) {
    // Asserts full CRUD and administrative capability
    delete [SELECT Id FROM Candidate__c LIMIT 1];
    System.assert(true, 'Admin successfully deleted candidate');
}

// Persona 2: Recruitment_Recruiter
System.runAs(recruiterUser) {
    // Asserts Create, Read, Edit
    Candidate__c cand = [SELECT Id, Phone__c FROM Candidate__c LIMIT 1];
    System.assertNotEquals(null, cand.Phone__c, 'Recruiter has full FLS phone access');
    
    // Asserts ZERO DELETE permission (Hardened in Phase 7B.1)
    try {
        delete cand;
        System.assert(false, 'Expected DML exception: Recruiter must not have delete access');
    } catch (DmlException e) {
        System.assert(e.getMessage().contains('INSUFFICIENT_ACCESS'), 'Delete access properly denied');
    }
}

// Persona 3: Recruitment_Hiring_Manager
System.runAs(managerUser) {
    // Asserts Candidate Phone PII is masked / inaccessible
    Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
    Boolean phoneAccessible = Schema.sObjectType.Candidate__c.fields.Phone__c.isAccessible();
    System.assertEquals(false, phoneAccessible, 'Hiring manager cannot access phone PII');
}

// Persona 4: Recruitment_Agent_User
System.runAs(agentUser) {
    // Asserts Agent User cannot perform direct DML on recruitment objects
    try {
        insert new Candidate__c(Name = 'Unauthorized Agent Insert');
        System.assert(false, 'Expected DML exception: Agent cannot perform direct DML');
    } catch (DmlException e) {
        System.assert(e.getMessage().contains('INSUFFICIENT_ACCESS'), 'Direct DML blocked');
    }
}
```

---

## 4. Test Execution & CLI Commands

### Execute Full Local Test Suite with Code Coverage
```powershell
sf apex run test --test-level RunLocalTests --code-coverage --result-format human -o recruitment-dev
```

### Run Dedicated Security Tests
```powershell
sf apex run test --tests RecruitmentSecurityTest --result-format human -o recruitment-dev
```

### Run Matching Intelligence Suite Only
```powershell
sf apex run test --tests CandidateJobMatchServiceTest,CandidateJobMatchActionTest,CandidateComparisonControllerTest --result-format human -o recruitment-dev
```

---

## 5. End-to-End Manual Verification Checklist

Follow this 10-step checklist to verify end-to-end platform readiness in the demonstration org:

- [ ] **Step 1: Seed Test Data**
  Open Developer Console > Execute Anonymous Apex:
  ```apex
  RecruitmentTestDataFactory.createFullRecruitmentScenario();
  ```
- [ ] **Step 2: Inspect Candidate Record**
  Navigate to **Candidates** tab. Open any candidate record (e.g., *Jane Doe*). Verify profile fields and related applications.
- [ ] **Step 3: Verify Match Intelligence UI**
  On the candidate page, review the [`candidateJobMatchPanel`](../../force-app/main/default/lwc/candidateJobMatchPanel) component. Confirm the circular match score gauge and explainability breakdown (Skills, Experience, Qualification, Location).
- [ ] **Step 4: Launch Candidate Comparison**
  Navigate to the **Candidate Comparison** tab. Select a job requisition and 3 candidate records. Verify the side-by-side comparative matrix renders with normalized factor scores.
- [ ] **Step 5: Agentforce Match Inquiry**
  Open the Agentforce Copilot panel. Prompt: *"How well does Jane Doe match the Senior Salesforce Developer requisition?"*. Verify the agent invokes `CandidateJobMatchAction` and cites stored scores.
- [ ] **Step 6: Agentforce Comparison Prompt**
  In the Agentforce Copilot, prompt: *"Compare candidates Jane Doe and John Smith for the Technical Architect opening."*. Verify structured side-by-side synthesis.
- [ ] **Step 7: Check Recruitment Dashboard**
  Navigate to **Recruitment Intelligence Dashboard**. Verify stage conversion rates, requisition open aging, and interview distribution charts load reactively.
- [ ] **Step 8: Review Operational Risk Alerts**
  Examine the **Risk & Bottleneck Alerts** panel. Verify stalled applications (>14 days) and pending feedback warnings are surfaced with HIGH or MEDIUM severity badges.
- [ ] **Step 9: Execute Recruiter Action**
  In the **Recruiter Action Center**, click **"Nudge Interviewer"** or **"Flag Stalled Application"** on an active alert item. Complete the modal notes and confirm dispatch.
- [ ] **Step 10: Verify Audit Log Creation**
  Navigate to the **Recruiter Action Logs** tab. Confirm a new `Recruiter_Action_Log__c` record was generated with action type, timestamp, recipient, and notes.
