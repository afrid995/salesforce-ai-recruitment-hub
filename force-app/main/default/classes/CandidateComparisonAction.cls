public with sharing class CandidateComparisonAction {

    public class CompareRequest {
        @InvocableVariable(label='Job Requisition ID' description='ID of the Job Requisition' required=false)
        public Id jobId;

        @InvocableVariable(label='Job Title or Code' description='Title or code of the Job Requisition (e.g. AI/ML Engineer, REQ-AIML-001)' required=false)
        public String jobTitle;

        @InvocableVariable(label='Candidate Match IDs' description='List of 2 to 5 Candidate_Job_Match__c IDs' required=false)
        public List<Id> matchIds;

        @InvocableVariable(label='Candidate IDs' description='List of 2 to 5 Candidate__c IDs' required=false)
        public List<Id> candidateIds;

        @InvocableVariable(label='Candidate Names' description='Comma-separated names of 2 to 5 candidates to compare (e.g. Alex Morgan, Fiona Gallagher, George Brooks)' required=false)
        public String candidateNames;

        @InvocableVariable(label='Top N Candidates' description='Number of top matching candidates to compare for the job (between 2 and 5, default 3)' required=false)
        public Integer topN;
    }

    public class CompareResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Comparison Summary')
        public String comparisonSummary;

        @InvocableVariable(label='Highest Score Candidate')
        public String highestScoreCandidate;

        @InvocableVariable(label='Highest Score')
        public Decimal highestScore;

        @InvocableVariable(label='Skill Differences')
        public String skillDifferences;

        @InvocableVariable(label='Experience Comparison')
        public String experienceComparison;

        @InvocableVariable(label='Score Factor Breakdown')
        public String factorBreakdown;

        @InvocableVariable(label='Responsible AI Notice')
        public String responsibleAiNotice;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(label='Compare Candidates and Rank Match Scores' description='Compares candidates side-by-side, ranks top candidates by match score, identifies the highest match score candidate, explains score differences between candidates, and analyzes skill gaps.')
    public static List<CompareResult> compare(List<CompareRequest> requests) {
        List<CompareResult> results = new List<CompareResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (CompareRequest req : requests) {
            CompareResult res = new CompareResult();
            try {
                // 1. Resolve Candidate IDs / Match IDs first so we can infer the job if jobTitle is omitted
                List<Id> resolvedCandIds = new List<Id>();
                if (req.candidateIds != null && !req.candidateIds.isEmpty()) {
                    resolvedCandIds.addAll(req.candidateIds);
                } else if (String.isNotBlank(req.candidateNames)) {
                    String normalized = req.candidateNames.replaceAll('(?i)\\s+and\\s+', ', ');
                    List<String> rawTokens = normalized.split('[,;]');
                    Set<Id> resolvedCandIdSet = new Set<Id>();

                    for (String token : rawTokens) {
                        String trimmed = token.trim();
                        if (String.isNotBlank(trimmed)) {
                            List<Candidate__c> cList = [
                                SELECT Id, Candidate_Name__c
                                FROM Candidate__c
                                WHERE Candidate_Name__c = :trimmed
                                   OR Candidate_Name__c LIKE :('%' + trimmed + '%')
                                LIMIT 1
                            ];
                            if (!cList.isEmpty()) {
                                resolvedCandIdSet.add(cList[0].Id);
                            }
                        }
                    }
                    resolvedCandIds.addAll(resolvedCandIdSet);
                }

                // 2. Resolve Job ID
                Id resolvedJobId = req.jobId;
                if (resolvedJobId == null && String.isNotBlank(req.jobTitle)) {
                    String cleanTitle = req.jobTitle.trim();
                    List<Job_Requisition__c> matchedJobs = [
                        SELECT Id FROM Job_Requisition__c
                        WHERE Job_Code__c = :cleanTitle
                           OR Job_Title__c = :cleanTitle
                           OR Job_Title__c LIKE :('%' + cleanTitle + '%')
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!matchedJobs.isEmpty()) {
                        resolvedJobId = matchedJobs[0].Id;
                    }
                }

                // If job is still null and jobTitle was blank, infer from common evaluated matches or open jobs
                if (resolvedJobId == null && String.isBlank(req.jobTitle) && !resolvedCandIds.isEmpty()) {
                    List<AggregateResult> commonJobs = [
                        SELECT Job_Requisition__c, COUNT(Id) cnt
                        FROM Candidate_Job_Match__c
                        WHERE Candidate__c IN :resolvedCandIds
                        GROUP BY Job_Requisition__c
                        ORDER BY COUNT(Id) DESC, MAX(Overall_Match_Score__c) DESC
                        LIMIT 1
                    ];
                    if (!commonJobs.isEmpty()) {
                        resolvedJobId = (Id) commonJobs[0].get('Job_Requisition__c');
                    }
                }
                if (resolvedJobId == null && String.isBlank(req.jobTitle) && resolvedCandIds.isEmpty() && req.jobId == null) {
                    List<Job_Requisition__c> openJobs = [
                        SELECT Id FROM Job_Requisition__c WHERE Status__c = 'Open' ORDER BY CreatedDate ASC LIMIT 1
                    ];
                    if (!openJobs.isEmpty()) {
                        resolvedJobId = openJobs[0].Id;
                    }
                }

                if (resolvedJobId == null) {
                    res.isSuccess = false;
                    res.errorMessage = 'Please provide a valid Job Requisition ID or Job Title.';
                    results.add(res);
                    continue;
                }

                // 3. Build Comparison Result
                CandidateComparisonController.ComparisonResultDTO compData;

                if (req.matchIds != null && !req.matchIds.isEmpty()) {
                    compData = CandidateComparisonController.getComparisonData(resolvedJobId, req.matchIds);
                } else if (resolvedCandIds.size() >= 2) {
                    compData = CandidateComparisonController.getComparisonByCandidateIds(resolvedJobId, resolvedCandIds);
                } else if (resolvedCandIds.size() == 1) {
                    // Supplement single candidate with top other candidate for this job
                    List<Candidate_Job_Match__c> topMatches = [
                        SELECT Id, Candidate__c
                        FROM Candidate_Job_Match__c
                        WHERE Job_Requisition__c = :resolvedJobId
                          AND Candidate__c != :resolvedCandIds[0]
                        ORDER BY Overall_Match_Score__c DESC
                        LIMIT 1
                    ];
                    if (!topMatches.isEmpty()) {
                        resolvedCandIds.add(topMatches[0].Candidate__c);
                        compData = CandidateComparisonController.getComparisonByCandidateIds(resolvedJobId, resolvedCandIds);
                    }
                }

                // If compData not yet obtained (e.g. topN requested or no candidates specified)
                if (compData == null) {
                    Integer limitN = (req.topN != null && req.topN >= 2) ? Math.min(req.topN, 5) : 3;
                    List<Candidate_Job_Match__c> topMatches = [
                        SELECT Id, Overall_Match_Score__c, Candidate__c
                        FROM Candidate_Job_Match__c
                        WHERE Job_Requisition__c = :resolvedJobId
                        ORDER BY Overall_Match_Score__c DESC
                        LIMIT :limitN
                    ];
                    if (topMatches.size() < 2) {
                        topMatches = CandidateJobMatchService.evaluateCandidatesForJob(resolvedJobId, true);
                    }
                    List<Id> topMatchIds = new List<Id>();
                    for (Integer i = 0; i < Math.min(limitN, topMatches.size()); i++) {
                        topMatchIds.add(topMatches[i].Id);
                    }
                    if (topMatchIds.size() >= 2) {
                        compData = CandidateComparisonController.getComparisonData(resolvedJobId, topMatchIds);
                    }
                }

                if (compData == null || compData.candidates == null || compData.candidates.size() < 2) {
                    res.isSuccess = false;
                    res.errorMessage = 'Please provide 2 to 5 candidates to compare, or ensure evaluated candidate match records exist for this job.';
                    results.add(res);
                    continue;
                }

                res.isSuccess = true;
                res.highestScoreCandidate = compData.highestScoreCandidateName;
                res.highestScore = compData.highestScore;
                res.responsibleAiNotice = compData.responsibleAiNotice;

                // Build human-readable comparison summary
                List<String> summaryLines = new List<String>();
                summaryLines.add('=== 📊 Candidate Comparison: ' + compData.jobTitle + ' (' + compData.jobCode + ') ===');
                summaryLines.add('**' + compData.highestScoreText + '**');
                summaryLines.add('');
                summaryLines.add('Score Breakdown:');
                for (CandidateComparisonController.CandidateComparisonItemDTO c : compData.candidates) {
                    summaryLines.add('- **' + c.candidateName + '**: **' + c.overallScoreFormatted + '** (' + c.recommendation + ') | ' +
                        'Skills: ' + c.skillScore + '% (wt ' + c.skillWeight + '%) | Exp: ' + c.experienceScore + '% (wt ' + c.experienceWeight + '%) | Qual: ' + c.qualificationScore + '% (wt ' + c.qualificationWeight + '%) | Loc: ' + c.locationScore + '% (wt ' + c.locationWeight + '%)');
                    if (String.isNotBlank(c.formulaExplanation)) {
                        summaryLines.add('  *Formula: ' + c.formulaExplanation + '*');
                    }
                }
                summaryLines.add('');

                // Key Score Drivers / Why highest candidate scored higher
                List<String> scoreDiffReasons = new List<String>();
                CandidateComparisonController.CandidateComparisonItemDTO topC = compData.candidates[0];
                for (Integer i = 1; i < compData.candidates.size(); i++) {
                    CandidateComparisonController.CandidateComparisonItemDTO otherC = compData.candidates[i];
                    List<String> drivers = new List<String>();
                    if (topC.skillScore > otherC.skillScore) {
                        drivers.add('higher Skill Match (' + topC.skillScore + '% vs ' + otherC.skillScore + '%)');
                    }
                    if (topC.experienceScore > otherC.experienceScore) {
                        drivers.add('greater Experience Compatibility (' + topC.experienceScore + '% [' + topC.candidateExperience + ' yrs] vs ' + otherC.experienceScore + '% [' + otherC.candidateExperience + ' yrs])');
                    }
                    if (topC.qualificationScore > otherC.qualificationScore) {
                        drivers.add('higher Qualification Compatibility (' + topC.qualificationScore + '% vs ' + otherC.qualificationScore + '%)');
                    }
                    if (topC.locationScore > otherC.locationScore) {
                        drivers.add('closer Location Compatibility (' + topC.locationScore + '% vs ' + otherC.locationScore + '%)');
                    }
                    if (!drivers.isEmpty()) {
                        scoreDiffReasons.add('- ' + topC.candidateName + ' (' + topC.overallScoreFormatted + ') scores higher than ' + otherC.candidateName + ' (' + otherC.overallScoreFormatted + ') primarily due to: ' + String.join(drivers, ', ') + '.');
                    }
                }
                if (!scoreDiffReasons.isEmpty()) {
                    summaryLines.add('Score Differences & Key Drivers:');
                    summaryLines.addAll(scoreDiffReasons);
                    summaryLines.add('');
                }

                summaryLines.add('Skills Summary:');
                for (CandidateComparisonController.CandidateComparisonItemDTO c : compData.candidates) {
                    String matched = c.matchedSkillsList.isEmpty() ? 'None' : String.join(c.matchedSkillsList, ', ');
                    String missing = c.missingSkillsList.isEmpty() ? 'None' : String.join(c.missingSkillsList, ', ');
                    summaryLines.add('- **' + c.candidateName + '** -> Matched: [' + matched + '] | Missing Gap: [' + missing + ']');
                }
                summaryLines.add('');
                summaryLines.add('> **Responsible AI Notice**: ' + compData.responsibleAiNotice);
                res.comparisonSummary = String.join(summaryLines, '\n');

                // Skill differences
                List<String> skillDiffs = new List<String>();
                if (compData.skillMatrix != null && compData.skillMatrix.rows != null) {
                    for (CandidateComparisonController.SkillMatrixRowDTO row : compData.skillMatrix.rows) {
                        List<String> possessing = new List<String>();
                        List<String> lacking = new List<String>();
                        for (CandidateComparisonController.SkillCellDTO cell : row.cells) {
                            if (cell.hasSkill) {
                                possessing.add(cell.candidateName);
                            } else {
                                lacking.add(cell.candidateName);
                            }
                        }
                        if (!possessing.isEmpty() && !lacking.isEmpty()) {
                            skillDiffs.add('- **' + row.skill + '**: Possessed by (' + String.join(possessing, ', ') + ') but missing from (' + String.join(lacking, ', ') + ')');
                        }
                    }
                }
                res.skillDifferences = skillDiffs.isEmpty() ? 'No differentiating skill gaps identified among compared candidates.' : String.join(skillDiffs, '\n');

                // Experience comparison
                List<String> expLines = new List<String>();
                for (CandidateComparisonController.CandidateComparisonItemDTO c : compData.candidates) {
                    expLines.add(c.candidateName + ': ' + c.candidateExperience + ' yrs experience (Req: ' + compData.jobExperienceRequired + ' yrs)');
                }
                res.experienceComparison = String.join(expLines, ' | ');

                // Factor breakdown
                List<String> factorLines = new List<String>();
                for (CandidateComparisonController.CandidateComparisonItemDTO c : compData.candidates) {
                    factorLines.add(c.candidateName + ' (' + c.overallScoreFormatted + '): ' + c.formulaExplanation);
                }
                res.factorBreakdown = String.join(factorLines, '\n');

            } catch (Exception ex) {
                res.isSuccess = false;
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}
