public with sharing class RecruitmentSearchCandidatesAction {
    public class Request {
        @InvocableVariable(label='Skills' description='Skills to search for, e.g. Python, machine learning')
        public String skills;

        @InvocableVariable(label='Minimum Experience' description='Minimum years of experience')
        public Decimal minExperience;

        @InvocableVariable(label='Candidate Name' description='Candidate name to search')
        public String candidateName;

        @InvocableVariable(label='Status' description='Candidate status filter')
        public String status;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Formatted list of candidate records')
        public String result;

        @InvocableVariable(label='Total Found' description='Total matching candidates')
        public Integer totalFound;
    }

    @InvocableMethod(label='Search Candidate Directory' description='Searches candidate directory records by keyword or status. Do not use when evaluating match scores, ranking candidates, or comparing candidates.')
    public static List<Response> searchCandidates(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String nameQuery = req != null && String.isNotBlank(req.candidateName) ? req.candidateName.trim().toLowerCase() : null;
            String skillsQuery = req != null && String.isNotBlank(req.skills) ? req.skills.trim().toLowerCase() : null;
            Decimal minExp = req != null ? req.minExperience : null;
            String statusQuery = req != null && String.isNotBlank(req.status) ? req.status.trim().toLowerCase() : null;

            List<Candidate__c> allCandidates = [
                SELECT Id, Candidate_Name__c, Email__c, Phone__c, Location__c, Highest_Qualification__c,
                       University__c, Graduation_Year__c, Years_of_Experience__c, Skills__c, Candidate_Status__c
                FROM Candidate__c
                ORDER BY Candidate_Name__c ASC
            ];

            List<Candidate__c> matched = new List<Candidate__c>();
            for (Candidate__c c : allCandidates) {
                Boolean matches = true;

                // Name filter
                if (nameQuery != null) {
                    if (c.Candidate_Name__c == null || !c.Candidate_Name__c.toLowerCase().contains(nameQuery)) {
                        matches = false;
                    }
                }

                // Status filter
                if (statusQuery != null) {
                    if (c.Candidate_Status__c == null || !c.Candidate_Status__c.toLowerCase().contains(statusQuery)) {
                        matches = false;
                    }
                }

                // Minimum experience filter
                if (minExp != null) {
                    if (c.Years_of_Experience__c == null || c.Years_of_Experience__c < minExp) {
                        matches = false;
                    }
                }

                // Skills filter (handles multi-skill keywords, stop words, and AI/ML synonyms)
                if (skillsQuery != null) {
                    if (String.isBlank(c.Skills__c)) {
                        matches = false;
                    } else {
                        String candSkills = c.Skills__c.toLowerCase();
                        // Normalize query and strip common stop words
                        String cleanQuery = skillsQuery.replaceAll('(?i)\\b(and|with|skills|skill|candidates|candidate|in|the|of)\\b', ' ');
                        List<String> rawTokens = cleanQuery.split('[,\\s]+');
                        Set<String> cleanKeywords = new Set<String>();
                        for (String t : rawTokens) {
                            String trimmed = t.trim();
                            if (trimmed.length() >= 2) {
                                cleanKeywords.add(trimmed);
                            }
                        }

                        // Check keywords (requires at least 1 keyword match)
                        Integer matchedTokenCount = 0;
                        for (String kw : cleanKeywords) {
                            Boolean tokenMatch = false;
                            if (candSkills.contains(kw)) {
                                tokenMatch = true;
                            } else if (kw == 'machine' || kw == 'learning' || kw == 'ml' || kw == 'ai') {
                                // Match AI / Machine Learning related terms
                                if (candSkills.contains('learning') || candSkills.contains('pytorch') ||
                                    candSkills.contains('nlp') || candSkills.contains('llm') ||
                                    candSkills.contains('tensorflow') || candSkills.contains('vision')) {
                                    tokenMatch = true;
                                }
                            }

                            if (tokenMatch) {
                                matchedTokenCount++;
                            }
                        }

                        if (matchedTokenCount == 0) {
                            matches = false;
                        }
                    }
                }

                if (matches) {
                    matched.add(c);
                }
            }

            res.totalFound = matched.size();
            if (matched.isEmpty()) {
                if (nameQuery != null) {
                    res.result = 'No candidate found with name "' + req.candidateName + '" in Salesforce.';
                } else if (skillsQuery != null) {
                    res.result = 'No candidates found matching skills: "' + req.skills + '".';
                } else {
                    res.result = 'No candidates found matching the specified criteria.';
                }
            } else {
                List<String> lines = new List<String>();
                lines.add('Found ' + matched.size() + ' matching candidate(s):');
                Integer i = 1;
                for (Candidate__c c : matched) {
                    lines.add(i + '. **' + c.Candidate_Name__c + '**');
                    lines.add('   - Email: ' + c.Email__c + ' | Phone: ' + (c.Phone__c != null ? c.Phone__c : 'N/A') + ' | Location: ' + (c.Location__c != null ? c.Location__c : 'N/A'));
                    lines.add('   - Experience: ' + (c.Years_of_Experience__c != null ? String.valueOf(c.Years_of_Experience__c) : '0') + ' yrs | Status: ' + c.Candidate_Status__c);
                    lines.add('   - Education: ' + (c.Highest_Qualification__c != null ? c.Highest_Qualification__c : 'N/A') + ' (' + (c.University__c != null ? c.University__c : 'N/A') + ')');
                    if (String.isNotBlank(c.Skills__c)) {
                        lines.add('   - Skills: ' + c.Skills__c);
                    }
                    i++;
                }
                res.result = String.join(lines, '\n');
            }
            responses.add(res);
        }
        return responses;
    }
}
