public with sharing class RecruitmentMatchAction {

    public class Request {
        @InvocableVariable(label='Job Title or Code' description='Job title or job code to match candidates against')
        public String jobTitleOrCode;

        @InvocableVariable(label='Candidate Name' description='Candidate name to match against open jobs')
        public String candidateName;

        @InvocableVariable(label='Job Requisition Id' description='Salesforce record Id of the Job Requisition')
        public Id jobRequisitionId;

        @InvocableVariable(label='Candidate Id' description='Salesforce record Id of the Candidate')
        public Id candidateId;

        @InvocableVariable(label='Top N Results' description='Maximum number of top matches to return (default 5)')
        public Integer topN;

        @InvocableVariable(label='Persist Scores' description='Set to true to update Match_Score__c and rationale on Job_Application__c records')
        public Boolean persistScores;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Markdown formatted decision-support matching analysis and ranking')
        public String result;

        @InvocableVariable(label='Total Matches Found' description='Number of candidate or job matches evaluated')
        public Integer totalMatchesFound;

        @InvocableVariable(label='Top Match Score' description='Highest match score percentage')
        public Decimal topMatchScore;
    }

    @InvocableMethod(label='Match Candidates and Jobs' description='Evaluates multi-factor candidate-to-job compatibility for recruiter decision support')
    public static List<Response> match(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.totalMatchesFound = 0;
            res.topMatchScore = 0.00;

            Integer limitN = (req != null && req.topN != null && req.topN > 0) ? req.topN : 5;
            Boolean persist = (req != null && req.persistScores == true);

            Id targetJobId = req != null ? req.jobRequisitionId : null;
            Id targetCandId = req != null ? req.candidateId : null;

            // Resolve Job ID from name/code if not directly provided
            if (targetJobId == null && req != null && String.isNotBlank(req.jobTitleOrCode)) {
                String searchJob = req.jobTitleOrCode.trim();
                List<Job_Requisition__c> foundJobs = [
                    SELECT Id, Job_Title__c, Job_Code__c
                    FROM Job_Requisition__c
                    WHERE Job_Code__c = :searchJob
                       OR Job_Title__c LIKE :('%' + searchJob + '%')
                    LIMIT 1
                ];
                if (!foundJobs.isEmpty()) {
                    targetJobId = foundJobs[0].Id;
                }
            }

            // Resolve Candidate ID from name if not directly provided
            if (targetCandId == null && req != null && String.isNotBlank(req.candidateName)) {
                String searchCand = req.candidateName.trim();
                List<Candidate__c> foundCands = [
                    SELECT Id, Candidate_Name__c
                    FROM Candidate__c
                    WHERE Candidate_Name__c LIKE :('%' + searchCand + '%')
                    LIMIT 1
                ];
                if (!foundCands.isEmpty()) {
                    targetCandId = foundCands[0].Id;
                }
            }

            // Case 1: Specific Job AND Specific Candidate
            if (targetJobId != null && targetCandId != null) {
                evaluateSinglePair(targetCandId, targetJobId, persist, res);
            }
            // Case 2: Specific Job -> Rank Candidates
            else if (targetJobId != null) {
                rankCandidatesForJob(targetJobId, limitN, persist, res);
            }
            // Case 3: Specific Candidate -> Rank Jobs
            else if (targetCandId != null) {
                rankJobsForCandidate(targetCandId, limitN, persist, res);
            }
            // Case 4: Neither specified -> Evaluate all applications
            else {
                evaluateAllApplications(limitN, persist, res, req);
            }

            responses.add(res);
        }

        return responses;
    }

    private static void evaluateSinglePair(Id candId, Id jobId, Boolean persist, Response res) {
        Candidate__c cand = [
            SELECT Id, Candidate_Name__c, Email__c, Phone__c, Location__c,
                   Highest_Qualification__c, University__c, Years_of_Experience__c,
                   Skills__c, Candidate_Status__c
            FROM Candidate__c
            WHERE Id = :candId
            LIMIT 1
        ];

        Job_Requisition__c job = [
            SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c,
                   Experience_Required__c, Minimum_Qualification__c, Required_Skills__c
            FROM Job_Requisition__c
            WHERE Id = :jobId
            LIMIT 1
        ];

        RecruitmentMatchingService.MatchResult mr = RecruitmentMatchingService.calculateMatch(cand, job);
        res.totalMatchesFound = 1;
        res.topMatchScore = mr.overallScore;

        if (persist) {
            List<Job_Application__c> apps = [
                SELECT Id FROM Job_Application__c
                WHERE Candidate__c = :candId AND Job_Requisition__c = :jobId
                LIMIT 1
            ];
            if (!apps.isEmpty()) {
                RecruitmentMatchingService.evaluateApplications(new List<Id>{apps[0].Id}, true);
            }
        }

        List<String> lines = new List<String>();
        lines.add('### Candidate Match Analysis: ' + cand.Candidate_Name__c + ' for ' + job.Job_Title__c + ' (' + job.Job_Code__c + ')');
        lines.add('');
        lines.add('**Overall Fit**: ' + getTierBadge(mr.fitTier) + ' **' + mr.overallScore + '%** (' + mr.fitTier + ')');
        lines.add('- **Skills Score**: ' + mr.skillScore + ' / 50 pts (' + mr.skillPercentage + '% match)');
        lines.add('  - *Matched Skills*: ' + (mr.matchedSkills.isEmpty() ? 'None' : String.join(mr.matchedSkills, ', ')));
        if (!mr.missingSkills.isEmpty()) {
            lines.add('  - *Missing Skills*: ' + String.join(mr.missingSkills, ', '));
        }
        lines.add('- **Experience**: ' + mr.experienceScore + ' / 25 pts (' + (cand.Years_of_Experience__c != null ? String.valueOf(cand.Years_of_Experience__c) : '0') + ' yrs vs ' + (job.Experience_Required__c != null ? String.valueOf(job.Experience_Required__c) : '0') + ' yrs required)');
        lines.add('- **Education**: ' + mr.qualificationScore + ' / 15 pts (' + (cand.Highest_Qualification__c != null ? cand.Highest_Qualification__c : 'N/A') + ')');
        lines.add('- **Location**: ' + mr.locationScore + ' / 10 pts (' + (cand.Location__c != null ? cand.Location__c : 'N/A') + ' vs ' + job.Location__c + ')');
        lines.add('');
        lines.add(getDecisionSupportFooter());

        res.result = String.join(lines, '\n');
    }

    private static void rankCandidatesForJob(Id jobId, Integer limitN, Boolean persist, Response res) {
        List<RecruitmentMatchingService.MatchResult> matches = RecruitmentMatchingService.matchCandidatesToJob(jobId, limitN);
        res.totalMatchesFound = matches.size();
        if (matches.isEmpty()) {
            res.result = 'No candidates found to evaluate for this job.';
            return;
        }

        res.topMatchScore = matches[0].overallScore;
        Job_Requisition__c job = [SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c FROM Job_Requisition__c WHERE Id = :jobId LIMIT 1];

        if (persist) {
            RecruitmentMatchingService.evaluateApplications(null, true);
        }

        List<String> lines = new List<String>();
        lines.add('### Top Candidate Recommendations for **' + job.Job_Title__c + '** (' + job.Job_Code__c + ')');
        lines.add('*Evaluated across Skills (50%), Experience (25%), Education (15%), and Location (10%).*');
        lines.add('');

        Integer rank = 1;
        for (RecruitmentMatchingService.MatchResult mr : matches) {
            lines.add('**' + rank + '. ' + mr.candidateName + '** — ' + getTierBadge(mr.fitTier) + ' **' + mr.overallScore + '%** (' + mr.fitTier + ')');
            lines.add('   - **Skills (' + mr.skillScore + '/50 pts, ' + mr.skillPercentage + '%)**: ' + (mr.matchedSkills.isEmpty() ? 'None' : String.join(mr.matchedSkills, ', ')));
            if (!mr.missingSkills.isEmpty()) {
                lines.add('   - **Missing Skills**: ' + String.join(mr.missingSkills, ', '));
            }
            lines.add('   - **Exp**: ' + (mr.candidateExperience != null ? String.valueOf(mr.candidateExperience) : '0') + ' yrs | **Edu**: ' + (mr.candidateQualification != null ? mr.candidateQualification : 'N/A') + ' | **Loc**: ' + (mr.candidateLocation != null ? mr.candidateLocation : 'N/A'));
            lines.add('');
            rank++;
        }

        lines.add(getDecisionSupportFooter());
        res.result = String.join(lines, '\n');
    }

    private static void rankJobsForCandidate(Id candId, Integer limitN, Boolean persist, Response res) {
        List<RecruitmentMatchingService.MatchResult> matches = RecruitmentMatchingService.matchJobsToCandidate(candId, limitN);
        res.totalMatchesFound = matches.size();
        if (matches.isEmpty()) {
            res.result = 'No open job requisitions found to evaluate for this candidate.';
            return;
        }

        res.topMatchScore = matches[0].overallScore;
        Candidate__c cand = [SELECT Id, Candidate_Name__c, Skills__c FROM Candidate__c WHERE Id = :candId LIMIT 1];

        if (persist) {
            RecruitmentMatchingService.evaluateApplications(null, true);
        }

        List<String> lines = new List<String>();
        lines.add('### Top Job Recommendations for **' + cand.Candidate_Name__c + '**');
        lines.add('*Evaluated across Skills (50%), Experience (25%), Education (15%), and Location (10%).*');
        lines.add('');

        Integer rank = 1;
        for (RecruitmentMatchingService.MatchResult mr : matches) {
            lines.add('**' + rank + '. ' + mr.jobTitle + '** (' + mr.jobCode + ') — ' + getTierBadge(mr.fitTier) + ' **' + mr.overallScore + '%** (' + mr.fitTier + ')');
            lines.add('   - **Skills (' + mr.skillScore + '/50 pts, ' + mr.skillPercentage + '%)**: ' + (mr.matchedSkills.isEmpty() ? 'None' : String.join(mr.matchedSkills, ', ')));
            if (!mr.missingSkills.isEmpty()) {
                lines.add('   - **Skills Gap**: ' + String.join(mr.missingSkills, ', '));
            }
            lines.add('   - **Dept**: ' + mr.jobDepartment + ' | **Req Exp**: ' + (mr.jobExperienceRequired != null ? String.valueOf(mr.jobExperienceRequired) : '0') + ' yrs | **Loc**: ' + mr.jobLocation);
            lines.add('');
            rank++;
        }

        lines.add(getDecisionSupportFooter());
        res.result = String.join(lines, '\n');
    }

    private static void evaluateAllApplications(Integer limitN, Boolean persist, Response res, Request req) {
        if (req != null && String.isNotBlank(req.jobTitleOrCode)) {
            res.result = 'No open job requisition found matching "' + req.jobTitleOrCode + '" in Salesforce.';
            return;
        }
        if (req != null && String.isNotBlank(req.candidateName)) {
            res.result = 'No candidate found matching "' + req.candidateName + '" in Salesforce.';
            return;
        }

        List<RecruitmentMatchingService.MatchResult> matches = RecruitmentMatchingService.evaluateApplications(null, persist);
        res.totalMatchesFound = matches.size();
        if (matches.isEmpty()) {
            res.result = 'No job applications found to evaluate.';
            return;
        }

        res.topMatchScore = matches[0].overallScore;

        List<String> lines = new List<String>();
        lines.add('### Current Job Applications Match Ranking (Top ' + Math.min(limitN, matches.size()) + ')');
        lines.add('*Scored via multi-factor matching intelligence (Skills 50%, Experience 25%, Education 15%, Location 10%).*');
        lines.add('');

        Integer rank = 1;
        for (RecruitmentMatchingService.MatchResult mr : matches) {
            if (rank > limitN) break;
            lines.add('**' + rank + '. ' + mr.candidateName + '** applying for **' + mr.jobTitle + '** (' + mr.jobCode + ')');
            lines.add('   - **Score**: ' + getTierBadge(mr.fitTier) + ' **' + mr.overallScore + '%** (' + mr.fitTier + ')');
            lines.add('   - **Skills**: ' + mr.skillPercentage + '% | **Exp**: ' + (mr.candidateExperience != null ? String.valueOf(mr.candidateExperience) : '0') + ' yrs | **Edu**: ' + (mr.candidateQualification != null ? mr.candidateQualification : 'N/A'));
            if (!mr.missingSkills.isEmpty()) {
                lines.add('   - **Missing Skills**: ' + String.join(mr.missingSkills, ', '));
            }
            lines.add('');
            rank++;
        }

        lines.add(getDecisionSupportFooter());
        res.result = String.join(lines, '\n');
    }

    private static String getTierBadge(String tier) {
        if (tier == 'Strong Match') return '🟢';
        if (tier == 'Good Match') return '🟡';
        if (tier == 'Moderate Match') return '🟠';
        return '🔴';
    }

    private static String getDecisionSupportFooter() {
        return '> **Decision Support Only**: Match scores are algorithmic recommendations to aid recruiters. In accordance with safety policies, all shortlisting, interview selections, and hiring decisions must be determined by human recruiters.';
    }
}
