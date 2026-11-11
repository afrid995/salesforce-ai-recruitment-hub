public with sharing class CandidateComparisonController {

    public class ComparisonResultDTO {
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public String jobDepartment { get; set; }
        @AuraEnabled public String jobLocation { get; set; }
        @AuraEnabled public Decimal jobExperienceRequired { get; set; }
        @AuraEnabled public String jobMinimumQualification { get; set; }
        @AuraEnabled public String jobRequiredSkills { get; set; }
        
        @AuraEnabled public CandidateJobMatchUIController.WeightConfigDTO weights { get; set; }
        @AuraEnabled public List<CandidateComparisonItemDTO> candidates { get; set; }
        
        @AuraEnabled public String highestScoreCandidateName { get; set; }
        @AuraEnabled public Decimal highestScore { get; set; }
        @AuraEnabled public Boolean isHighestScoreTied { get; set; }
        @AuraEnabled public String highestScoreText { get; set; }
        
        @AuraEnabled public SkillMatrixDTO skillMatrix { get; set; }
        @AuraEnabled public String responsibleAiNotice { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class CandidateComparisonItemDTO {
        @AuraEnabled public Id matchId { get; set; }
        @AuraEnabled public String matchName { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public String candidateEmail { get; set; }
        @AuraEnabled public String candidatePhone { get; set; }
        @AuraEnabled public String candidateLocation { get; set; }
        @AuraEnabled public Decimal candidateExperience { get; set; }
        @AuraEnabled public String candidateQualification { get; set; }
        @AuraEnabled public String candidateSkills { get; set; }
        
        @AuraEnabled public Decimal overallScore { get; set; }
        @AuraEnabled public String overallScoreFormatted { get; set; }
        @AuraEnabled public Boolean isHighestScore { get; set; }
        @AuraEnabled public String recommendation { get; set; }
        @AuraEnabled public String evaluationStatus { get; set; }
        @AuraEnabled public DateTime calculatedOn { get; set; }
        @AuraEnabled public String calculatedOnFormatted { get; set; }
        
        @AuraEnabled public Decimal skillScore { get; set; }
        @AuraEnabled public Decimal skillWeight { get; set; }
        @AuraEnabled public Decimal skillContribution { get; set; }
        @AuraEnabled public Decimal skillGapPercent { get; set; }
        
        @AuraEnabled public Decimal experienceScore { get; set; }
        @AuraEnabled public Decimal experienceWeight { get; set; }
        @AuraEnabled public Decimal experienceContribution { get; set; }
        
        @AuraEnabled public Decimal qualificationScore { get; set; }
        @AuraEnabled public Decimal qualificationWeight { get; set; }
        @AuraEnabled public Decimal qualificationContribution { get; set; }
        
        @AuraEnabled public Decimal locationScore { get; set; }
        @AuraEnabled public Decimal locationWeight { get; set; }
        @AuraEnabled public Decimal locationContribution { get; set; }
        
        @AuraEnabled public List<String> matchedSkillsList { get; set; }
        @AuraEnabled public List<String> missingSkillsList { get; set; }
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public List<String> recruiterAttentionPoints { get; set; }
        @AuraEnabled public String formulaExplanation { get; set; }
    }

    public class SkillMatrixDTO {
        @AuraEnabled public List<String> candidateNames { get; set; }
        @AuraEnabled public List<SkillMatrixRowDTO> rows { get; set; }
    }

    public class SkillMatrixRowDTO {
        @AuraEnabled public String skill { get; set; }
        @AuraEnabled public Boolean isRequired { get; set; }
        @AuraEnabled public List<SkillCellDTO> cells { get; set; }
    }

    public class SkillCellDTO {
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public Boolean hasSkill { get; set; }
        @AuraEnabled public String symbol { get; set; }
        @AuraEnabled public String cellClass { get; set; }
    }

    /**
     * Retrieves side-by-side comparison data for 2 to 5 selected Candidate_Job_Match__c records.
     * Enforces job scoping, candidate limits, and ethical decision-support guardrails.
     */
    @AuraEnabled(cacheable=true)
    public static ComparisonResultDTO getComparisonData(Id jobId, List<Id> matchIds) {
        // 1. Parameter Validation
        if (jobId == null) {
            throw new AuraHandledException('Job Requisition ID is required for candidate comparison.');
        }
        if (matchIds == null || matchIds.size() < 2) {
            throw new AuraHandledException('Please select at least 2 candidates to compare.');
        }
        if (matchIds.size() > 5) {
            throw new AuraHandledException('Comparison is limited to a maximum of 5 candidates. Please select between 2 and 5 candidates.');
        }

        // 2. Query Job Requisition
        List<Job_Requisition__c> jobs = [
            SELECT Id, Name, Job_Title__c, Job_Code__c, Department__c, Location__c,
                   Experience_Required__c, Minimum_Qualification__c, Required_Skills__c
            FROM Job_Requisition__c
            WHERE Id = :jobId
            LIMIT 1
        ];
        if (jobs.isEmpty()) {
            throw new AuraHandledException('Job Requisition with ID ' + jobId + ' was not found.');
        }
        Job_Requisition__c job = jobs[0];

        // 3. Query Candidate_Job_Match__c Records (with FLS check on Phone__c)
        Boolean canReadPhone = Schema.sObjectType.Candidate__c.fields.Phone__c.isAccessible();
        String phoneSelect = canReadPhone ? 'Candidate__r.Phone__c, ' : '';
        String matchQuery = 'SELECT Id, Name, Match_Key__c, Job_Requisition__c, ' +
                            'Candidate__c, Candidate__r.Name, Candidate__r.Candidate_Name__c, ' +
                            'Candidate__r.Email__c, ' + phoneSelect + 'Candidate__r.Location__c, ' +
                            'Candidate__r.Years_of_Experience__c, Candidate__r.Highest_Qualification__c, ' +
                            'Candidate__r.Skills__c, ' +
                            'Skill_Match_Percent__c, Skill_Gap_Percent__c, ' +
                            'Experience_Match_Percent__c, Qualification_Match_Percent__c, Location_Match_Percent__c, ' +
                            'Overall_Match_Score__c, Matched_Skills__c, Missing_Skills__c, ' +
                            'Explanation__c, Recommendation__c, Evaluation_Status__c, Calculated_On__c ' +
                            'FROM Candidate_Job_Match__c WHERE Id IN :matchIds';
        List<Candidate_Job_Match__c> matches = Database.query(matchQuery);

        if (matches.isEmpty()) {
            throw new AuraHandledException('None of the requested candidate match records were found.');
        }

        // 4. Job Scope Validation (Reject any match from another job)
        for (Candidate_Job_Match__c m : matches) {
            if (m.Job_Requisition__c != jobId) {
                String cName = String.isNotBlank(m.Candidate__r.Candidate_Name__c) ? m.Candidate__r.Candidate_Name__c : m.Candidate__r.Name;
                throw new AuraHandledException('Validation Error: All selected candidates must belong to the selected job requisition (' + job.Job_Title__c + '). Candidate ' + cName + ' is associated with a different job.');
            }
        }

        // 5. Construct Comparison DTO
        ComparisonResultDTO result = new ComparisonResultDTO();
        result.jobId = job.Id;
        result.jobTitle = job.Job_Title__c;
        result.jobCode = job.Job_Code__c;
        result.jobDepartment = job.Department__c;
        result.jobLocation = job.Location__c;
        result.jobExperienceRequired = job.Experience_Required__c;
        result.jobMinimumQualification = job.Minimum_Qualification__c;
        result.jobRequiredSkills = job.Required_Skills__c;

        CandidateJobMatchUIController.WeightConfigDTO w = CandidateJobMatchUIController.getWeightConfig();
        result.weights = w;
        result.responsibleAiNotice = 'The comparison is based only on explicit job-relevant criteria such as competencies, experience, education, and location. It does not predict hiring probability and does not use protected characteristics. Final recruitment decisions must be made by human recruiters.';
        result.status = 'Success';

        // 6. Build Candidate Comparison Items & Determine Highest Match Score
        Decimal maxScore = -1.0;
        List<CandidateComparisonItemDTO> items = new List<CandidateComparisonItemDTO>();

        for (Candidate_Job_Match__c m : matches) {
            CandidateComparisonItemDTO item = buildItemDTO(m, w);
            if (item.overallScore != null && item.overallScore > maxScore) {
                maxScore = item.overallScore;
            }
            items.add(item);
        }

        // Identify candidate(s) with Highest Match Score (handles ties gracefully)
        List<String> topCandidateNames = new List<String>();
        for (CandidateComparisonItemDTO item : items) {
            if (item.overallScore != null && item.overallScore == maxScore && maxScore >= 0) {
                item.isHighestScore = true;
                topCandidateNames.add(item.candidateName);
            } else {
                item.isHighestScore = false;
            }
        }

        result.highestScore = maxScore >= 0 ? maxScore : 0.00;
        if (topCandidateNames.size() == 1) {
            result.highestScoreCandidateName = topCandidateNames[0];
            result.isHighestScoreTied = false;
            result.highestScoreText = 'Highest Match Score: ' + topCandidateNames[0] + ' — ' + String.valueOf(maxScore.setScale(2)) + '%';
        } else if (topCandidateNames.size() > 1) {
            result.highestScoreCandidateName = String.join(topCandidateNames, ', ');
            result.isHighestScoreTied = true;
            result.highestScoreText = 'Highest Match Score (Tied): ' + String.join(topCandidateNames, ', ') + ' — ' + String.valueOf(maxScore.setScale(2)) + '%';
        } else {
            result.highestScoreText = 'No Match Scores Available';
            result.isHighestScoreTied = false;
        }

        result.candidates = items;

        // 7. Generate Cross-Candidate Skill Comparison Matrix
        result.skillMatrix = buildSkillMatrix(job.Required_Skills__c, items);

        return result;
    }

    /**
     * Compares candidates by their Candidate__c IDs for a given Job_Requisition__c.
     * Gracefully handles missing match records.
     */
    @AuraEnabled(cacheable=true)
    public static ComparisonResultDTO getComparisonByCandidateIds(Id jobId, List<Id> candidateIds) {
        if (jobId == null) {
            throw new AuraHandledException('Job Requisition ID is required for comparison.');
        }
        if (candidateIds == null || candidateIds.size() < 2) {
            throw new AuraHandledException('Please select at least 2 candidates to compare.');
        }
        if (candidateIds.size() > 5) {
            throw new AuraHandledException('Comparison is limited to a maximum of 5 candidates. Please select between 2 and 5 candidates.');
        }

        List<Candidate_Job_Match__c> matches = [
            SELECT Id, Candidate__c
            FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :jobId
              AND Candidate__c IN :candidateIds
        ];

        List<Id> matchIds = new List<Id>();
        Set<Id> foundCandIds = new Set<Id>();
        for (Candidate_Job_Match__c m : matches) {
            matchIds.add(m.Id);
            foundCandIds.add(m.Candidate__c);
        }

        // If any candidate has no match record, handle missing match record
        if (matchIds.size() < candidateIds.size()) {
            List<Candidate__c> missingCands = [
                SELECT Id, Name, Candidate_Name__c
                FROM Candidate__c
                WHERE Id IN :candidateIds AND Id NOT IN :foundCandIds
            ];
            List<String> missingNames = new List<String>();
            for (Candidate__c c : missingCands) {
                missingNames.add(String.isNotBlank(c.Candidate_Name__c) ? c.Candidate_Name__c : c.Name);
            }
            throw new AuraHandledException('Match evaluation not available for: ' + String.join(missingNames, ', ') + '. Please return to Match Intelligence and evaluate candidate matches before comparing.');
        }

        return getComparisonData(jobId, matchIds);
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    private static CandidateComparisonItemDTO buildItemDTO(Candidate_Job_Match__c m, CandidateJobMatchUIController.WeightConfigDTO w) {
        CandidateComparisonItemDTO item = new CandidateComparisonItemDTO();
        item.matchId = m.Id;
        item.matchName = m.Name;
        item.candidateId = m.Candidate__c;
        item.candidateName = String.isNotBlank(m.Candidate__r.Candidate_Name__c) ? m.Candidate__r.Candidate_Name__c : m.Candidate__r.Name;
        item.candidateEmail = m.Candidate__r.Email__c;
        item.candidatePhone = Schema.sObjectType.Candidate__c.fields.Phone__c.isAccessible() 
            ? m.Candidate__r.Phone__c 
            : '[Protected - Contact Recruiter]';
        item.candidateLocation = m.Candidate__r.Location__c;
        item.candidateExperience = m.Candidate__r.Years_of_Experience__c != null ? m.Candidate__r.Years_of_Experience__c : 0.0;
        item.candidateQualification = m.Candidate__r.Highest_Qualification__c;
        item.candidateSkills = m.Candidate__r.Skills__c;

        item.overallScore = m.Overall_Match_Score__c != null ? m.Overall_Match_Score__c : 0.00;
        item.overallScoreFormatted = item.overallScore.setScale(2) + '%';
        item.recommendation = m.Recommendation__c != null ? m.Recommendation__c : 'Not Evaluated';
        item.evaluationStatus = m.Evaluation_Status__c != null ? m.Evaluation_Status__c : 'Pending';
        item.calculatedOn = m.Calculated_On__c;
        item.calculatedOnFormatted = m.Calculated_On__c != null ? m.Calculated_On__c.format('MMM d, yyyy, h:mm a') : 'N/A';

        item.skillScore = m.Skill_Match_Percent__c != null ? m.Skill_Match_Percent__c : 0.00;
        item.skillWeight = w.skillWeight;
        item.skillContribution = ((item.skillScore * w.skillWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);
        item.skillGapPercent = m.Skill_Gap_Percent__c != null ? m.Skill_Gap_Percent__c : (100.00 - item.skillScore);

        item.experienceScore = m.Experience_Match_Percent__c != null ? m.Experience_Match_Percent__c : 0.00;
        item.experienceWeight = w.experienceWeight;
        item.experienceContribution = ((item.experienceScore * w.experienceWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        item.qualificationScore = m.Qualification_Match_Percent__c != null ? m.Qualification_Match_Percent__c : 0.00;
        item.qualificationWeight = w.qualificationWeight;
        item.qualificationContribution = ((item.qualificationScore * w.qualificationWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        item.locationScore = m.Location_Match_Percent__c != null ? m.Location_Match_Percent__c : 0.00;
        item.locationWeight = w.locationWeight;
        item.locationContribution = ((item.locationScore * w.locationWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        item.matchedSkillsList = CandidateJobMatchUIController.parseSkillList(m.Matched_Skills__c);
        item.missingSkillsList = CandidateJobMatchUIController.parseSkillList(m.Missing_Skills__c);
        item.explanation = m.Explanation__c;

        // Derives factual recruiter review points
        CandidateJobMatchUIController.MatchDetailDTO tempDto = new CandidateJobMatchUIController.MatchDetailDTO();
        tempDto.missingSkillsList = item.missingSkillsList;
        tempDto.candidateExperience = item.candidateExperience;
        tempDto.candidateLocation = item.candidateLocation;
        tempDto.candidateQualification = item.candidateQualification;
        tempDto.locationScore = item.locationScore;
        tempDto.qualificationScore = item.qualificationScore;
        item.recruiterAttentionPoints = CandidateJobMatchUIController.deriveRecruiterAttentionPoints(tempDto);

        // Explanation Formula
        item.formulaExplanation = 'Skill (' + item.skillScore + '% × ' + item.skillWeight + '% = ' + item.skillContribution + '%) + ' +
                                  'Exp (' + item.experienceScore + '% × ' + item.experienceWeight + '% = ' + item.experienceContribution + '%) + ' +
                                  'Qual (' + item.qualificationScore + '% × ' + item.qualificationWeight + '% = ' + item.qualificationContribution + '%) + ' +
                                  'Loc (' + item.locationScore + '% × ' + item.locationWeight + '% = ' + item.locationContribution + '%) = ' +
                                  item.overallScore + '%';

        return item;
    }

    /**
     * Builds a cross-candidate skill comparison matrix.
     * Evaluates all required skills and unique candidate skills across each candidate.
     */
    private static SkillMatrixDTO buildSkillMatrix(String requiredSkillsStr, List<CandidateComparisonItemDTO> candidates) {
        SkillMatrixDTO matrix = new SkillMatrixDTO();
        matrix.candidateNames = new List<String>();
        for (CandidateComparisonItemDTO c : candidates) {
            matrix.candidateNames.add(c.candidateName);
        }

        // 1. Collect required skills maintaining role order
        List<String> requiredTokens = CandidateJobMatchService.parseTokens(requiredSkillsStr);
        Set<String> uniqueSkillNames = new Set<String>();
        List<String> orderedSkills = new List<String>();

        for (String req : requiredTokens) {
            String trimmed = req.trim();
            if (String.isNotBlank(trimmed) && !uniqueSkillNames.contains(trimmed.toLowerCase())) {
                uniqueSkillNames.add(trimmed.toLowerCase());
                orderedSkills.add(trimmed);
            }
        }

        // 2. Build rows for each skill
        List<SkillMatrixRowDTO> rows = new List<SkillMatrixRowDTO>();
        for (String skillName : orderedSkills) {
            SkillMatrixRowDTO row = new SkillMatrixRowDTO();
            row.skill = skillName;
            row.isRequired = true;
            row.cells = new List<SkillCellDTO>();

            String reqLower = skillName.toLowerCase();

            for (CandidateComparisonItemDTO cand : candidates) {
                SkillCellDTO cell = new SkillCellDTO();
                cell.candidateId = cand.candidateId;
                cell.candidateName = cand.candidateName;

                Boolean hasSkill = checkCandidateSkillPresence(cand, reqLower);
                cell.hasSkill = hasSkill;
                cell.symbol = hasSkill ? '✓' : '—';
                cell.cellClass = hasSkill ? 'cell-matched' : 'cell-missing';

                row.cells.add(cell);
            }
            rows.add(row);
        }

        matrix.rows = rows;
        return matrix;
    }

    /**
     * Checks if a candidate possesses a skill using candidate's matched skills,
     * candidate profile skills, and CandidateJobMatchService synonym normalization.
     */
    private static Boolean checkCandidateSkillPresence(CandidateComparisonItemDTO cand, String targetSkillLower) {
        // Direct match against pre-parsed matched skills
        if (cand.matchedSkillsList != null) {
            for (String mSkill : cand.matchedSkillsList) {
                if (mSkill.equalsIgnoreCase(targetSkillLower) || CandidateJobMatchService.areSkillsEquivalent(targetSkillLower, mSkill.toLowerCase())) {
                    return true;
                }
            }
        }

        // Substring / token match against raw candidate skills
        if (String.isNotBlank(cand.candidateSkills)) {
            String candLower = cand.candidateSkills.toLowerCase();
            if (candLower.contains(targetSkillLower)) {
                return true;
            }
            for (String t : CandidateJobMatchService.parseTokens(cand.candidateSkills)) {
                if (CandidateJobMatchService.areSkillsEquivalent(targetSkillLower, t.toLowerCase())) {
                    return true;
                }
            }
        }

        return false;
    }
}
