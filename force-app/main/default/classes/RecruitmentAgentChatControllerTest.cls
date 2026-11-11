@isTest
private class RecruitmentAgentChatControllerTest {

    @isTest
    static void testGetAgentInfo() {
        Test.startTest();
        RecruitmentAgentChatController.AgentInfo info = RecruitmentAgentChatController.getAgentInfo();
        Test.stopTest();

        System.assertNotEquals(null, info, 'AgentInfo should not be null');
        System.assertEquals('AI_Recruitment_Assistant', info.developerName, 'Developer name should match');
    }

    @isTest
    static void testSendMessageEmpty() {
        Test.startTest();
        RecruitmentAgentChatController.ChatResponse resp = RecruitmentAgentChatController.sendMessage('', null);
        Test.stopTest();

        System.assertEquals(false, resp.isSuccess, 'Should fail for empty message');
        System.assertNotEquals(null, resp.errorMessage, 'Error message should be set');
    }

    @isTest
    static void testSendMessageInvocation() {
        Test.startTest();
        RecruitmentAgentChatController.ChatResponse resp = RecruitmentAgentChatController.sendMessage(
            'Give me a recruitment pipeline summary.', 
            null
        );
        Test.stopTest();

        // In test context, verify ChatResponse structure is handled gracefully
        System.assertNotEquals(null, resp, 'ChatResponse should not be null');
    }
}
