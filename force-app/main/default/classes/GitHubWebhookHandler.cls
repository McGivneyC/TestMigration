@RestResource(urlMapping='/services/apexrest/github/webhook')
global with sharing class GitHubWebhookHandler {

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Parse the JSON payload from the webhook
            WebhookPayload payload = (WebhookPayload)JSON.deserialize(req.requestBody.toString(), WebhookPayload.class);
            
            // Check for a specific condition to trigger the Copado Function
            if (payload.action == 'push' && payload.repository != null) {
                // Assuming there's a Copado Function designed to handle GitHub push events
                triggerCopadoFunction(payload.repository.name);
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('Function triggered successfully.');
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Invalid payload or action.');
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing request: ' + e.getMessage());
        }
    }
    
    private static void triggerCopadoFunction(String repositoryName) {
        // Logic to trigger a Copado Function, possibly using a custom setting or directly invoking a function
        copado.RunCopadoFunction.InvocableVariables request = new copado.RunCopadoFunction.InvocableVariables();
        request.functionApiName = 'ClonePublicRepo';
        //request.contextId = 'contextId';
        request.parametersJSON = '[{"name": "giturl", "value": "https://github.com/McGivneyC/SFDX"}]';
        // request.resultCallback = 'SampleResultCallback';
        List<String> result = copado.RunCopadoFunction.execute(new List<copado.RunCopadoFunction.InvocableVariables> { request });
        String resultId = result[0];
        System.debug('Triggering Copado Function for repository: ' + repositoryName + resultId);
    }
    
    // Class to deserialize JSON payload from GitHub
    global class WebhookPayload {
        public String action;
        public Repository repository;
    }
    
    global class Repository {
        public String name;
    }
}