public class EnvironmentActionController {
    
    @InvocableMethod(label='Run SFDX Code Analyzer' 
                     description='Executes SFDX Code Analyzer on the specified environment')
    public static void runCodeAnalyzer(List<Request> requests) {
        if (requests.isEmpty()) {
            return;
        }
        
        Request req = requests[0];
        Id environmentId = req.environmentId;
        
        // Get environment details
        copado__Environment__c env = [
            SELECT Id, Name, copado__Org_ID__c, copado__Platform__c
            FROM copado__Environment__c 
            WHERE Id = :environmentId 
            LIMIT 1
        ];
        
        // Create Function execution
        copado__JobExecution__c jobExec = new copado__JobExecution__c();
        jobExec.copado__DataJson__c = JSON.serialize(new Map<String, Object>{
            'environmentId' => environmentId,
            'environmentName' => env.Name,
            'orgId' => env.copado__Org_ID__c
        });
        
        // Link to your Copado Function
        // You'll need to get your Function's ID
        jobExec.copado__Template__c = 'a0MDm000000XXXXX'; // Replace with your Function ID
        
        insert jobExec;
        
        // Optionally, start the execution
        // This depends on your Copado version and setup
    }
    
    public class Request {
        @InvocableVariable(label='Environment ID' required=true)
        public Id environmentId;
    }
}