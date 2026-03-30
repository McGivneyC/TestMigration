@IsTest
private class TestGitHubWebhookHandler {
    
    @IsTest
    static void testValidPushEvent() {
        // Setup test data and mock request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = 'https://yourInstance.salesforce.com/services/apexrest/github/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"action":"push","repository":{"name":"example-repo"}}');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        GitHubWebhookHandler.handleWebhook();
        Test.stopTest();
        
        // Asserts
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Function triggered successfully.', res.responseBody.toString());
    }
    
    @IsTest
    static void testInvalidAction() {
        // Setup test data and mock request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = 'https://yourInstance.salesforce.com/services/apexrest/github/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"action":"invalid","repository":{"name":"example-repo"}}');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        GitHubWebhookHandler.handleWebhook();
        Test.stopTest();
        
        // Asserts
        System.assertEquals(400, res.statusCode);
        System.assertEquals('Invalid payload or action.', res.responseBody.toString());
    }
    
    @IsTest
    static void testExceptionHandling() {
        // Setup test data and mock request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = 'https://yourInstance.salesforce.com/services/apexrest/github/webhook';
        req.httpMethod = 'POST';
        // Deliberately malformed JSON to trigger exception
        req.requestBody = Blob.valueOf('{"action":"push","repository":{');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        GitHubWebhookHandler.handleWebhook();
        Test.stopTest();
        
        // Asserts
        System.assertEquals(500, res.statusCode);
        System.assert(res.responseBody.toString().startsWith('Error processing request:'));
    }
}