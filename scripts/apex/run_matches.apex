List<Candidate_Job_Match__c> results = CandidateJobMatchService.evaluateAll(true);
System.debug('Evaluated and upserted ' + results.size() + ' match records.');
