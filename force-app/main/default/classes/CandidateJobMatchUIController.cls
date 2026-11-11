public with sharing class CandidateJobMatchUIController {

    public class WeightConfigDTO {
        @AuraEnabled public Decimal skillWeight { get; set; }
        @AuraEnabled public Decimal experienceWeight { get; set; }
        @AuraEnabled public Decimal qualificationWeight { get; set; }
        @AuraEnabled public Decimal locationWeight { get; set; }
        @AuraEnabled public Decimal totalWeight { get; set; }
    }

    public class MatchSummaryDTO {
        @AuraEnabled public Id matchId { get; set; }
        @AuraEnabled public String matchName { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public String candidateEmail { get; set; }
        @AuraEnabled public String candidateLocation { get; set; }
        @AuraEnabled public Decimal candidateExperience { get; set; }
        @AuraEnabled public String candidateQualification { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public Decimal overallScore { get; set; }
        @AuraEnabled public Decimal skillScore { get; set; }
        @AuraEnabled public Decimal experienceScore { get; set; }
        @AuraEnabled public Decimal qualificationScore { get; set; }
        @AuraEnabled public Decimal locationScore { get; set; }
        @AuraEnabled public String recommendation { get; set; }
        @AuraEnabled public String evaluationStatus { get; set; }
        @AuraEnabled public DateTime calculatedOn { get; set; }
        @AuraEnabled public Integer rank { get; set; }
    }

    public class MatchDetailDTO {
        @AuraEnabled public Id matchId { get; set; }
        @AuraEnabled public String matchName { get; set; }
        @AuraEnabled public String matchKey { get; set; }
        
        // Candidate Information
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public String candidateEmail { get; set; }
        @AuraEnabled public String candidatePhone { get; set; }
        @AuraEnabled public String candidateLocation { get; set; }
        @AuraEnabled public Decimal candidateExperience { get; set; }
        @AuraEnabled public String candidateQualification { get; set; }
        @AuraEnabled public String candidateSkills { get; set; }
        
        // Job Information
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public String jobDepartment { get; set; }
        @AuraEnabled public String jobLocation { get; set; }
        @AuraEnabled public Decimal jobExperienceRequired { get; set; }
        @AuraEnabled public String jobMinimumQualification { get; set; }
        @AuraEnabled public String jobRequiredSkills { get; set; }
        
        // Scores & Classifications
        @AuraEnabled public Decimal overallScore { get; set; }
        @AuraEnabled public String recommendation { get; set; }
        @AuraEnabled public String evaluationStatus { get; set; }
        @AuraEnabled public DateTime calculatedOn { get; set; }
        @AuraEnabled public String calculatedOnFormatted { get; set; }
        
        // Factor Scores
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
        
        @AuraEnabled public Decimal totalWeight { get; set; }
        
        // Skills Breakdown
        @AuraEnabled public String rawMatchedSkills { get; set; }
        @AuraEnabled public String rawMissingSkills { get; set; }
        @AuraEnabled public List<String> matchedSkillsList { get; set; }
        @AuraEnabled public List<String> missingSkillsList { get; set; }
        
        // Explainability & Recruiter Guidance
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public List<String> recruiterAttentionPoints { get; set; }
        @AuraEnabled public String responsibleAiNotice { get; set; }
    }

    public class InitialContextDTO {
        @AuraEnabled public List<Job_Requisition__c> activeJobs { get; set; }
        @AuraEnabled public WeightConfigDTO weights { get; set; }
        @AuraEnabled public Id selectedJobId { get; set; }
        @AuraEnabled public Id selectedMatchId { get; set; }
        @AuraEnabled public MatchDetailDTO matchDetail { get; set; }
        @AuraEnabled public List<MatchSummaryDTO> rankedCandidates { get; set; }
    }

    /**
     * Retrieves configured weights from Custom Metadata Type Match_Weight_Configuration__mdt
     * via CandidateJobMatchService.
     */
    @AuraEnabled(cacheable=true)
    public static WeightConfigDTO getWeightConfig() {
        CandidateJobMatchService.WeightConfig cfg = CandidateJobMatchService.getWeightConfiguration();
        WeightConfigDTO dto = new WeightConfigDTO();
        dto.skillWeight = cfg.skillWeight != null ? cfg.skillWeight : 50.00;
        dto.experienceWeight = cfg.experienceWeight != null ? cfg.experienceWeight : 25.00;
        dto.qualificationWeight = cfg.qualificationWeight != null ? cfg.qualificationWeight : 15.00;
        dto.locationWeight = cfg.locationWeight != null ? cfg.locationWeight : 10.00;
        dto.totalWeight = dto.skillWeight + dto.experienceWeight + dto.qualificationWeight + dto.locationWeight;
        return dto;
    }

    /**
     * Retrieves all active Job Requisitions for the job-level recruiter view selector.
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Requisition__c> getActiveJobs() {
        return [
            SELECT Id, Name, Job_Title__c, Job_Code__c, Department__c, Status__c,
                   Location__c, Experience_Required__c, Minimum_Qualification__c, Required_Skills__c
            FROM Job_Requisition__c
            WHERE Status__c != 'Closed'
            ORDER BY Job_Title__c ASC
        ];
    }

    /**
     * Retrieves complete detail and explainable breakdown for a specific Candidate_Job_Match__c record.
     */
    @AuraEnabled(cacheable=true)
    public static MatchDetailDTO getMatchDetail(Id matchId) {
        if (matchId == null) {
            return null;
        }

        Boolean canReadPhone = Schema.sObjectType.Candidate__c.fields.Phone__c.isAccessible();
        String phoneSelect = canReadPhone ? 'Candidate__r.Phone__c, ' : '';
        String matchQuery = 'SELECT Id, Name, Match_Key__c, ' +
                            'Candidate__c, Candidate__r.Name, Candidate__r.Candidate_Name__c, ' +
                            'Candidate__r.Email__c, ' + phoneSelect + 'Candidate__r.Location__c, ' +
                            'Candidate__r.Years_of_Experience__c, Candidate__r.Highest_Qualification__c, Candidate__r.Skills__c, ' +
                            'Job_Requisition__c, Job_Requisition__r.Name, Job_Requisition__r.Job_Title__c, ' +
                            'Job_Requisition__r.Job_Code__c, Job_Requisition__r.Department__c, Job_Requisition__r.Location__c, ' +
                            'Job_Requisition__r.Experience_Required__c, Job_Requisition__r.Minimum_Qualification__c, ' +
                            'Job_Requisition__r.Required_Skills__c, ' +
                            'Skill_Match_Percent__c, Skill_Gap_Percent__c, ' +
                            'Experience_Match_Percent__c, Qualification_Match_Percent__c, Location_Match_Percent__c, ' +
                            'Overall_Match_Score__c, Matched_Skills__c, Missing_Skills__c, ' +
                            'Explanation__c, Recommendation__c, Evaluation_Status__c, Calculated_On__c ' +
                            'FROM Candidate_Job_Match__c WHERE Id = :matchId LIMIT 1';
        List<Candidate_Job_Match__c> matches = Database.query(matchQuery);

        if (matches.isEmpty()) {
            return null;
        }

        return buildMatchDetailDTO(matches[0], getWeightConfig());
    }

    /**
     * Retrieves ranked candidates for a specific Job Requisition.
     */
    @AuraEnabled(cacheable=true)
    public static List<MatchSummaryDTO> getMatchesForJob(Id jobId) {
        if (jobId == null) {
            return new List<MatchSummaryDTO>();
        }

        List<Candidate_Job_Match__c> matches = [
            SELECT Id, Name, Candidate__c, Candidate__r.Name, Candidate__r.Candidate_Name__c,
                   Candidate__r.Email__c, Candidate__r.Location__c, Candidate__r.Years_of_Experience__c,
                   Candidate__r.Highest_Qualification__c,
                   Job_Requisition__c, Job_Requisition__r.Job_Title__c, Job_Requisition__r.Job_Code__c,
                   Skill_Match_Percent__c, Experience_Match_Percent__c, Qualification_Match_Percent__c,
                   Location_Match_Percent__c, Overall_Match_Score__c, Recommendation__c,
                   Evaluation_Status__c, Calculated_On__c
            FROM Candidate_Job_Match__c
            WHERE Job_Requisition__c = :jobId
            ORDER BY Overall_Match_Score__c DESC, Skill_Match_Percent__c DESC, Experience_Match_Percent__c DESC
        ];

        List<MatchSummaryDTO> dtoList = new List<MatchSummaryDTO>();
        Integer rank = 1;
        for (Candidate_Job_Match__c m : matches) {
            MatchSummaryDTO s = new MatchSummaryDTO();
            s.matchId = m.Id;
            s.matchName = m.Name;
            s.candidateId = m.Candidate__c;
            s.candidateName = String.isNotBlank(m.Candidate__r.Candidate_Name__c) ? m.Candidate__r.Candidate_Name__c : m.Candidate__r.Name;
            s.candidateEmail = m.Candidate__r.Email__c;
            s.candidateLocation = m.Candidate__r.Location__c;
            s.candidateExperience = m.Candidate__r.Years_of_Experience__c;
            s.candidateQualification = m.Candidate__r.Highest_Qualification__c;
            s.jobId = m.Job_Requisition__c;
            s.jobTitle = m.Job_Requisition__r.Job_Title__c;
            s.jobCode = m.Job_Requisition__r.Job_Code__c;
            s.overallScore = m.Overall_Match_Score__c;
            s.skillScore = m.Skill_Match_Percent__c;
            s.experienceScore = m.Experience_Match_Percent__c;
            s.qualificationScore = m.Qualification_Match_Percent__c;
            s.locationScore = m.Location_Match_Percent__c;
            s.recommendation = m.Recommendation__c;
            s.evaluationStatus = m.Evaluation_Status__c;
            s.calculatedOn = m.Calculated_On__c;
            s.rank = rank++;
            dtoList.add(s);
        }
        return dtoList;
    }

    /**
     * Resolves initial context dynamically based on whether recordId is a Match, Job, Candidate, or null.
     */
    @AuraEnabled(cacheable=true)
    public static InitialContextDTO getInitialContext(Id recordId) {
        InitialContextDTO context = new InitialContextDTO();
        context.weights = getWeightConfig();
        context.activeJobs = getActiveJobs();

        if (recordId != null) {
            String sObjName = recordId.getSobjectType().getDescribe().getName();
            if (sObjName == 'Candidate_Job_Match__c') {
                context.selectedMatchId = recordId;
                context.matchDetail = getMatchDetail(recordId);
                if (context.matchDetail != null) {
                    context.selectedJobId = context.matchDetail.jobId;
                    context.rankedCandidates = getMatchesForJob(context.selectedJobId);
                }
                return context;
            } else if (sObjName == 'Job_Requisition__c') {
                context.selectedJobId = recordId;
                context.rankedCandidates = getMatchesForJob(recordId);
                if (!context.rankedCandidates.isEmpty()) {
                    context.selectedMatchId = context.rankedCandidates[0].matchId;
                    context.matchDetail = getMatchDetail(context.selectedMatchId);
                }
                return context;
            } else if (sObjName == 'Candidate__c') {
                List<Candidate_Job_Match__c> candMatches = [
                    SELECT Id, Job_Requisition__c FROM Candidate_Job_Match__c
                    WHERE Candidate__c = :recordId
                    ORDER BY Overall_Match_Score__c DESC LIMIT 1
                ];
                if (!candMatches.isEmpty()) {
                    context.selectedMatchId = candMatches[0].Id;
                    context.selectedJobId = candMatches[0].Job_Requisition__c;
                    context.matchDetail = getMatchDetail(candMatches[0].Id);
                    context.rankedCandidates = getMatchesForJob(context.selectedJobId);
                }
                return context;
            }
        }

        // Default: pick first active job or AI/ML Engineer
        if (!context.activeJobs.isEmpty()) {
            Id defaultJobId = context.activeJobs[0].Id;
            for (Job_Requisition__c j : context.activeJobs) {
                if (j.Job_Title__c != null && j.Job_Title__c.containsIgnoreCase('AI/ML')) {
                    defaultJobId = j.Id;
                    break;
                }
            }
            context.selectedJobId = defaultJobId;
            context.rankedCandidates = getMatchesForJob(defaultJobId);
            if (!context.rankedCandidates.isEmpty()) {
                context.selectedMatchId = context.rankedCandidates[0].matchId;
                context.matchDetail = getMatchDetail(context.selectedMatchId);
            }
        }

        return context;
    }

    /**
     * Re-evaluates a single candidate-job match on-demand via CandidateJobMatchService.
     */
    @AuraEnabled
    public static MatchDetailDTO recalculateMatch(Id matchId) {
        if (matchId == null) {
            throw new AuraHandledException('Match ID is required for recalculation.');
        }

        Candidate_Job_Match__c matchRec = [
            SELECT Candidate__c, Job_Requisition__c
            FROM Candidate_Job_Match__c
            WHERE Id = :matchId
            LIMIT 1
        ];

        Candidate_Job_Match__c refreshed = CandidateJobMatchService.evaluateAndSaveMatch(
            matchRec.Candidate__c,
            matchRec.Job_Requisition__c
        );

        return getMatchDetail(refreshed.Id);
    }

    /**
     * Re-evaluates all candidates against a job requisition on-demand via CandidateJobMatchService.
     */
    @AuraEnabled
    public static List<MatchSummaryDTO> recalculateJobMatches(Id jobId) {
        if (jobId == null) {
            throw new AuraHandledException('Job Requisition ID is required for recalculation.');
        }

        CandidateJobMatchService.evaluateCandidatesForJob(jobId, true);
        return getMatchesForJob(jobId);
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    private static MatchDetailDTO buildMatchDetailDTO(Candidate_Job_Match__c m, WeightConfigDTO w) {
        MatchDetailDTO dto = new MatchDetailDTO();
        dto.matchId = m.Id;
        dto.matchName = m.Name;
        dto.matchKey = m.Match_Key__c;

        // Candidate
        dto.candidateId = m.Candidate__c;
        dto.candidateName = String.isNotBlank(m.Candidate__r.Candidate_Name__c) ? m.Candidate__r.Candidate_Name__c : m.Candidate__r.Name;
        dto.candidateEmail = m.Candidate__r.Email__c;
        dto.candidatePhone = Schema.sObjectType.Candidate__c.fields.Phone__c.isAccessible() 
            ? m.Candidate__r.Phone__c 
            : '[Protected - Contact Recruiter]';
        dto.candidateLocation = m.Candidate__r.Location__c;
        dto.candidateExperience = m.Candidate__r.Years_of_Experience__c;
        dto.candidateQualification = m.Candidate__r.Highest_Qualification__c;
        dto.candidateSkills = m.Candidate__r.Skills__c;

        // Job Requisition
        dto.jobId = m.Job_Requisition__c;
        dto.jobTitle = m.Job_Requisition__r.Job_Title__c;
        dto.jobCode = m.Job_Requisition__r.Job_Code__c;
        dto.jobDepartment = m.Job_Requisition__r.Department__c;
        dto.jobLocation = m.Job_Requisition__r.Location__c;
        dto.jobExperienceRequired = m.Job_Requisition__r.Experience_Required__c;
        dto.jobMinimumQualification = m.Job_Requisition__r.Minimum_Qualification__c;
        dto.jobRequiredSkills = m.Job_Requisition__r.Required_Skills__c;

        // Overall
        dto.overallScore = m.Overall_Match_Score__c != null ? m.Overall_Match_Score__c : 0.00;
        dto.recommendation = m.Recommendation__c != null ? m.Recommendation__c : 'Not Evaluated';
        dto.evaluationStatus = m.Evaluation_Status__c != null ? m.Evaluation_Status__c : 'Pending';
        dto.calculatedOn = m.Calculated_On__c;
        dto.calculatedOnFormatted = m.Calculated_On__c != null ? m.Calculated_On__c.format('MMM d, yyyy, h:mm a') : 'N/A';

        // Weights & Factors
        dto.skillScore = m.Skill_Match_Percent__c != null ? m.Skill_Match_Percent__c : 0.00;
        dto.skillWeight = w.skillWeight;
        dto.skillContribution = ((dto.skillScore * w.skillWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);
        dto.skillGapPercent = m.Skill_Gap_Percent__c != null ? m.Skill_Gap_Percent__c : (100.00 - dto.skillScore);

        dto.experienceScore = m.Experience_Match_Percent__c != null ? m.Experience_Match_Percent__c : 0.00;
        dto.experienceWeight = w.experienceWeight;
        dto.experienceContribution = ((dto.experienceScore * w.experienceWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        dto.qualificationScore = m.Qualification_Match_Percent__c != null ? m.Qualification_Match_Percent__c : 0.00;
        dto.qualificationWeight = w.qualificationWeight;
        dto.qualificationContribution = ((dto.qualificationScore * w.qualificationWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        dto.locationScore = m.Location_Match_Percent__c != null ? m.Location_Match_Percent__c : 0.00;
        dto.locationWeight = w.locationWeight;
        dto.locationContribution = ((dto.locationScore * w.locationWeight) / 100.00).setScale(2, System.RoundingMode.HALF_UP);

        dto.totalWeight = w.totalWeight;

        // Skills Parsing
        dto.rawMatchedSkills = m.Matched_Skills__c;
        dto.rawMissingSkills = m.Missing_Skills__c;
        dto.matchedSkillsList = parseSkillList(m.Matched_Skills__c);
        dto.missingSkillsList = parseSkillList(m.Missing_Skills__c);

        // Explanation & Review Points
        dto.explanation = m.Explanation__c;
        dto.recruiterAttentionPoints = deriveRecruiterAttentionPoints(dto);
        dto.responsibleAiNotice = 'Decision-support only. The match score is based on explicit job-relevant information and does not predict hiring probability. Final recruitment decisions remain with authorized human recruiters.';

        return dto;
    }

    /**
     * Splits comma, semicolon, bullet, or newline-delimited skill strings into a clean list of individual tokens.
     */
    public static List<String> parseSkillList(String rawSkills) {
        List<String> result = new List<String>();
        if (String.isBlank(rawSkills) || rawSkills.equalsIgnoreCase('None')) {
            return result;
        }

        List<String> rawTokens = rawSkills.split('[,;\n\r•]+');
        for (String token : rawTokens) {
            String trimmed = token.trim();
            if (String.isNotBlank(trimmed) && !trimmed.equalsIgnoreCase('None')) {
                result.add(trimmed);
            }
        }
        return result;
    }

    /**
     * Derives actionable review points strictly from actual match information.
     */
    public static List<String> deriveRecruiterAttentionPoints(MatchDetailDTO d) {
        List<String> points = new List<String>();

        // Missing Skills Review Point
        if (d.missingSkillsList != null && !d.missingSkillsList.isEmpty()) {
            points.add('Verify practical experience with ' + String.join(d.missingSkillsList, ', ') + ' during technical evaluation.');
        }

        // Experience Gap Review Point
        if (d.candidateExperience != null && d.jobExperienceRequired != null && d.candidateExperience < d.jobExperienceRequired) {
            points.add('Candidate profile indicates ' + d.candidateExperience + ' yrs experience vs ' + d.jobExperienceRequired + ' yrs required; evaluate project depth and scope during interview.');
        }

        // Location Review Point
        if (d.locationScore < 100.00 && String.isNotBlank(d.candidateLocation) && String.isNotBlank(d.jobLocation)) {
            points.add('Role is located in ' + d.jobLocation + ' while candidate is based in ' + d.candidateLocation + '; confirm relocation willingness or remote work flexibility.');
        }

        // Qualification Review Point
        if (d.qualificationScore < 100.00 && String.isNotBlank(d.jobMinimumQualification)) {
            String candEdu = String.isNotBlank(d.candidateQualification) ? d.candidateQualification : 'Not specified';
            points.add('Candidate qualification is (' + candEdu + ') vs role requirement (' + d.jobMinimumQualification + '); review equivalent professional accomplishments.');
        }

        // If no gaps identified
        if (points.isEmpty()) {
            points.add('Candidate meets or exceeds all explicit baseline requirements for skills, experience, education, and location.');
        }

        return points;
    }
}
