/**
 * @description Controller for Phase 4B: Recruitment Intelligence & Operational Insights Dashboard.
 * Aggregates live organization-level recruitment health, job coverage, candidate match metrics,
 * skill gaps, and interview bottlenecks directly from existing Salesforce objects and
 * Candidate_Job_Match__c intelligence without duplicating scoring algorithms.
 */
public with sharing class RecruitmentIntelligenceController {

    public class DashboardData {
        @AuraEnabled public KpiSummary kpis { get; set; }
        @AuraEnabled public List<PipelineStageMetric> pipelineStages { get; set; }
        @AuraEnabled public List<JobHealthRow> jobHealthTable { get; set; }
        @AuraEnabled public MatchCoverageSummary matchCoverage { get; set; }
        @AuraEnabled public List<SkillGapMetric> skillGaps { get; set; }
        @AuraEnabled public InterviewBottleneckSummary interviewBottlenecks { get; set; }
        @AuraEnabled public List<AttentionItem> recruiterAttentionItems { get; set; }
        @AuraEnabled public FilterOptions filterOptions { get; set; }
    }

    public class KpiSummary {
        @AuraEnabled public Integer openJobs { get; set; }
        @AuraEnabled public Integer totalCandidates { get; set; }
        @AuraEnabled public Integer totalApplications { get; set; }
        @AuraEnabled public Integer shortlistedApplications { get; set; }
        @AuraEnabled public Integer interviewedApplications { get; set; }
        @AuraEnabled public Integer selectedCandidates { get; set; }
        @AuraEnabled public Integer upcomingInterviews { get; set; }
        @AuraEnabled public Decimal averageCandidateMatchScore { get; set; }
    }

    public class PipelineStageMetric {
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public String colorClass { get; set; }
    }

    public class JobHealthRow {
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String jobCode { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal requiredHeadcount { get; set; }
        @AuraEnabled public Integer applicationCount { get; set; }
        @AuraEnabled public Integer candidateCount { get; set; }
        @AuraEnabled public Decimal averageMatchScore { get; set; }
        @AuraEnabled public Decimal highestMatchScore { get; set; }
        @AuraEnabled public String highestMatchCandidateName { get; set; }
        @AuraEnabled public Integer strongMatchCount { get; set; } // >= 80%
        @AuraEnabled public Integer goodMatchCount { get; set; }   // >= 65%
        @AuraEnabled public Integer moderateMatchCount { get; set; } // >= 50%
        @AuraEnabled public Integer lowMatchCount { get; set; }      // < 50%
        @AuraEnabled public Boolean hasEvaluations { get; set; }
        @AuraEnabled public String matchStatusText { get; set; }
    }

    public class MatchCoverageSummary {
        @AuraEnabled public Decimal orgAverageMatchScore { get; set; }
        @AuraEnabled public Integer totalEvaluatedMatches { get; set; }
        @AuraEnabled public Integer totalStrongMatches { get; set; } // >= 80%
        @AuraEnabled public Integer totalGoodMatches { get; set; }   // >= 65%
        @AuraEnabled public Integer totalModerateMatches { get; set; } // >= 50%
        @AuraEnabled public Integer totalLowMatches { get; set; }      // < 50%
        @AuraEnabled public List<JobCoverageItem> strongestJobs { get; set; }
        @AuraEnabled public List<JobCoverageItem> weakestJobs { get; set; }
    }

    public class JobCoverageItem {
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public Decimal averageScore { get; set; }
        @AuraEnabled public Decimal highestScore { get; set; }
        @AuraEnabled public Integer goodOrHigherCount { get; set; } // >= 65%
        @AuraEnabled public Integer totalEvaluated { get; set; }
    }

    public class SkillGapMetric {
        @AuraEnabled public String skillName { get; set; }
        @AuraEnabled public Integer gapCount { get; set; }
        @AuraEnabled public List<String> relevantJobTitles { get; set; }
        @AuraEnabled public List<Id> relevantJobIds { get; set; }
    }

    public class InterviewBottleneckSummary {
        @AuraEnabled public Integer upcomingCount { get; set; }
        @AuraEnabled public Integer completedCount { get; set; }
        @AuraEnabled public Integer scheduledCount { get; set; }
        @AuraEnabled public Integer attentionCount { get; set; } // Overdue scheduled
        @AuraEnabled public Integer interviewStageApplications { get; set; }
        @AuraEnabled public List<InterviewItem> upcomingInterviewsList { get; set; }
        @AuraEnabled public List<InterviewItem> attentionInterviewsList { get; set; }
        @AuraEnabled public List<JobInterviewActivity> jobsWithActivity { get; set; }
    }

    public class InterviewItem {
        @AuraEnabled public Id interviewId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public Datetime interviewDate { get; set; }
        @AuraEnabled public String interviewStatus { get; set; }
        @AuraEnabled public String interviewRound { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
    }

    public class JobInterviewActivity {
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String jobTitle { get; set; }
        @AuraEnabled public Integer scheduledCount { get; set; }
        @AuraEnabled public Integer completedCount { get; set; }
    }

    public class AttentionItem {
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String severity { get; set; } // High, Medium, Info
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Id relatedRecordId { get; set; }
        @AuraEnabled public String targetComponent { get; set; }
    }

    public class FilterOptions {
        @AuraEnabled public List<SelectOptionDTO> jobs { get; set; }
        @AuraEnabled public List<SelectOptionDTO> departments { get; set; }
        @AuraEnabled public List<SelectOptionDTO> jobStatuses { get; set; }
        @AuraEnabled public List<SelectOptionDTO> applicationStatuses { get; set; }
    }

    public class SelectOptionDTO {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public SelectOptionDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Main entry point for retrieving the Recruitment Intelligence Dashboard data.
     * Supports dynamic filtering across Job Requisition, Department, Job Status, Application Status,
     * and Candidate Match Recommendation tier.
     */
    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboardData(
        String jobId,
        String department,
        String jobStatus,
        String appStatus,
        String recommendationTier
    ) {
        DashboardData data = new DashboardData();
        data.kpis = new KpiSummary();
        data.pipelineStages = new List<PipelineStageMetric>();
        data.jobHealthTable = new List<JobHealthRow>();
        data.matchCoverage = new MatchCoverageSummary();
        data.skillGaps = new List<SkillGapMetric>();
        data.interviewBottlenecks = new InterviewBottleneckSummary();
        data.recruiterAttentionItems = new List<AttentionItem>();
        data.filterOptions = buildFilterOptions();

        // 1. Query Job Requisitions with filters
        String jobQuery = 'SELECT Id, Name, Job_Title__c, Job_Code__c, Department__c, Location__c, Status__c, Number_of_Positions__c FROM Job_Requisition__c WHERE Id != null';
        List<String> jobFilters = new List<String>();
        if (String.isNotBlank(jobId)) {
            jobFilters.add('Id = :jobId');
        }
        if (String.isNotBlank(department)) {
            jobFilters.add('Department__c = :department');
        }
        if (String.isNotBlank(jobStatus)) {
            jobFilters.add('Status__c = :jobStatus');
        }
        if (!jobFilters.isEmpty()) {
            jobQuery += ' AND ' + String.join(jobFilters, ' AND ');
        }
        jobQuery += ' ORDER BY Job_Title__c ASC';
        List<Job_Requisition__c> targetJobs = Database.query(jobQuery);

        Set<Id> targetJobIds = new Map<Id, Job_Requisition__c>(targetJobs).keySet();

        // 2. Query Applications with filters
        String appQuery = 'SELECT Id, Application_Number__c, Application_Status__c, Application_Date__c, Candidate__c, Candidate__r.Candidate_Name__c, Job_Requisition__c, Job_Requisition__r.Job_Title__c FROM Job_Application__c WHERE Id != null';
        if (!targetJobIds.isEmpty()) {
            appQuery += ' AND Job_Requisition__c IN :targetJobIds';
        } else if (String.isNotBlank(jobId) || String.isNotBlank(department) || String.isNotBlank(jobStatus)) {
            // Filter resulted in 0 jobs -> 0 apps
            appQuery += ' AND Id = null';
        }
        if (String.isNotBlank(appStatus)) {
            appQuery += ' AND Application_Status__c = :appStatus';
        }
        List<Job_Application__c> targetApps = Database.query(appQuery);

        // 3. Query Candidate_Job_Match__c intelligence with filters
        String matchQuery = 'SELECT Id, Candidate__c, Candidate__r.Candidate_Name__c, Job_Requisition__c, Job_Requisition__r.Job_Title__c, Overall_Match_Score__c, Recommendation__c, Missing_Skills__c, Matched_Skills__c FROM Candidate_Job_Match__c WHERE Id != null';
        if (!targetJobIds.isEmpty()) {
            matchQuery += ' AND Job_Requisition__c IN :targetJobIds';
        } else if (String.isNotBlank(jobId) || String.isNotBlank(department) || String.isNotBlank(jobStatus)) {
            matchQuery += ' AND Id = null';
        }
        if (String.isNotBlank(recommendationTier)) {
            matchQuery += ' AND Recommendation__c = :recommendationTier';
        }
        matchQuery += ' ORDER BY Overall_Match_Score__c DESC';
        List<Candidate_Job_Match__c> targetMatches = Database.query(matchQuery);

        // 4. Query Interviews (respecting Datetime.now() semantics)
        Datetime nowTime = Datetime.now();
        String interviewQuery = 'SELECT Id, Name, Interview_Date__c, Interview_Status__c, Interview_Type__c, Job_Application__c, Job_Application__r.Candidate__c, Job_Application__r.Candidate__r.Candidate_Name__c, Job_Application__r.Job_Requisition__c, Job_Application__r.Job_Requisition__r.Job_Title__c FROM Interview__c WHERE Id != null';
        if (!targetJobIds.isEmpty()) {
            interviewQuery += ' AND Job_Application__r.Job_Requisition__c IN :targetJobIds';
        } else if (String.isNotBlank(jobId) || String.isNotBlank(department) || String.isNotBlank(jobStatus)) {
            interviewQuery += ' AND Id = null';
        }
        interviewQuery += ' ORDER BY Interview_Date__c ASC';
        List<Interview__c> targetInterviews = Database.query(interviewQuery);

        // 5. Query Candidates (overall count & selected)
        List<Candidate__c> allCandidates = [
            SELECT Id, Candidate_Name__c, Candidate_Status__c FROM Candidate__c
        ];

        // 6. Build Core KPI Section
        Integer openJobsCount = 0;
        for (Job_Requisition__c j : targetJobs) {
            if ('Open'.equalsIgnoreCase(j.Status__c)) {
                openJobsCount++;
            }
        }
        data.kpis.openJobs = openJobsCount;
        data.kpis.totalCandidates = allCandidates.size();
        data.kpis.totalApplications = targetApps.size();

        Integer shortlistedCount = 0;
        Integer interviewedCount = 0;
        for (Job_Application__c app : targetApps) {
            if ('Shortlisted'.equalsIgnoreCase(app.Application_Status__c)) {
                shortlistedCount++;
            } else if ('Interviewed'.equalsIgnoreCase(app.Application_Status__c)) {
                interviewedCount++;
            }
        }
        data.kpis.shortlistedApplications = shortlistedCount;
        data.kpis.interviewedApplications = interviewedCount;

        Integer selectedCandCount = 0;
        for (Candidate__c c : allCandidates) {
            if ('Selected'.equalsIgnoreCase(c.Candidate_Status__c)) {
                selectedCandCount++;
            }
        }
        data.kpis.selectedCandidates = selectedCandCount;

        Integer upcomingIntCount = 0;
        for (Interview__c iv : targetInterviews) {
            if (iv.Interview_Date__c != null && iv.Interview_Date__c >= nowTime && 'Scheduled'.equalsIgnoreCase(iv.Interview_Status__c)) {
                upcomingIntCount++;
            }
        }
        data.kpis.upcomingInterviews = upcomingIntCount;

        Decimal totalMatchScoreSum = 0;
        for (Candidate_Job_Match__c m : targetMatches) {
            if (m.Overall_Match_Score__c != null) {
                totalMatchScoreSum += m.Overall_Match_Score__c;
            }
        }
        data.kpis.averageCandidateMatchScore = !targetMatches.isEmpty()
            ? (totalMatchScoreSum / targetMatches.size()).setScale(2)
            : 0.00;

        // 7. Build Recruitment Pipeline Stage Distribution
        Map<String, Integer> stageCounts = new Map<String, Integer>{
            'Applied' => 0,
            'Under Review' => 0,
            'Shortlisted' => 0,
            'Interview Scheduled' => 0,
            'Interviewed' => 0,
            'Selected' => 0
        };
        for (Job_Application__c app : targetApps) {
            String st = app.Application_Status__c;
            if (st != null && stageCounts.containsKey(st)) {
                stageCounts.put(st, stageCounts.get(st) + 1);
            }
        }
        List<String> orderedStages = new List<String>{
            'Applied', 'Under Review', 'Shortlisted', 'Interview Scheduled', 'Interviewed', 'Selected'
        };
        Integer totalAppsForPipeline = targetApps.size();
        for (String st : orderedStages) {
            PipelineStageMetric psm = new PipelineStageMetric();
            psm.stageName = st;
            psm.count = stageCounts.get(st);
            psm.percentage = totalAppsForPipeline > 0
                ? ((Decimal.valueOf(psm.count) / Decimal.valueOf(totalAppsForPipeline)) * 100).setScale(1)
                : 0.0;
            if (st == 'Applied') psm.colorClass = 'stage-applied';
            else if (st == 'Under Review') psm.colorClass = 'stage-review';
            else if (st == 'Shortlisted') psm.colorClass = 'stage-shortlisted';
            else if (st == 'Interview Scheduled') psm.colorClass = 'stage-scheduled';
            else if (st == 'Interviewed') psm.colorClass = 'stage-interviewed';
            else if (st == 'Selected') psm.colorClass = 'stage-selected';
            data.pipelineStages.add(psm);
        }

        // 8. Build Job Health Table & Match Coverage
        Map<Id, List<Job_Application__c>> appsByJob = new Map<Id, List<Job_Application__c>>();
        for (Job_Application__c app : targetApps) {
            if (app.Job_Requisition__c != null) {
                if (!appsByJob.containsKey(app.Job_Requisition__c)) {
                    appsByJob.put(app.Job_Requisition__c, new List<Job_Application__c>());
                }
                appsByJob.get(app.Job_Requisition__c).add(app);
            }
        }

        Map<Id, List<Candidate_Job_Match__c>> matchesByJob = new Map<Id, List<Candidate_Job_Match__c>>();
        for (Candidate_Job_Match__c m : targetMatches) {
            if (m.Job_Requisition__c != null) {
                if (!matchesByJob.containsKey(m.Job_Requisition__c)) {
                    matchesByJob.put(m.Job_Requisition__c, new List<Candidate_Job_Match__c>());
                }
                matchesByJob.get(m.Job_Requisition__c).add(m);
            }
        }

        List<JobCoverageItem> coverageItems = new List<JobCoverageItem>();
        Integer totalStrong = 0;
        Integer totalGood = 0;
        Integer totalModerate = 0;
        Integer totalLow = 0;

        for (Job_Requisition__c j : targetJobs) {
            JobHealthRow row = new JobHealthRow();
            row.jobId = j.Id;
            row.jobTitle = j.Job_Title__c;
            row.jobCode = j.Job_Code__c;
            row.department = j.Department__c;
            row.status = j.Status__c;
            row.requiredHeadcount = j.Number_of_Positions__c != null ? j.Number_of_Positions__c : 0;
            
            List<Job_Application__c> jApps = appsByJob.containsKey(j.Id) ? appsByJob.get(j.Id) : new List<Job_Application__c>();
            row.applicationCount = jApps.size();

            Set<Id> uniqueCandidates = new Set<Id>();
            for (Job_Application__c a : jApps) {
                if (a.Candidate__c != null) uniqueCandidates.add(a.Candidate__c);
            }

            List<Candidate_Job_Match__c> jMatches = matchesByJob.containsKey(j.Id) ? matchesByJob.get(j.Id) : new List<Candidate_Job_Match__c>();
            for (Candidate_Job_Match__c m : jMatches) {
                if (m.Candidate__c != null) uniqueCandidates.add(m.Candidate__c);
            }
            row.candidateCount = uniqueCandidates.size();

            if (!jMatches.isEmpty()) {
                row.hasEvaluations = true;
                row.matchStatusText = 'Evaluated';

                Decimal sumScore = 0;
                Decimal maxScore = 0;
                String topCandidate = 'None';
                Integer sCount = 0;
                Integer gCount = 0;
                Integer mCount = 0;
                Integer lCount = 0;

                for (Candidate_Job_Match__c m : jMatches) {
                    Decimal score = m.Overall_Match_Score__c != null ? m.Overall_Match_Score__c : 0.00;
                    sumScore += score;
                    if (score > maxScore) {
                        maxScore = score;
                        if (m.Candidate__r != null && String.isNotBlank(m.Candidate__r.Candidate_Name__c)) {
                            topCandidate = m.Candidate__r.Candidate_Name__c;
                        }
                    }

                    if (score >= 80.00) {
                        sCount++;
                        totalStrong++;
                    } else if (score >= 65.00) {
                        gCount++;
                        totalGood++;
                    } else if (score >= 50.00) {
                        mCount++;
                        totalModerate++;
                    } else {
                        lCount++;
                        totalLow++;
                    }
                }

                row.averageMatchScore = (sumScore / jMatches.size()).setScale(2);
                row.highestMatchScore = maxScore.setScale(2);
                row.highestMatchCandidateName = topCandidate;
                row.strongMatchCount = sCount;
                row.goodMatchCount = gCount;
                row.moderateMatchCount = mCount;
                row.lowMatchCount = lCount;

                JobCoverageItem cov = new JobCoverageItem();
                cov.jobId = j.Id;
                cov.jobTitle = j.Job_Title__c;
                cov.department = j.Department__c;
                cov.averageScore = row.averageMatchScore;
                cov.highestScore = row.highestMatchScore;
                cov.goodOrHigherCount = sCount + gCount;
                cov.totalEvaluated = jMatches.size();
                coverageItems.add(cov);
            } else {
                row.hasEvaluations = false;
                row.matchStatusText = 'Match evaluation unavailable';
                row.averageMatchScore = 0.00;
                row.highestMatchScore = 0.00;
                row.highestMatchCandidateName = 'None';
                row.strongMatchCount = 0;
                row.goodMatchCount = 0;
                row.moderateMatchCount = 0;
                row.lowMatchCount = 0;
            }

            data.jobHealthTable.add(row);
        }

        // 9. Match Coverage Summary
        data.matchCoverage.totalEvaluatedMatches = targetMatches.size();
        data.matchCoverage.totalStrongMatches = totalStrong;
        data.matchCoverage.totalGoodMatches = totalGood;
        data.matchCoverage.totalModerateMatches = totalModerate;
        data.matchCoverage.totalLowMatches = totalLow;
        data.matchCoverage.orgAverageMatchScore = data.kpis.averageCandidateMatchScore;

        // Sort coverage items to find strongest and weakest jobs
        List<JobCoverageItem> sortedStrong = new List<JobCoverageItem>(coverageItems);
        sortCoverageItems(sortedStrong, false); // highest first
        data.matchCoverage.strongestJobs = new List<JobCoverageItem>();
        for (Integer i = 0; i < Math.min(3, sortedStrong.size()); i++) {
            data.matchCoverage.strongestJobs.add(sortedStrong[i]);
        }

        List<JobCoverageItem> sortedWeak = new List<JobCoverageItem>(coverageItems);
        sortCoverageItems(sortedWeak, true); // lowest first
        data.matchCoverage.weakestJobs = new List<JobCoverageItem>();
        for (Integer i = 0; i < Math.min(3, sortedWeak.size()); i++) {
            data.matchCoverage.weakestJobs.add(sortedWeak[i]);
        }

        // 10. Skill Gap Intelligence (from Candidate_Job_Match__c.Missing_Skills__c)
        Map<String, SkillGapDataHolder> skillMap = new Map<String, SkillGapDataHolder>();
        for (Candidate_Job_Match__c m : targetMatches) {
            if (String.isNotBlank(m.Missing_Skills__c)) {
                List<String> rawSkills = m.Missing_Skills__c.split(',');
                for (String rs : rawSkills) {
                    String cleanSkill = rs.trim();
                    if (cleanSkill.length() >= 2) {
                        String lookupKey = cleanSkill.toLowerCase();
                        if (!skillMap.containsKey(lookupKey)) {
                            skillMap.put(lookupKey, new SkillGapDataHolder(cleanSkill));
                        }
                        SkillGapDataHolder holder = skillMap.get(lookupKey);
                        holder.gapCount++;
                        if (m.Job_Requisition__r != null && String.isNotBlank(m.Job_Requisition__r.Job_Title__c)) {
                            holder.jobTitles.add(m.Job_Requisition__r.Job_Title__c);
                            holder.jobIds.add(m.Job_Requisition__c);
                        }
                    }
                }
            }
        }

        List<SkillGapDataHolder> holderList = skillMap.values();
        sortSkillGaps(holderList);
        for (Integer i = 0; i < Math.min(10, holderList.size()); i++) {
            SkillGapDataHolder h = holderList[i];
            SkillGapMetric sgm = new SkillGapMetric();
            sgm.skillName = h.originalName;
            sgm.gapCount = h.gapCount;
            sgm.relevantJobTitles = new List<String>(h.jobTitles);
            sgm.relevantJobIds = new List<Id>(h.jobIds);
            data.skillGaps.add(sgm);
        }

        // 11. Interview Bottlenecks Section
        Integer compCount = 0;
        Integer schedCount = 0;
        Integer attnCount = 0;
        List<InterviewItem> upcomingList = new List<InterviewItem>();
        List<InterviewItem> attnList = new List<InterviewItem>();
        Map<Id, JobInterviewActivity> jobActivityMap = new Map<Id, JobInterviewActivity>();

        for (Interview__c iv : targetInterviews) {
            String st = iv.Interview_Status__c;
            Boolean isUpcoming = (iv.Interview_Date__c != null && iv.Interview_Date__c >= nowTime && 'Scheduled'.equalsIgnoreCase(st));
            Boolean isOverdue = (iv.Interview_Date__c != null && iv.Interview_Date__c < nowTime && 'Scheduled'.equalsIgnoreCase(st));

            if ('Completed'.equalsIgnoreCase(st)) {
                compCount++;
            } else if ('Scheduled'.equalsIgnoreCase(st)) {
                schedCount++;
            }

            if (isOverdue) {
                attnCount++;
                attnList.add(buildInterviewItem(iv, true));
            }

            if (isUpcoming) {
                upcomingList.add(buildInterviewItem(iv, false));
            }

            // Track activity per job
            Id jId = iv.Job_Application__r != null ? iv.Job_Application__r.Job_Requisition__c : null;
            if (jId != null) {
                if (!jobActivityMap.containsKey(jId)) {
                    JobInterviewActivity act = new JobInterviewActivity();
                    act.jobId = jId;
                    act.jobTitle = iv.Job_Application__r.Job_Requisition__r != null ? iv.Job_Application__r.Job_Requisition__r.Job_Title__c : 'Job';
                    act.scheduledCount = 0;
                    act.completedCount = 0;
                    jobActivityMap.put(jId, act);
                }
                if ('Scheduled'.equalsIgnoreCase(st)) {
                    jobActivityMap.get(jId).scheduledCount++;
                } else if ('Completed'.equalsIgnoreCase(st)) {
                    jobActivityMap.get(jId).completedCount++;
                }
            }
        }

        data.interviewBottlenecks.upcomingCount = upcomingIntCount;
        data.interviewBottlenecks.completedCount = compCount;
        data.interviewBottlenecks.scheduledCount = schedCount;
        data.interviewBottlenecks.attentionCount = attnCount;
        data.interviewBottlenecks.interviewStageApplications = stageCounts.get('Interview Scheduled') + stageCounts.get('Interviewed');
        data.interviewBottlenecks.upcomingInterviewsList = upcomingList;
        data.interviewBottlenecks.attentionInterviewsList = attnList;
        data.interviewBottlenecks.jobsWithActivity = jobActivityMap.values();

        // 12. Recruiter Attention Section (Strictly data-derived, no predictive phrasing)
        generateRecruiterAttention(data, targetJobs, appsByJob, matchesByJob, attnList);

        return data;
    }

    /**
     * @description Generates objective, evidence-based attention items with 'Requires recruiter review' phrasing.
     */
    private static void generateRecruiterAttention(
        DashboardData data,
        List<Job_Requisition__c> jobs,
        Map<Id, List<Job_Application__c>> appsByJob,
        Map<Id, List<Candidate_Job_Match__c>> matchesByJob,
        List<InterviewItem> overdueInterviews
    ) {
        List<AttentionItem> items = new List<AttentionItem>();

        // Overdue interviews
        for (InterviewItem iv : overdueInterviews) {
            AttentionItem item = new AttentionItem();
            item.category = 'Interviews';
            item.severity = 'High';
            item.title = 'Overdue scheduled interview: ' + iv.candidateName;
            item.description = 'Interview for ' + iv.candidateName + ' (' + iv.jobTitle + ') was scheduled for ' +
                iv.interviewDate.format('MMM dd, yyyy HH:mm') + ' and is past due. Requires recruiter review.';
            item.relatedRecordId = iv.interviewId;
            item.targetComponent = 'Interview';
            items.add(item);
        }

        // Job coverage and match health
        for (Job_Requisition__c j : jobs) {
            Decimal headcount = j.Number_of_Positions__c != null ? j.Number_of_Positions__c : 0;
            List<Job_Application__c> jApps = appsByJob.containsKey(j.Id) ? appsByJob.get(j.Id) : new List<Job_Application__c>();
            List<Candidate_Job_Match__c> jMatches = matchesByJob.containsKey(j.Id) ? matchesByJob.get(j.Id) : new List<Candidate_Job_Match__c>();

            // Observation: Open job with no match evaluations
            if ('Open'.equalsIgnoreCase(j.Status__c) && jMatches.isEmpty()) {
                AttentionItem item = new AttentionItem();
                item.category = 'Match Health';
                item.severity = 'Medium';
                item.title = 'Missing match evaluations for ' + j.Job_Title__c;
                item.description = j.Job_Title__c + ' has no candidate match evaluations calculated. Requires recruiter review.';
                item.relatedRecordId = j.Id;
                item.targetComponent = 'Match';
                items.add(item);
                continue;
            }

            // Count strong & good matches
            Integer strongAndGoodCount = 0;
            Decimal sumScore = 0;
            for (Candidate_Job_Match__c m : jMatches) {
                Decimal sc = m.Overall_Match_Score__c != null ? m.Overall_Match_Score__c : 0;
                sumScore += sc;
                if (sc >= 65.00) {
                    strongAndGoodCount++;
                }
            }
            Decimal avgScore = !jMatches.isEmpty() ? (sumScore / jMatches.size()).setScale(1) : 0;

            // Observation: Required headcount vs low good/strong candidate count
            if ('Open'.equalsIgnoreCase(j.Status__c) && headcount >= 2 && strongAndGoodCount <= 1) {
                AttentionItem item = new AttentionItem();
                item.category = 'Candidate Coverage';
                item.severity = 'High';
                item.title = 'Low strong candidate coverage for ' + j.Job_Title__c;
                item.description = j.Job_Title__c + ' has ' + headcount.intValue() + ' open positions, but only ' +
                    strongAndGoodCount + ' candidate(s) evaluated with >= 65% match score. Requires recruiter review.';
                item.relatedRecordId = j.Id;
                item.targetComponent = 'Compare';
                items.add(item);
            }

            // Observation: Average score below benchmark
            if ('Open'.equalsIgnoreCase(j.Status__c) && avgScore > 0 && avgScore < 45.0) {
                AttentionItem item = new AttentionItem();
                item.category = 'Match Health';
                item.severity = 'Medium';
                item.title = 'Low average candidate match score for ' + j.Job_Title__c;
                item.description = j.Job_Title__c + ' candidate pool has an average match score of ' +
                    avgScore + '%, below the moderate benchmark. Requires recruiter review.';
                item.relatedRecordId = j.Id;
                item.targetComponent = 'Match';
                items.add(item);
            }

            // Observation: Screening backlog (applications concentrated in Applied / Under Review)
            if (jApps.size() >= 3) {
                Integer pendingScreening = 0;
                for (Job_Application__c a : jApps) {
                    if ('Applied'.equalsIgnoreCase(a.Application_Status__c) || 'Under Review'.equalsIgnoreCase(a.Application_Status__c)) {
                        pendingScreening++;
                    }
                }
                Decimal pendingRatio = (Decimal.valueOf(pendingScreening) / Decimal.valueOf(jApps.size())) * 100;
                if (pendingRatio >= 60.0) {
                    AttentionItem item = new AttentionItem();
                    item.category = 'Pipeline';
                    item.severity = 'Medium';
                    item.title = 'Screening concentration for ' + j.Job_Title__c;
                    item.description = j.Job_Title__c + ' has ' + pendingScreening + ' of ' + jApps.size() +
                        ' applications (' + pendingRatio.setScale(0) + '%) awaiting review or shortlisting. Requires recruiter review.';
                    item.relatedRecordId = j.Id;
                    item.targetComponent = 'Job';
                    items.add(item);
                }
            }

            // Observation: High headcount but 0 applications
            if ('Open'.equalsIgnoreCase(j.Status__c) && headcount >= 3 && jApps.isEmpty()) {
                AttentionItem item = new AttentionItem();
                item.category = 'Pipeline';
                item.severity = 'Info';
                item.title = 'Zero applications received for ' + j.Job_Title__c;
                item.description = j.Job_Title__c + ' has ' + headcount.intValue() +
                    ' open positions but 0 applications received to date. Requires recruiter review.';
                item.relatedRecordId = j.Id;
                item.targetComponent = 'Job';
                items.add(item);
            }
        }

        data.recruiterAttentionItems = items;
    }

    private static InterviewItem buildInterviewItem(Interview__c iv, Boolean isOverdue) {
        InterviewItem item = new InterviewItem();
        item.interviewId = iv.Id;
        item.interviewDate = iv.Interview_Date__c;
        item.interviewStatus = iv.Interview_Status__c;
        item.interviewRound = iv.Interview_Type__c;
        item.isOverdue = isOverdue;
        if (iv.Job_Application__r != null) {
            item.jobId = iv.Job_Application__r.Job_Requisition__c;
            if (iv.Job_Application__r.Job_Requisition__r != null) {
                item.jobTitle = iv.Job_Application__r.Job_Requisition__r.Job_Title__c;
            }
            if (iv.Job_Application__r.Candidate__r != null) {
                item.candidateName = iv.Job_Application__r.Candidate__r.Candidate_Name__c;
                item.candidateId = iv.Job_Application__r.Candidate__c;
            }
        }
        return item;
    }

    private static FilterOptions buildFilterOptions() {
        FilterOptions opt = new FilterOptions();
        opt.jobs = new List<SelectOptionDTO>{ new SelectOptionDTO('All Jobs', '') };
        opt.departments = new List<SelectOptionDTO>{ new SelectOptionDTO('All Departments', '') };
        opt.jobStatuses = new List<SelectOptionDTO>{
            new SelectOptionDTO('All Job Statuses', ''),
            new SelectOptionDTO('Open', 'Open'),
            new SelectOptionDTO('Closed', 'Closed')
        };
        opt.applicationStatuses = new List<SelectOptionDTO>{
            new SelectOptionDTO('All Application Statuses', ''),
            new SelectOptionDTO('Applied', 'Applied'),
            new SelectOptionDTO('Under Review', 'Under Review'),
            new SelectOptionDTO('Shortlisted', 'Shortlisted'),
            new SelectOptionDTO('Interview Scheduled', 'Interview Scheduled'),
            new SelectOptionDTO('Interviewed', 'Interviewed'),
            new SelectOptionDTO('Selected', 'Selected')
        };

        Set<String> depts = new Set<String>();
        for (Job_Requisition__c j : [
            SELECT Id, Job_Title__c, Job_Code__c, Department__c FROM Job_Requisition__c ORDER BY Job_Title__c ASC
        ]) {
            String label = j.Job_Title__c + (String.isNotBlank(j.Job_Code__c) ? ' (' + j.Job_Code__c + ')' : '');
            opt.jobs.add(new SelectOptionDTO(label, j.Id));
            if (String.isNotBlank(j.Department__c)) {
                depts.add(j.Department__c);
            }
        }
        List<String> sortedDepts = new List<String>(depts);
        sortedDepts.sort();
        for (String d : sortedDepts) {
            opt.departments.add(new SelectOptionDTO(d, d));
        }

        return opt;
    }

    // Helper sorting routines
    private class SkillGapDataHolder {
        public String originalName;
        public Integer gapCount;
        public Set<String> jobTitles;
        public Set<Id> jobIds;

        public SkillGapDataHolder(String originalName) {
            this.originalName = originalName;
            this.gapCount = 0;
            this.jobTitles = new Set<String>();
            this.jobIds = new Set<Id>();
        }
    }

    private static void sortSkillGaps(List<SkillGapDataHolder> items) {
        Integer n = items.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = 0; j < n - i - 1; j++) {
                if (items[j].gapCount < items[j + 1].gapCount) {
                    SkillGapDataHolder temp = items[j];
                    items[j] = items[j + 1];
                    items[j + 1] = temp;
                }
            }
        }
    }

    private static void sortCoverageItems(List<JobCoverageItem> items, Boolean ascending) {
        Integer n = items.size();
        for (Integer i = 0; i < n - 1; i++) {
            for (Integer j = 0; j < n - i - 1; j++) {
                Boolean swap = ascending
                    ? (items[j].averageScore > items[j + 1].averageScore)
                    : (items[j].averageScore < items[j + 1].averageScore);
                if (swap) {
                    JobCoverageItem temp = items[j];
                    items[j] = items[j + 1];
                    items[j + 1] = temp;
                }
            }
        }
    }
}
