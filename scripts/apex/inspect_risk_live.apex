RecruitmentRiskService.RiskDashboardDTO intelligence = RecruitmentRiskService.evaluateRisks(null, 'all', 'all');
System.debug('=== RISK INTELLIGENCE SUMMARY ===');
System.debug('Total Signals: ' + intelligence.allSignals.size());
System.debug('High Attention: ' + intelligence.totalHighAttentionCount);
System.debug('Requires Review: ' + intelligence.totalRequiresReviewCount);
System.debug('Informational: ' + intelligence.totalInformationalCount);
System.debug('Jobs Needing Attention: ' + intelligence.totalJobsNeedingAttention);
System.debug('Overdue Interviews: ' + intelligence.totalOverdueInterviews);

System.debug('=== SIGNALS BREAKDOWN ===');
for (RecruitmentRiskService.RiskSignal sig : intelligence.allSignals) {
    System.debug('[' + sig.severity + '] (' + sig.signalType + ') Job: ' + sig.jobTitle + ' - ' + sig.title);
    System.debug('   Evidence: ' + sig.evidence);
    System.debug('   Explanation: ' + sig.explanation);
    System.debug('   DrillDown: ' + sig.drillDownAction + ' | RelatedId: ' + sig.relatedRecordId);
}

System.debug('=== JOB SUMMARIES ===');
for (RecruitmentRiskService.RequisitionRiskSummary sum : intelligence.jobSummaries) {
    System.debug('Job: ' + sum.jobTitle + ' [' + sum.status + '] - Level: ' + sum.overallAttentionLevel +
                 ' | Apps: ' + sum.applicationCount + ' | Evaluated: ' + sum.evaluatedCandidateCount +
                 ' | Strong: ' + sum.strongMatchCount + ' | Good: ' + sum.goodMatchCount +
                 ' | Mod: ' + sum.moderateMatchCount + ' | Low: ' + sum.lowMatchCount +
                 ' | AvgScore: ' + sum.averageMatchScore + '% | HighScore: ' + sum.highestMatchScore + '% (' + sum.highestMatchCandidateName + ')');
}

System.debug('=== RECURRING SKILL GAPS ===');
for (RecruitmentRiskService.SkillGapRiskMetric skill : intelligence.recurringSkillGaps) {
    System.debug('Skill: ' + skill.skillName + ' | Missing in ' + skill.affectedEvaluations + ' evaluations (' + skill.affectedCandidates + ' candidates) across ' + skill.affectedJobsCount + ' jobs (' + String.join(skill.affectedJobTitles, ', ') + ')');
}

System.debug('=== SAMPLE INVOCABLE ACTION RUN (all) ===');
RecruitmentRiskAction.RiskRequest req = new RecruitmentRiskAction.RiskRequest();
req.queryType = 'all';
List<RecruitmentRiskAction.RiskResult> results = RecruitmentRiskAction.getRiskIntelligence(new List<RecruitmentRiskAction.RiskRequest>{ req });
if (!results.isEmpty()) {
    System.debug('Agent Action Summary:\n' + results[0].summary);
}

System.debug('=== SAMPLE INVOCABLE ACTION RUN (why_job_needs_attention) ===');
RecruitmentRiskAction.RiskRequest req2 = new RecruitmentRiskAction.RiskRequest();
req2.queryType = 'why_job_needs_attention';
req2.jobTitleOrCode = 'AI/ML Engineer';
List<RecruitmentRiskAction.RiskResult> results2 = RecruitmentRiskAction.getRiskIntelligence(new List<RecruitmentRiskAction.RiskRequest>{ req2 });
if (!results2.isEmpty()) {
    System.debug('AI/ML Engineer Attention:\n' + results2[0].summary);
}
