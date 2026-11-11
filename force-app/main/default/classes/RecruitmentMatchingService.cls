public with sharing class RecruitmentMatchingService {

    public class MatchResult implements Comparable {
        public Id candidateId;
        public String candidateName;
        public String candidateEmail;
        public String candidateLocation;
        public Decimal candidateExperience;
        public String candidateQualification;
        public String candidateSkills;

        public Id jobId;
        public String jobTitle;
        public String jobCode;
        public String jobDepartment;
        public String jobLocation;
        public Decimal jobExperienceRequired;
        public String jobMinQualification;
        public String jobRequiredSkills;

        public Decimal overallScore;       // 0 to 100
        public String fitTier;             // Strong Match, Good Match, Moderate Match, Low Match
        public Decimal skillScore;         // 0 to 50
        public Decimal skillPercentage;    // 0 to 100
        public Decimal experienceScore;    // 0 to 25
        public Decimal qualificationScore; // 0 to 15
        public Decimal locationScore;      // 0 to 10

        public List<String> matchedSkills = new List<String>();
        public List<String> missingSkills = new List<String>();
        public String rationale;
        public Id applicationId;

        public Integer compareTo(Object compareTo) {
            MatchResult other = (MatchResult)compareTo;
            if (this.overallScore == other.overallScore) {
                return 0;
            }
            return (this.overallScore < other.overallScore) ? 1 : -1;
        }
    }

    /**
     * Calculates candidate-to-job multi-factor compatibility score and rationale.
     * Weights: Skills 50%, Experience 25%, Qualification 15%, Location 10%.
     */
    public static MatchResult calculateMatch(Candidate__c candidate, Job_Requisition__c job) {
        MatchResult res = new MatchResult();
        if (candidate != null) {
            res.candidateId = candidate.Id;
            res.candidateName = candidate.Candidate_Name__c;
            res.candidateEmail = candidate.Email__c;
            res.candidateLocation = candidate.Location__c;
            res.candidateExperience = candidate.Years_of_Experience__c;
            res.candidateQualification = candidate.Highest_Qualification__c;
            res.candidateSkills = candidate.Skills__c;
        }

        if (job != null) {
            res.jobId = job.Id;
            res.jobTitle = job.Job_Title__c;
            res.jobCode = job.Job_Code__c;
            res.jobDepartment = job.Department__c;
            res.jobLocation = job.Location__c;
            res.jobExperienceRequired = job.Experience_Required__c;
            res.jobMinQualification = job.Minimum_Qualification__c;
            res.jobRequiredSkills = job.Required_Skills__c;
        }

        // 1. SKILLS EVALUATION (50% weight)
        evaluateSkills(candidate != null ? candidate.Skills__c : null,
                       job != null ? job.Required_Skills__c : null,
                       res);

        // 2. EXPERIENCE EVALUATION (25% weight)
        evaluateExperience(candidate != null ? candidate.Years_of_Experience__c : null,
                           job != null ? job.Experience_Required__c : null,
                           res);

        // 3. QUALIFICATION EVALUATION (15% weight)
        evaluateQualification(candidate != null ? candidate.Highest_Qualification__c : null,
                              job != null ? job.Minimum_Qualification__c : null,
                              res);

        // 4. LOCATION EVALUATION (10% weight)
        evaluateLocation(candidate != null ? candidate.Location__c : null,
                         job != null ? job.Location__c : null,
                         res);

        // OVERALL SCORE
        Decimal rawTotal = res.skillScore + res.experienceScore + res.qualificationScore + res.locationScore;
        res.overallScore = rawTotal.setScale(2, System.RoundingMode.HALF_UP);
        if (res.overallScore > 100) {
            res.overallScore = 100.00;
        } else if (res.overallScore < 0) {
            res.overallScore = 0.00;
        }

        // FIT TIER
        if (res.overallScore >= 85.0) {
            res.fitTier = 'Strong Match';
        } else if (res.overallScore >= 70.0) {
            res.fitTier = 'Good Match';
        } else if (res.overallScore >= 50.0) {
            res.fitTier = 'Moderate Match';
        } else {
            res.fitTier = 'Low Match';
        }

        // RATIONALE GENERATION
        buildRationale(res);

        return res;
    }

    /**
     * Ranks all active candidates against a specified Job Requisition.
     */
    public static List<MatchResult> matchCandidatesToJob(Id jobId, Integer limitN) {
        if (jobId == null) {
            return new List<MatchResult>();
        }

        List<Job_Requisition__c> jobs = [
            SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c,
                   Experience_Required__c, Minimum_Qualification__c, Required_Skills__c
            FROM Job_Requisition__c
            WHERE Id = :jobId
            LIMIT 1
        ];
        if (jobs.isEmpty()) {
            return new List<MatchResult>();
        }

        Job_Requisition__c job = jobs[0];
        List<Candidate__c> candidates = [
            SELECT Id, Candidate_Name__c, Email__c, Phone__c, Location__c,
                   Highest_Qualification__c, University__c, Years_of_Experience__c,
                   Skills__c, Candidate_Status__c
            FROM Candidate__c
        ];

        List<MatchResult> results = new List<MatchResult>();
        for (Candidate__c cand : candidates) {
            results.add(calculateMatch(cand, job));
        }

        results.sort();

        if (limitN != null && limitN > 0 && results.size() > limitN) {
            List<MatchResult> truncated = new List<MatchResult>();
            for (Integer i = 0; i < limitN; i++) {
                truncated.add(results[i]);
            }
            return truncated;
        }
        return results;
    }

    /**
     * Ranks all open Job Requisitions for a specified Candidate.
     */
    public static List<MatchResult> matchJobsToCandidate(Id candidateId, Integer limitN) {
        if (candidateId == null) {
            return new List<MatchResult>();
        }

        List<Candidate__c> candidates = [
            SELECT Id, Candidate_Name__c, Email__c, Phone__c, Location__c,
                   Highest_Qualification__c, University__c, Years_of_Experience__c,
                   Skills__c, Candidate_Status__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        if (candidates.isEmpty()) {
            return new List<MatchResult>();
        }

        Candidate__c cand = candidates[0];
        List<Job_Requisition__c> openJobs = [
            SELECT Id, Job_Title__c, Job_Code__c, Department__c, Location__c,
                   Experience_Required__c, Minimum_Qualification__c, Required_Skills__c
            FROM Job_Requisition__c
            WHERE Status__c = 'Open'
        ];

        List<MatchResult> results = new List<MatchResult>();
        for (Job_Requisition__c job : openJobs) {
            results.add(calculateMatch(cand, job));
        }

        results.sort();

        if (limitN != null && limitN > 0 && results.size() > limitN) {
            List<MatchResult> truncated = new List<MatchResult>();
            for (Integer i = 0; i < limitN; i++) {
                truncated.add(results[i]);
            }
            return truncated;
        }
        return results;
    }

    /**
     * Evaluates existing Job Application records and optionally updates matching fields.
     * Note: Does NOT modify Application_Status__c (human-in-the-loop safety rule).
     */
    public static List<MatchResult> evaluateApplications(List<Id> applicationIds, Boolean persistScores) {
        String query = 'SELECT Id, Application_Number__c, Application_Status__c, ' +
                       'Candidate__c, Candidate__r.Candidate_Name__c, Candidate__r.Email__c, ' +
                       'Candidate__r.Location__c, Candidate__r.Years_of_Experience__c, ' +
                       'Candidate__r.Highest_Qualification__c, Candidate__r.Skills__c, ' +
                       'Job_Requisition__c, Job_Requisition__r.Job_Title__c, Job_Requisition__r.Job_Code__c, ' +
                       'Job_Requisition__r.Department__c, Job_Requisition__r.Location__c, ' +
                       'Job_Requisition__r.Experience_Required__c, Job_Requisition__r.Minimum_Qualification__c, ' +
                       'Job_Requisition__r.Required_Skills__c ' +
                       'FROM Job_Application__c ';

        if (applicationIds != null && !applicationIds.isEmpty()) {
            query += 'WHERE Id IN :applicationIds ORDER BY Application_Number__c ASC';
        } else {
            query += 'ORDER BY Application_Number__c ASC';
        }

        List<Job_Application__c> apps = Database.query(query);
        List<MatchResult> results = new List<MatchResult>();
        List<Job_Application__c> toUpdate = new List<Job_Application__c>();

        for (Job_Application__c app : apps) {
            MatchResult mr = calculateMatch(app.Candidate__r, app.Job_Requisition__r);
            mr.applicationId = app.Id;
            results.add(mr);

            if (persistScores == true) {
                Job_Application__c updatedApp = new Job_Application__c(
                    Id = app.Id,
                    Match_Score__c = mr.overallScore,
                    Skill_Match_Percentage__c = mr.skillPercentage,
                    Match_Rationale__c = truncateString(mr.rationale, 32000),
                    Missing_Skills__c = truncateString(String.join(mr.missingSkills, ', '), 2000)
                );
                toUpdate.add(updatedApp);
            }
        }

        if (persistScores == true && !toUpdate.isEmpty()) {
            update toUpdate;
        }

        results.sort();
        return results;
    }

    // --- Private Helper Methods ---

    private static void evaluateSkills(String candidateSkillsStr, String requiredSkillsStr, MatchResult res) {
        if (String.isBlank(requiredSkillsStr)) {
            // No specific skills required -> full score
            res.skillPercentage = 100.00;
            res.skillScore = 50.00;
            return;
        }

        List<String> requiredList = parseTokens(requiredSkillsStr);
        if (requiredList.isEmpty()) {
            res.skillPercentage = 100.00;
            res.skillScore = 50.00;
            return;
        }

        if (String.isBlank(candidateSkillsStr)) {
            res.skillPercentage = 0.00;
            res.skillScore = 0.00;
            res.missingSkills.addAll(requiredList);
            return;
        }

        String candNormalized = candidateSkillsStr.toLowerCase();
        Set<String> candidateTokens = new Set<String>();
        for (String t : parseTokens(candidateSkillsStr)) {
            candidateTokens.add(t.toLowerCase());
        }

        for (String reqSkill : requiredList) {
            String reqLower = reqSkill.toLowerCase();
            Boolean matched = false;

            // Direct substring match in full candidate skills text
            if (candNormalized.contains(reqLower)) {
                matched = true;
            } else {
                // Token-level synonym & semantic check
                for (String cToken : candidateTokens) {
                    if (isSkillEquivalent(reqLower, cToken)) {
                        matched = true;
                        break;
                    }
                }
            }

            if (matched) {
                res.matchedSkills.add(reqSkill);
            } else {
                res.missingSkills.add(reqSkill);
            }
        }

        Decimal pct = (Decimal.valueOf(res.matchedSkills.size()) / Decimal.valueOf(requiredList.size())) * 100.0;
        res.skillPercentage = pct.setScale(2, System.RoundingMode.HALF_UP);
        Decimal sScore = (res.skillPercentage / 100.0) * 50.0;
        res.skillScore = sScore.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static void evaluateExperience(Decimal candExp, Decimal reqExp, MatchResult res) {
        if (reqExp == null || reqExp <= 0) {
            res.experienceScore = 25.00;
            return;
        }
        if (candExp == null || candExp <= 0) {
            res.experienceScore = 0.00;
            return;
        }

        if (candExp >= reqExp) {
            res.experienceScore = 25.00;
        } else if (candExp >= (reqExp - 1.0)) {
            res.experienceScore = 18.75; // 75%
        } else if (candExp >= (reqExp - 2.0)) {
            res.experienceScore = 12.50; // 50%
        } else {
            Decimal ratio = (candExp / reqExp) * 25.0;
            res.experienceScore = Math.max(0.00, ratio.setScale(2, System.RoundingMode.HALF_UP));
        }
    }

    private static void evaluateQualification(String candQual, String reqQual, MatchResult res) {
        Integer candTier = getEducationTier(candQual);
        Integer reqTier = getEducationTier(reqQual);

        if (candTier >= reqTier) {
            res.qualificationScore = 15.00;
        } else if (candTier == reqTier - 1) {
            res.qualificationScore = 9.00; // 60%
        } else {
            res.qualificationScore = 3.75; // 25%
        }
    }

    private static Integer getEducationTier(String qual) {
        if (String.isBlank(qual)) {
            return 1;
        }
        String q = qual.toLowerCase();
        if (q.contains('phd') || q.contains('ph.d') || q.contains('doctorate') || q.contains('doctor')) {
            return 4;
        }
        if (q.contains('ms') || q.contains('m.s') || q.contains('master') || q.contains('m.tech') ||
            q.contains('mtech') || q.contains('mba') || q.contains('mca')) {
            return 3;
        }
        if (q.contains('bs') || q.contains('b.s') || q.contains('bachelor') || q.contains('b.tech') ||
            q.contains('btech') || q.contains('b.e') || q.contains('b.sc') || q.contains('bsc') ||
            q.contains('bca') || q.contains('ba')) {
            return 2;
        }
        return 1;
    }

    private static void evaluateLocation(String candLoc, String jobLoc, MatchResult res) {
        if (String.isBlank(jobLoc) || String.isBlank(candLoc)) {
            res.locationScore = 5.00;
            return;
        }

        String jLower = jobLoc.toLowerCase();
        String cLower = candLoc.toLowerCase();

        // Remote compatibility
        if (jLower.contains('remote') || cLower.contains('remote')) {
            res.locationScore = 10.00;
            return;
        }

        // Direct containment
        if (jLower.contains(cLower) || cLower.contains(jLower)) {
            res.locationScore = 10.00;
            return;
        }

        // Check common cities and regions
        List<String> keyLocations = new List<String>{
            'san francisco', 'austin', 'seattle', 'new york', 'boston', 'chicago',
            'denver', 'atlanta', 'los angeles', 'san diego', 'mumbai'
        };
        for (String loc : keyLocations) {
            if (jLower.contains(loc) && cLower.contains(loc)) {
                res.locationScore = 10.00;
                return;
            }
        }

        // Candidate in different location, non-remote
        res.locationScore = 4.00;
    }

    private static Boolean isSkillEquivalent(String req, String cand) {
        if (req == cand) {
            return true;
        }
        // AI / ML synonyms
        Set<String> aimlTerms = new Set<String>{
            'ai', 'ml', 'machine learning', 'deep learning', 'pytorch', 'tensorflow',
            'nlp', 'llm', 'llms', 'transformer', 'transformers', 'agentforce', 'langchain'
        };
        if (aimlTerms.contains(req) && aimlTerms.contains(cand)) {
            return true;
        }

        // Fullstack / Frontend synonyms
        Set<String> frontTerms = new Set<String>{'react', 'react.js', 'reactjs', 'next.js'};
        if (frontTerms.contains(req) && frontTerms.contains(cand)) {
            return true;
        }
        Set<String> jsTerms = new Set<String>{'javascript', 'typescript', 'js', 'node.js', 'node'};
        if (jsTerms.contains(req) && jsTerms.contains(cand)) {
            return true;
        }

        // Java synonyms
        if (req.startsWith('java') && cand.startsWith('java')) {
            return true;
        }

        // Cloud & DevOps synonyms
        Set<String> containerTerms = new Set<String>{'docker', 'kubernetes', 'k8s', 'microservices'};
        if (containerTerms.contains(req) && containerTerms.contains(cand)) {
            return true;
        }

        // Database synonyms
        Set<String> sqlTerms = new Set<String>{'sql', 'postgresql', 'postgres', 'mysql', 'bigquery', 'snowflake'};
        if (sqlTerms.contains(req) && sqlTerms.contains(cand)) {
            return true;
        }

        return false;
    }

    private static List<String> parseTokens(String input) {
        List<String> tokens = new List<String>();
        if (String.isBlank(input)) {
            return tokens;
        }
        // Split by comma, semicolon, newline, slash
        for (String part : input.split('[,;\\n\\/]+')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                tokens.add(trimmed);
            }
        }
        return tokens;
    }

    private static void buildRationale(MatchResult res) {
        List<String> parts = new List<String>();
        parts.add('Overall Match: ' + res.overallScore + '% (' + res.fitTier + ')');

        // Skills
        parts.add('Skills Match (' + res.skillScore + '/50 pts, ' + res.skillPercentage + '%): ' +
                  (res.matchedSkills.isEmpty() ? 'None' : String.join(res.matchedSkills, ', ')));
        if (!res.missingSkills.isEmpty()) {
            parts.add('Missing Skills: ' + String.join(res.missingSkills, ', '));
        }

        // Experience
        String candExpStr = (res.candidateExperience != null ? String.valueOf(res.candidateExperience) : '0') + ' yrs';
        String reqExpStr = (res.jobExperienceRequired != null ? String.valueOf(res.jobExperienceRequired) : '0') + ' yrs';
        parts.add('Experience (' + res.experienceScore + '/25 pts): Candidate has ' + candExpStr + ' vs ' + reqExpStr + ' required');

        // Qualification
        parts.add('Education (' + res.qualificationScore + '/15 pts): ' +
                  (String.isNotBlank(res.candidateQualification) ? res.candidateQualification : 'Not specified') +
                  ' vs ' +
                  (String.isNotBlank(res.jobMinQualification) ? res.jobMinQualification : 'Not specified'));

        // Location
        parts.add('Location (' + res.locationScore + '/10 pts): ' +
                  (String.isNotBlank(res.candidateLocation) ? res.candidateLocation : 'Not specified') +
                  ' vs ' +
                  (String.isNotBlank(res.jobLocation) ? res.jobLocation : 'Not specified'));

        res.rationale = String.join(parts, '\n');
    }

    private static String truncateString(String str, Integer maxLen) {
        if (str == null) {
            return null;
        }
        if (str.length() <= maxLen) {
            return str;
        }
        return str.substring(0, maxLen);
    }
}
