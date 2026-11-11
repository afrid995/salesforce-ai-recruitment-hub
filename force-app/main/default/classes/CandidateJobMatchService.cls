public with sharing class CandidateJobMatchService {

    public class WeightConfig {
        public Decimal skillWeight;
        public Decimal experienceWeight;
        public Decimal qualificationWeight;
        public Decimal locationWeight;

        public WeightConfig() {
            this.skillWeight = 50.00;
            this.experienceWeight = 25.00;
            this.qualificationWeight = 15.00;
            this.locationWeight = 10.00;
        }

        public WeightConfig(Decimal s, Decimal e, Decimal q, Decimal l) {
            this.skillWeight = (s != null && s >= 0) ? s : 50.00;
            this.experienceWeight = (e != null && e >= 0) ? e : 25.00;
            this.qualificationWeight = (q != null && q >= 0) ? q : 15.00;
            this.locationWeight = (l != null && l >= 0) ? l : 10.00;
        }
    }

    /**
     * Retrieves configurable weights from Custom Metadata Type Match_Weight_Configuration__mdt,
     * with graceful fallback to default weights (50, 25, 15, 10).
     */
    public static WeightConfig getWeightConfiguration() {
        try {
            List<Match_Weight_Configuration__mdt> configs = [
                SELECT Skill_Weight__c, Experience_Weight__c, Qualification_Weight__c, Location_Weight__c
                FROM Match_Weight_Configuration__mdt
                WHERE DeveloperName = 'Default_Weight'
                LIMIT 1
            ];
            if (!configs.isEmpty()) {
                Match_Weight_Configuration__mdt cfg = configs[0];
                return new WeightConfig(
                    cfg.Skill_Weight__c,
                    cfg.Experience_Weight__c,
                    cfg.Qualification_Weight__c,
                    cfg.Location_Weight__c
                );
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Could not load Match_Weight_Configuration__mdt, falling back to defaults: ' + ex.getMessage());
        }
        return new WeightConfig();
    }

    /**
     * Evaluates compatibility between a single Candidate and Job Requisition.
     * Produces a Candidate_Job_Match__c evaluation record in memory.
     */
    public static Candidate_Job_Match__c evaluateMatch(Candidate__c cand, Job_Requisition__c job) {
        return evaluateMatchWithWeights(cand, job, getWeightConfiguration());
    }

    /**
     * Evaluates compatibility between Candidate and Job Requisition with custom weights.
     */
    public static Candidate_Job_Match__c evaluateMatchWithWeights(Candidate__c cand, Job_Requisition__c job, WeightConfig weights) {
        Candidate_Job_Match__c matchRec = new Candidate_Job_Match__c();

        Id candId = cand != null ? cand.Id : null;
        Id jobId = job != null ? job.Id : null;

        matchRec.Candidate__c = candId;
        matchRec.Job_Requisition__c = jobId;

        if (candId != null && jobId != null) {
            matchRec.Match_Key__c = String.valueOf(candId) + '_' + String.valueOf(jobId);
        }

        matchRec.Evaluation_Status__c = 'Completed';
        matchRec.Calculated_On__c = DateTime.now();

        // 1. SKILLS EVALUATION (Default 50%)
        List<String> matchedSkills = new List<String>();
        List<String> missingSkills = new List<String>();
        Decimal skillMatchPercent = evaluateSkills(
            cand != null ? cand.Skills__c : null,
            job != null ? job.Required_Skills__c : null,
            matchedSkills,
            missingSkills
        );
        matchRec.Skill_Match_Percent__c = skillMatchPercent;
        matchRec.Skill_Gap_Percent__c = (100.00 - skillMatchPercent).setScale(2, System.RoundingMode.HALF_UP);
        matchRec.Matched_Skills__c = matchedSkills.isEmpty() ? 'None' : String.join(matchedSkills, ', ');
        matchRec.Missing_Skills__c = missingSkills.isEmpty() ? 'None' : String.join(missingSkills, ', ');

        // 2. EXPERIENCE EVALUATION (Default 25%)
        Decimal expMatchPercent = evaluateExperience(
            cand != null ? cand.Years_of_Experience__c : null,
            job != null ? job.Experience_Required__c : null
        );
        matchRec.Experience_Match_Percent__c = expMatchPercent;

        // 3. QUALIFICATION EVALUATION (Default 15%)
        Decimal qualMatchPercent = evaluateQualification(
            cand != null ? cand.Highest_Qualification__c : null,
            job != null ? job.Minimum_Qualification__c : null
        );
        matchRec.Qualification_Match_Percent__c = qualMatchPercent;

        // 4. LOCATION & EMPLOYMENT COMPATIBILITY (Default 10%)
        Decimal locMatchPercent = evaluateLocation(
            cand != null ? cand.Location__c : null,
            job != null ? job.Location__c : null
        );
        matchRec.Location_Match_Percent__c = locMatchPercent;

        // 5. WEIGHTED OVERALL MATCH SCORE
        WeightConfig w = weights != null ? weights : new WeightConfig();
        Decimal totalWeight = w.skillWeight + w.experienceWeight + w.qualificationWeight + w.locationWeight;
        if (totalWeight <= 0) totalWeight = 100.00;

        Decimal weightedSum = (skillMatchPercent * w.skillWeight) +
                             (expMatchPercent * w.experienceWeight) +
                             (qualMatchPercent * w.qualificationWeight) +
                             (locMatchPercent * w.locationWeight);

        Decimal rawScore = weightedSum / totalWeight;
        Decimal overallScore = rawScore.setScale(2, System.RoundingMode.HALF_UP);
        if (overallScore > 100.00) overallScore = 100.00;
        if (overallScore < 0.00) overallScore = 0.00;
        matchRec.Overall_Match_Score__c = overallScore;

        // 6. RECOMMENDATION TIER
        if (overallScore >= 85.00) {
            matchRec.Recommendation__c = 'Strong Match';
        } else if (overallScore >= 70.00) {
            matchRec.Recommendation__c = 'Good Match';
        } else if (overallScore >= 50.00) {
            matchRec.Recommendation__c = 'Moderate Match';
        } else {
            matchRec.Recommendation__c = 'Low Match';
        }

        // 7. EXPLAINABLE RECRUITER RATIONALE
        matchRec.Explanation__c = generateExplanation(cand, job, matchRec, w, matchedSkills, missingSkills);

        return matchRec;
    }

    /**
     * Evaluates a candidate-job pair by IDs and persists the result to Candidate_Job_Match__c.
     */
    public static Candidate_Job_Match__c evaluateAndSaveMatch(Id candidateId, Id jobId) {
        if (candidateId == null || jobId == null) {
            return null;
        }

        Candidate__c cand = [
            SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c,
                   Highest_Qualification__c, Location__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        Job_Requisition__c job = [
            SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c,
                   Experience_Required__c, Minimum_Qualification__c, Location__c,
                   Employment_Type__c
            FROM Job_Requisition__c
            WHERE Id = :jobId
            LIMIT 1
        ];

        Candidate_Job_Match__c matchRec = evaluateMatch(cand, job);
        checkMatchUpsertPermission();
        upsert matchRec Match_Key__c;
        return matchRec;
    }

    /**
     * Evaluates all candidates against a specific job requisition, ranks them descending by match score,
     * and optionally persists the match evaluations to Candidate_Job_Match__c.
     */
    public static List<Candidate_Job_Match__c> evaluateCandidatesForJob(Id jobId, Boolean persist) {
        if (jobId == null) {
            return new List<Candidate_Job_Match__c>();
        }

        Job_Requisition__c job = [
            SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c,
                   Experience_Required__c, Minimum_Qualification__c, Location__c,
                   Employment_Type__c
            FROM Job_Requisition__c
            WHERE Id = :jobId
            LIMIT 1
        ];

        List<Candidate__c> candidates = [
            SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c,
                   Highest_Qualification__c, Location__c
            FROM Candidate__c
            ORDER BY Candidate_Name__c ASC
        ];

        WeightConfig weights = getWeightConfiguration();
        List<Candidate_Job_Match__c> matches = new List<Candidate_Job_Match__c>();

        for (Candidate__c c : candidates) {
            matches.add(evaluateMatchWithWeights(c, job, weights));
        }

        sortMatchesDescending(matches);

        if (persist == true && !matches.isEmpty()) {
            checkMatchUpsertPermission();
            upsert matches Match_Key__c;
        }

        return matches;
    }

    /**
     * Evaluates a candidate against all open job requisitions, ranks them descending by match score,
     * and optionally persists the evaluations.
     */
    public static List<Candidate_Job_Match__c> evaluateJobsForCandidate(Id candidateId, Boolean persist) {
        if (candidateId == null) {
            return new List<Candidate_Job_Match__c>();
        }

        Candidate__c cand = [
            SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c,
                   Highest_Qualification__c, Location__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        List<Job_Requisition__c> openJobs = [
            SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c,
                   Experience_Required__c, Minimum_Qualification__c, Location__c,
                   Employment_Type__c
            FROM Job_Requisition__c
            WHERE Status__c = 'Open'
            ORDER BY Job_Code__c ASC
        ];

        WeightConfig weights = getWeightConfiguration();
        List<Candidate_Job_Match__c> matches = new List<Candidate_Job_Match__c>();

        for (Job_Requisition__c j : openJobs) {
            matches.add(evaluateMatchWithWeights(cand, j, weights));
        }

        sortMatchesDescending(matches);

        if (persist == true && !matches.isEmpty()) {
            checkMatchUpsertPermission();
            upsert matches Match_Key__c;
        }

        return matches;
    }

    /**
     * Evaluates all candidates across all open job requisitions and optionally persists match evaluations.
     */
    public static List<Candidate_Job_Match__c> evaluateAll(Boolean persist) {
        List<Candidate__c> candidates = [
            SELECT Id, Candidate_Name__c, Skills__c, Years_of_Experience__c,
                   Highest_Qualification__c, Location__c
            FROM Candidate__c
        ];

        List<Job_Requisition__c> openJobs = [
            SELECT Id, Job_Title__c, Job_Code__c, Required_Skills__c,
                   Experience_Required__c, Minimum_Qualification__c, Location__c,
                   Employment_Type__c
            FROM Job_Requisition__c
            WHERE Status__c = 'Open'
        ];

        WeightConfig weights = getWeightConfiguration();
        List<Candidate_Job_Match__c> allMatches = new List<Candidate_Job_Match__c>();

        for (Job_Requisition__c job : openJobs) {
            for (Candidate__c cand : candidates) {
                allMatches.add(evaluateMatchWithWeights(cand, job, weights));
            }
        }

        sortMatchesDescending(allMatches);

        if (persist == true && !allMatches.isEmpty()) {
            checkMatchUpsertPermission();
            upsert allMatches Match_Key__c;
        }

        return allMatches;
    }

    private static void checkMatchUpsertPermission() {
        if (!Schema.sObjectType.Candidate_Job_Match__c.isCreateable() || !Schema.sObjectType.Candidate_Job_Match__c.isUpdateable()) {
            throw new System.NoAccessException();
        }
    }

    // --- Private Matching & Scoring Calculations ---

    /**
     * Compares candidate skills against job required skills.
     * Case-insensitive, supports comma, semicolon, slash, and newline separators.
     */
    private static Decimal evaluateSkills(String candidateSkillsStr, String requiredSkillsStr,
                                          List<String> matchedSkills, List<String> missingSkills) {
        if (String.isBlank(requiredSkillsStr)) {
            return 100.00;
        }

        List<String> requiredTokens = parseTokens(requiredSkillsStr);
        if (requiredTokens.isEmpty()) {
            return 100.00;
        }

        if (String.isBlank(candidateSkillsStr)) {
            missingSkills.addAll(requiredTokens);
            return 0.00;
        }

        String candNormalized = candidateSkillsStr.toLowerCase();
        Set<String> candidateTokenSet = new Set<String>();
        for (String t : parseTokens(candidateSkillsStr)) {
            candidateTokenSet.add(t.toLowerCase());
        }

        for (String req : requiredTokens) {
            String reqLower = req.toLowerCase();
            Boolean found = false;

            // Direct substring match
            if (candNormalized.contains(reqLower)) {
                found = true;
            } else {
                // Semantic synonym check across atomic tokens
                for (String cToken : candidateTokenSet) {
                    if (areSkillsEquivalent(reqLower, cToken)) {
                        found = true;
                        break;
                    }
                }
            }

            if (found) {
                matchedSkills.add(req);
            } else {
                missingSkills.add(req);
            }
        }

        Decimal coverage = (Decimal.valueOf(matchedSkills.size()) / Decimal.valueOf(requiredTokens.size())) * 100.00;
        return coverage.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * Compares candidate experience against job required experience.
     */
    private static Decimal evaluateExperience(Decimal candExp, Decimal reqExp) {
        if (reqExp == null || reqExp <= 0) {
            return 100.00;
        }
        if (candExp == null || candExp <= 0) {
            return 0.00;
        }

        if (candExp >= reqExp) {
            return 100.00;
        } else if (candExp >= (reqExp - 1.0)) {
            return 75.00;
        } else if (candExp >= (reqExp - 2.0)) {
            return 50.00;
        } else {
            Decimal pct = (candExp / reqExp) * 100.00;
            return Math.max(0.00, pct.setScale(2, System.RoundingMode.HALF_UP));
        }
    }

    /**
     * Evaluates qualification compatibility using only explicit job-relevant academic data.
     */
    private static Decimal evaluateQualification(String candQual, String reqQual) {
        Integer candTier = getEducationTier(candQual);
        Integer reqTier = getEducationTier(reqQual);

        if (candTier >= reqTier) {
            return 100.00;
        } else if (candTier == reqTier - 1) {
            return 60.00;
        } else {
            return 25.00;
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

    /**
     * Evaluates location & work-mode compatibility.
     */
    private static Decimal evaluateLocation(String candLoc, String jobLoc) {
        if (String.isBlank(jobLoc) || String.isBlank(candLoc)) {
            return 50.00;
        }

        String jLower = jobLoc.toLowerCase();
        String cLower = candLoc.toLowerCase();

        // Remote role compatibility
        if (jLower.contains('remote') || cLower.contains('remote')) {
            return 100.00;
        }

        // Direct containment
        if (jLower.contains(cLower) || cLower.contains(jLower)) {
            return 100.00;
        }

        // Shared metro / city keywords
        List<String> metros = new List<String>{
            'san francisco', 'austin', 'seattle', 'new york', 'boston',
            'chicago', 'denver', 'atlanta', 'los angeles', 'san diego', 'mumbai'
        };
        for (String m : metros) {
            if (jLower.contains(m) && cLower.contains(m)) {
                return 100.00;
            }
        }

        // Differing location, non-remote
        return 40.00;
    }

    /**
     * Case-insensitive, delimiter-tolerant token parser.
     * Supports comma (,), semicolon (;), forward slash (/), and newline (\n).
     */
    public static List<String> parseTokens(String input) {
        List<String> tokens = new List<String>();
        if (String.isBlank(input)) {
            return tokens;
        }
        for (String part : input.split('[,;\\n\\/]+')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                tokens.add(trimmed);
            }
        }
        return tokens;
    }

    public static Boolean areSkillsEquivalent(String req, String cand) {
        if (req == cand) return true;

        // AI / ML fine-grained synonym clusters
        if ((req == 'ai' || req == 'artificial intelligence') && (cand == 'ai' || cand == 'artificial intelligence')) return true;
        if ((req == 'ml' || req == 'machine learning') && (cand == 'ml' || cand == 'machine learning')) return true;
        if ((req == 'dl' || req == 'deep learning') && (cand == 'dl' || cand == 'deep learning')) return true;
        if ((req == 'llm' || req == 'llms' || req == 'large language model') && (cand == 'llm' || cand == 'llms' || cand == 'large language model')) return true;
        if ((req == 'nlp' || req == 'natural language processing') && (cand == 'nlp' || cand == 'natural language processing')) return true;
        if ((req == 'transformer' || req == 'transformers') && (cand == 'transformer' || cand == 'transformers')) return true;
        if ((req == 'computer vision' || req == 'cv') && (cand == 'computer vision' || cand == 'cv')) return true;

        // Frontend synonym clusters
        if ((req == 'react' || req == 'react.js' || req == 'reactjs') && (cand == 'react' || cand == 'react.js' || cand == 'reactjs')) return true;
        if ((req == 'next.js' || req == 'nextjs') && (cand == 'next.js' || cand == 'nextjs')) return true;
        if ((req == 'javascript' || req == 'js') && (cand == 'javascript' || cand == 'js')) return true;
        if ((req == 'typescript' || req == 'ts') && (cand == 'typescript' || cand == 'ts')) return true;
        if ((req == 'node' || req == 'node.js' || req == 'nodejs') && (cand == 'node' || cand == 'node.js' || cand == 'nodejs')) return true;

        // Java family
        if (req.startsWith('java') && cand.startsWith('java')) return true;

        // Cloud / DevOps
        if ((req == 'k8s' || req == 'kubernetes') && (cand == 'k8s' || cand == 'kubernetes')) return true;

        // Database
        if ((req == 'postgres' || req == 'postgresql') && (cand == 'postgres' || cand == 'postgresql')) return true;

        return false;
    }

    /**
     * Generates a plain-language, recruiter-friendly explanation that strictly adheres
     * to Ethical AI Guardrails (no protected characteristics, decision-support framing only).
     */
    private static String generateExplanation(Candidate__c cand, Job_Requisition__c job,
                                              Candidate_Job_Match__c matchRec, WeightConfig w,
                                              List<String> matchedSkills, List<String> missingSkills) {
        String candName = cand != null && String.isNotBlank(cand.Candidate_Name__c) ? cand.Candidate_Name__c : 'Candidate';
        String jobTitle = job != null && String.isNotBlank(job.Job_Title__c) ? job.Job_Title__c : 'Role';
        String jobCode = job != null && String.isNotBlank(job.Job_Code__c) ? ' (' + job.Job_Code__c + ')' : '';

        List<String> lines = new List<String>();
        lines.add('Candidate-Job Match Evaluation: ' + candName + ' for ' + jobTitle + jobCode);
        lines.add('Decision-Support Score: ' + matchRec.Overall_Match_Score__c + '% (' + matchRec.Recommendation__c + ')');
        lines.add('');
        lines.add('Factor Breakdown:');
        lines.add('1. Skills (Weight ' + w.skillWeight + '%): ' + matchRec.Skill_Match_Percent__c + '% match (' + matchRec.Skill_Gap_Percent__c + '% gap)');
        lines.add('   - Matched: ' + (matchedSkills.isEmpty() ? 'None' : String.join(matchedSkills, ', ')));
        if (!missingSkills.isEmpty()) {
            lines.add('   - Skill Gap: ' + String.join(missingSkills, ', '));
        }

        String candExp = (cand != null && cand.Years_of_Experience__c != null) ? String.valueOf(cand.Years_of_Experience__c) + ' yrs' : 'Not specified';
        String reqExp = (job != null && job.Experience_Required__c != null) ? String.valueOf(job.Experience_Required__c) + ' yrs' : 'None required';
        lines.add('2. Experience (Weight ' + w.experienceWeight + '%): ' + matchRec.Experience_Match_Percent__c + '% compatibility (Candidate: ' + candExp + ' vs Role: ' + reqExp + ')');

        String candEdu = (cand != null && String.isNotBlank(cand.Highest_Qualification__c)) ? cand.Highest_Qualification__c : 'Not specified';
        String reqEdu = (job != null && String.isNotBlank(job.Minimum_Qualification__c)) ? job.Minimum_Qualification__c : 'Not specified';
        lines.add('3. Qualification (Weight ' + w.qualificationWeight + '%): ' + matchRec.Qualification_Match_Percent__c + '% compatibility (Candidate: ' + candEdu + ' vs Role: ' + reqEdu + ')');

        String candLoc = (cand != null && String.isNotBlank(cand.Location__c)) ? cand.Location__c : 'Not specified';
        String jobLoc = (job != null && String.isNotBlank(job.Location__c)) ? job.Location__c : 'Not specified';
        lines.add('4. Location/Compatibility (Weight ' + w.locationWeight + '%): ' + matchRec.Location_Match_Percent__c + '% compatibility (Candidate: ' + candLoc + ' vs Role: ' + jobLoc + ')');
        lines.add('');
        lines.add('Ethical Decision-Support Guardrail: This match score is an algorithmic recommendation based strictly on explicit job-relevant competencies, experience, education, and location. It does not predict hiring probability and does not factor in age, gender, race, or any protected characteristics. All shortlisting and hiring decisions must be determined by human recruiters.');

        return String.join(lines, '\n');
    }

    /**
     * Sorts Candidate_Job_Match__c records descending by Overall_Match_Score__c.
     */
    private static void sortMatchesDescending(List<Candidate_Job_Match__c> matches) {
        Integer n = matches.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = 0; j < n - i - 1; j++) {
                Decimal score1 = matches[j].Overall_Match_Score__c != null ? matches[j].Overall_Match_Score__c : 0;
                Decimal score2 = matches[j + 1].Overall_Match_Score__c != null ? matches[j + 1].Overall_Match_Score__c : 0;
                if (score1 < score2) {
                    Candidate_Job_Match__c temp = matches[j];
                    matches[j] = matches[j + 1];
                    matches[j + 1] = temp;
                }
            }
        }
    }
}
