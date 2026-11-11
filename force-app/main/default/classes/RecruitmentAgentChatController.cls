/**
 * @description Controller for the AI Recruitment Assistant LWC tab.
 * Invokes the activated Agentforce agent (AI_Recruitment_Assistant)
 * via Salesforce's native Invocable Action API (generateAiAgentResponse).
 */
public with sharing class RecruitmentAgentChatController {

    public class ChatResponse {
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String sessionId { get; set; }
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class AgentInfo {
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public String masterLabel { get; set; }
        @AuraEnabled public String agentType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
    }

    /**
     * @description Returns the activation and metadata status of the AI_Recruitment_Assistant agent.
     */
    @AuraEnabled(cacheable=true)
    public static AgentInfo getAgentInfo() {
        AgentInfo info = new AgentInfo();
        info.developerName = 'AI_Recruitment_Assistant';
        info.masterLabel = 'AI Recruitment Assistant';
        info.agentType = 'EinsteinServiceAgent';
        info.status = 'Active';
        info.isActive = true;

        List<BotDefinition> bots = [
            SELECT Id, DeveloperName, MasterLabel, AgentType,
                   (SELECT Status FROM BotVersions WHERE Status = 'Active' LIMIT 1)
            FROM BotDefinition 
            WHERE DeveloperName = 'AI_Recruitment_Assistant'
            LIMIT 1
        ];

        if (!bots.isEmpty()) {
            info.masterLabel = bots[0].MasterLabel;
            if (bots[0].AgentType != null) {
                info.agentType = bots[0].AgentType;
            }
            if (bots[0].BotVersions != null && !bots[0].BotVersions.isEmpty()) {
                info.status = bots[0].BotVersions[0].Status;
                info.isActive = 'Active'.equalsIgnoreCase(info.status);
            }
        }
        return info;
    }

    /**
     * @description Sends a user prompt to the activated Agentforce agent and returns its live response.
     * @param userMessage The recruiter's question or command
     * @param sessionId Optional session identifier for multi-turn conversation memory
     */
    @AuraEnabled
    public static ChatResponse sendMessage(String userMessage, String sessionId) {
        ChatResponse resp = new ChatResponse();
        if (String.isBlank(userMessage)) {
            resp.isSuccess = false;
            resp.errorMessage = 'Please enter a message.';
            return resp;
        }

        try {
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse', 
                'AI_Recruitment_Assistant'
            );
            action.setInvocationParameter('userMessage', userMessage.trim());
            if (String.isNotBlank(sessionId)) {
                action.setInvocationParameter('sessionId', sessionId);
            }

            List<Invocable.Action.Result> results = action.invoke();
            if (!results.isEmpty()) {
                Invocable.Action.Result res = results[0];
                if (res.isSuccess()) {
                    Map<String, Object> outputParams = res.getOutputParameters();
                    String rawResponse = outputParams.containsKey('agentResponse') 
                        ? String.valueOf(outputParams.get('agentResponse')) : '';
                    String newSessionId = outputParams.containsKey('sessionId') 
                        ? String.valueOf(outputParams.get('sessionId')) : sessionId;

                    String cleanText = rawResponse;
                    if (String.isNotBlank(rawResponse) && rawResponse.trim().startsWith('{')) {
                        try {
                            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rawResponse);
                            if (parsed != null && parsed.containsKey('value')) {
                                cleanText = (String) parsed.get('value');
                            }
                        } catch (Exception jsonEx) {
                            // Fallback to rawResponse string
                        }
                    }

                    // Decode HTML entities (e.g. &#124; to |)
                    if (cleanText != null) {
                        cleanText = cleanText.replace('&#124;', '|');
                    }

                    resp.message = cleanText;
                    resp.sessionId = newSessionId;
                    resp.isSuccess = true;
                } else {
                    resp.isSuccess = false;
                    List<Invocable.Action.Error> errors = res.getErrors();
                    String errorMsg = 'Agentforce did not return a response.';
                    if (errors != null && !errors.isEmpty()) {
                        errorMsg = errors[0].getMessage();
                    }
                    resp.errorMessage = errorMsg;
                }
            } else {
                resp.isSuccess = false;
                resp.errorMessage = 'No response returned from the agent.';
            }
        } catch (Exception ex) {
            resp.isSuccess = false;
            resp.errorMessage = 'Error invoking Agentforce agent: ' + ex.getMessage();
        }

        return resp;
    }
}
