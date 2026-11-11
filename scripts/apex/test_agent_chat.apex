RecruitmentAgentChatController.ChatResponse resp = RecruitmentAgentChatController.sendMessage('How well does Alex Morgan match the AI/ML Engineer role?', null);
System.debug('Success: ' + resp.isSuccess);
System.debug('Message: ' + resp.message);
System.debug('Error: ' + resp.errorMessage);
