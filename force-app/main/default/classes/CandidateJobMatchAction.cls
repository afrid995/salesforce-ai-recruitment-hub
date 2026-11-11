public with sharing class CandidateJobMatchAction {

    public class Request {
        @InvocableVariable(label='Job Title or Code' description='Job title or job code to evaluate matches for')
        public String jobTitleOrCode;

        @InvocableVariable(label='Candidate Name' description='Candidate name to evaluate matching open jobs for')
        public String candidateName;

        @InvocableVariable(label='Job Requisition Id' description='Record Id of the Job Requisition')
        public Id jobRequisitionId;

        @InvocableVariable(label='Candidate Id' description='Record Id of the Candidate')
        public Id candidateId;

        @InvocableVariable(label='Top N Results' description='Maximum number of recommendations to return (default: 5)')
        public Integer topN;

        @InvocableVariable(label='Persist Records' description='Whether to save evaluation results into Candidate_Job_Match__c (default: true)')
        public Boolean persistRecords;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted markdown decision-support report for recruiters')
        public String result;

        @InvocableVariable(label='Total Matches Found' description='Number of candidate-job evaluations')
        public Integer totalMatchesFound;

        @InvocableVariable(label='Top Match Score' description='Highest decision-support match score')
        public Decimal topMatchScore;

        @InvocableVariable(label='Top Recommendation' description='Recommendation tier of the highest match')
        public String topRecommendation;
    }

    @InvocableMethod(label='Evaluate Match Scores and Factor Contributions' description='Retrieves candidate match scores, explains what contributes to a candidate score (Skills 50%, Experience 25%, Qualification 15%, Location 10%), factor breakdowns, and recommendation tiers.')
    public static List<Response> evaluate(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.totalMatchesFound = 0;
            res.topMatchScore = 0.00;
            res.topRecommendation = 'None';

            Integer limitN = (req != null && req.topN != null && req.topN > 0) ? req.topN : 5;
            Boolean persist = (req == null || req.persistRecords != false); // default true

            Id targetJobId = req != null ? req.jobRequisitionId : null;
            Id targetCandId = req != null ? req.candidateId : null;

            // Resolve Job Id if needed
            if (targetJobId == null && req != null && String.isNotBlank(req.jobTitleOrCode)) {
                String searchJob = req.jobTitleOrCode.trim();
                List<Job_Requisition__c> jobs = [
                    SELECT Id, Job_Title__c, Job_Code__c
                    FROM Job_Requisition__c
                    WHERE Job_Code__c = :searchJob
                       OR Job_Title__c LIKE :('%' + searchJob + '%')
                    LIMIT 1
                ];
                if (!jobs.isEmpty()) {
                    targetJobId = jobs[0].Id;
                }
            }

            // Resolve Candidate Id if needed
            if (targetCandId == null && req != null && String.isNotBlank(req.candidateName)) {
                String searchCand = req.candidateName.trim();
                List<Candidate__c> cands = [
                    SELECT Id, Candidate_Name__c
                    FROM Candidate__c
                    WHERE Candidate_Name__c LIKE :('%' + searchCand + '%')
                    LIMIT 1
                ];
                if (!cands.isEmpty()) {
                    targetCandId = cands[0].Id;
                }
            }

            // Case 1: Specific Job and Candidate
            if (targetJobId != null && targetCandId != null) {
                Candidate_Job_Match__c matchRec;
                if (persist) {
                    matchRec = CandidateJobMatchService.evaluateAndSaveMatch(targetCandId, targetJobId);
                } else {
                    Candidate__c c = [SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c, Highest_Qualification__c, Location__c FROM Candidate__c WHERE Id = :targetCandId];
                    Job_Requisition__c j = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c, Experience_Required__c, Minimum_Qualification__c, Location__c, Employment_Type__c FROM Job_Requisition__c WHERE Id = :targetJobId];
                    matchRec = CandidateJobMatchService.evaluateMatch(c, j);
                }
                res.totalMatchesFound = 1;
                res.topMatchScore = matchRec.Overall_Match_Score__c;
                res.topRecommendation = matchRec.Recommendation__c;
                res.result = matchRec.Explanation__c;
            }
            // Case 2: Specific Job -> Rank Candidates
            else if (targetJobId != null) {
                List<Candidate_Job_Match__c> matches = CandidateJobMatchService.evaluateCandidatesForJob(targetJobId, persist);
                res.totalMatchesFound = matches.size();
                if (matches.isEmpty()) {
                    res.result = 'No candidates found to evaluate for this job.';
                } else {
                    res.topMatchScore = matches[0].Overall_Match_Score__c;
                    res.topRecommendation = matches[0].Recommendation__c;
                    res.result = formatMultiMatchReport(matches, limitN, true);
                }
            }
            // Case 3: Specific Candidate -> Rank Jobs
            else if (targetCandId != null) {
                List<Candidate_Job_Match__c> matches = CandidateJobMatchService.evaluateJobsForCandidate(targetCandId, persist);
                res.totalMatchesFound = matches.size();
                if (matches.isEmpty()) {
                    res.result = 'No open job requisitions found to evaluate for this candidate.';
                } else {
                    res.topMatchScore = matches[0].Overall_Match_Score__c;
                    res.topRecommendation = matches[0].Recommendation__c;
                    res.result = matches[0].Explanation__c + '\n\n' + formatMultiMatchReport(matches, limitN, false);
                }
            }
            // Case 4: Neither specified -> Evaluate all
            else {
                if (req != null && String.isNotBlank(req.jobTitleOrCode)) {
                    res.result = 'No job requisition found matching "' + req.jobTitleOrCode + '" in Salesforce.';
                } else if (req != null && String.isNotBlank(req.candidateName)) {
                    res.result = 'No candidate found matching "' + req.candidateName + '" in Salesforce.';
                } else {
                    List<Candidate_Job_Match__c> matches = CandidateJobMatchService.evaluateAll(persist);
                    res.totalMatchesFound = matches.size();
                    if (matches.isEmpty()) {
                        res.result = 'No candidates or open jobs found to evaluate.';
                    } else {
                        res.topMatchScore = matches[0].Overall_Match_Score__c;
                        res.topRecommendation = matches[0].Recommendation__c;
                        res.result = formatMultiMatchReport(matches, limitN, true);
                    }
                }
            }

            responses.add(res);
        }

        return responses;
    }

    private static String formatMultiMatchReport(List<Candidate_Job_Match__c> matches, Integer limitN, Boolean showCandidateFirst) {
        // Collect Candidate and Job IDs for query details
        Set<Id> candIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();
        for (Candidate_Job_Match__c m : matches) {
            if (m.Candidate__c != null) candIds.add(m.Candidate__c);
            if (m.Job_Requisition__c != null) jobIds.add(m.Job_Requisition__c);
        }

        Map<Id, Candidate__c> candMap = new Map<Id, Candidate__c>([
            SELECT Id, Candidate_Name__c, Location__c, Years_of_Experience__c, Highest_Qualification__c
            FROM Candidate__c WHERE Id IN :candIds
        ]);
        Map<Id, Job_Requisition__c> jobMap = new Map<Id, Job_Requisition__c>([
            SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c, Experience_Required__c
            FROM Job_Requisition__c WHERE Id IN :jobIds
        ]);

        List<String> lines = new List<String>();
        lines.add('### 📋 Candidate–Job Match Intelligence Report');
        lines.add('*Displaying top ' + Math.min(limitN, matches.size()) + ' evaluated matches based on Decision-Support Scoring.*');
        lines.add('');

        Integer rank = 1;
        for (Candidate_Job_Match__c m : matches) {
            if (rank > limitN) break;

            Candidate__c c = candMap.get(m.Candidate__c);
            Job_Requisition__c j = jobMap.get(m.Job_Requisition__c);

            String candName = c != null ? c.Candidate_Name__c : 'Candidate';
            String jobTitle = j != null ? j.Job_Title__c + ' (' + j.Job_Code__c + ')' : 'Job';
            String badge = getBadge(m.Recommendation__c);

            if (showCandidateFirst) {
                lines.add('**' + rank + '. ' + candName + '** for **' + jobTitle + '** — ' + badge + ' **' + m.Overall_Match_Score__c + '%** (' + m.Recommendation__c + ')');
            } else {
                lines.add('**' + rank + '. ' + jobTitle + '** for **' + candName + '** — ' + badge + ' **' + m.Overall_Match_Score__c + '%** (' + m.Recommendation__c + ')');
            }

            lines.add('   - **Skills**: ' + m.Skill_Match_Percent__c + '% match | Gap: ' + m.Skill_Gap_Percent__c + '%');
            lines.add('   - **Matched Skills**: ' + m.Matched_Skills__c);
            if (String.isNotBlank(m.Missing_Skills__c) && m.Missing_Skills__c != 'None') {
                lines.add('   - **Skill Gap**: ' + m.Missing_Skills__c);
            }
            lines.add('   - **Experience**: ' + m.Experience_Match_Percent__c + '% | **Education**: ' + m.Qualification_Match_Percent__c + '% | **Location**: ' + m.Location_Match_Percent__c + '%');
            lines.add('');
            rank++;
        }

        lines.add('> **Ethical Decision-Support Guardrail**: Candidate-job match scores are objective algorithmic recommendations evaluating job-relevant criteria. They do not predict probability of hiring or incorporate protected characteristics. All final hiring decisions remain with human recruiters.');

        return String.join(lines, '\n');
    }

    private static String getBadge(String tier) {
        if (tier == 'Strong Match') return '🟢';
        if (tier == 'Good Match') return '🟡';
        if (tier == 'Moderate Match') return '🟠';
        return '🔴';
    }
}
