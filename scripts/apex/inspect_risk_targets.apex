RecruitmentRiskService.RiskDashboardDTO intelligence = RecruitmentRiskService.evaluateRisks(null, 'all', 'all');
System.debug('TOTAL_SIGNALS:' + intelligence.allSignals.size());
System.debug('HIGH_ATTN:' + intelligence.totalHighAttentionCount);
System.debug('REQ_REVIEW:' + intelligence.totalRequiresReviewCount);
System.debug('OVERDUE_INT:' + intelligence.totalOverdueInterviews);

for (RecruitmentRiskService.RequisitionRiskSummary sum : intelligence.jobSummaries) {
    if (sum.jobTitle == 'AI/ML Engineer' || sum.jobTitle == 'Software Engineer' || sum.jobTitle == 'Data Analyst') {
        System.debug('JOB_SUMMARY_START:' + sum.jobTitle);
        System.debug('  Status: ' + sum.status + ' | Req Headcount: ' + sum.requiredHeadcount);
        System.debug('  Apps: ' + sum.applicationCount + ' | Evaluated: ' + sum.evaluatedCandidateCount);
        System.debug('  Strong (>=80%): ' + sum.strongMatchCount + ' | Good (>=65%): ' + sum.goodMatchCount);
        System.debug('  Avg Match: ' + sum.averageMatchScore + '% | Highest: ' + sum.highestMatchScore + '% (' + sum.highestMatchCandidateName + ')');
        System.debug('  Overall Level: ' + sum.overallAttentionLevel);
        for (RecruitmentRiskService.RiskSignal sig : sum.signals) {
            System.debug('    Signal: [' + sig.severity + '] ' + sig.title + ' -> ' + sig.evidence);
        }
        System.debug('JOB_SUMMARY_END:' + sum.jobTitle);
    }
}

for (RecruitmentRiskService.RiskSignal sig : intelligence.interviewSignals) {
    System.debug('INTERVIEW_SIGNAL: [' + sig.severity + '] ' + sig.title + ' -> ' + sig.evidence + ' | ' + sig.explanation);
}

for (RecruitmentRiskService.RiskSignal sig : intelligence.pipelineSignals) {
    System.debug('PIPELINE_SIGNAL: [' + sig.severity + '] ' + sig.title + ' -> ' + sig.evidence);
}
