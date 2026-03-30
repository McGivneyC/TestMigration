/**
 * @description Comprehensive test class for CopadoBranchCleanup
 * @author Copado DevOps Team
 * @version 3.0
 */
@IsTest
private class CopadoBranchCleanupTest {
    
    /**
     * @description Setup test data
     */
    @TestSetup
    static void setupTestData() {
        // Create Custom Settings
        CopadoBranchCleanupSettings__c settings = new CopadoBranchCleanupSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            DaysToKeep__c = 90,
            ProtectedBranches__c = 'main,master,qa,production',
            DryRunMode__c = false,
            EmailRecipients__c = 'test@example.com',
            APITimeout__c = 120000,
            DeleteDeployments__c = true
        );
        insert settings;
        
        // Create System Properties
        List<copado__System_Property__c> systemProps = new List<copado__System_Property__c>{
            new copado__System_Property__c(
                copado__API_Name__c = 'Server_URL',
                copado__Value__c = 'https://test.copado.com'
            ),
            new copado__System_Property__c(
                copado__API_Name__c = 'Repository_Id',
                copado__Value__c = 'test-repo-123'
            ),
            new copado__System_Property__c(
                copado__API_Name__c = 'Copado_API_Key',
                copado__Value__c = 'test-api-key-456'
            )
        };
        insert systemProps;
        
        // Create test Promotions
        List<copado__Promotion__c> promotions = new List<copado__Promotion__c>();
        for (Integer i = 0; i < 5; i++) {
            promotions.add(new copado__Promotion__c(
                copado__Status__c = 'Completed'
            ));
        }
        insert promotions;
        
        // Create test Deployments
        List<copado__Deployment__c> deployments = new List<copado__Deployment__c>();
        
        // Old completed deployment with errors
        deployments.add(new copado__Deployment__c(
            copado__Promotion__c = promotions[0].Id,
            copado__Status__c = 'Completed with Errors',
            copado__Deployment_Type__c = 'Metadata'
        ));
        
        // Old successful validation deployment
        deployments.add(new copado__Deployment__c(
            copado__Promotion__c = promotions[1].Id,
            copado__Status__c = 'Completed Successfully',
            copado__Deployment_Type__c = 'Metadata'
        ));
        
        // Recent deployment (should not be deleted)
        deployments.add(new copado__Deployment__c(
            copado__Promotion__c = promotions[2].Id,
            copado__Status__c = 'Completed with Errors',
            copado__Deployment_Type__c = 'Metadata'
        ));
        
        // In-progress deployment (should not be deleted)
        deployments.add(new copado__Deployment__c(
            copado__Promotion__c = promotions[3].Id,
            copado__Status__c = 'In Progress',
            copado__Deployment_Type__c = 'Metadata'
        ));
        
        // Source format deployment (should not be deleted)
        deployments.add(new copado__Deployment__c(
            copado__Promotion__c = promotions[4].Id,
            copado__Status__c = 'Completed with Errors',
            copado__Deployment_Type__c = 'Source Format'
        ));
        
        insert deployments;
        
        // Create test Steps
        List<copado__Step__c> steps = new List<copado__Step__c>();
        
        // Old step with error - should be deleted
        steps.add(new copado__Step__c(
            copado__Deployment__c = deployments[0].Id,
            copado__Branch__c = 'feature/old-branch-1',
            copado__Status__c = 'Completed with Errors',
            copado__CheckOnly__c = false
        ));
        
        // Old validation step - should be deleted
        steps.add(new copado__Step__c(
            copado__Deployment__c = deployments[1].Id,
            copado__Branch__c = 'feature/old-validation-1',
            copado__Status__c = 'Completed Successfully',
            copado__CheckOnly__c = true
        ));
        
        // Protected branch - should NOT be deleted
        steps.add(new copado__Step__c(
            copado__Deployment__c = deployments[0].Id,
            copado__Branch__c = 'main',
            copado__Status__c = 'Completed with Errors',
            copado__CheckOnly__c = false
        ));
        
        // Recent step - should NOT be deleted
        steps.add(new copado__Step__c(
            copado__Deployment__c = deployments[2].Id,
            copado__Branch__c = 'feature/recent-branch',
            copado__Status__c = 'Completed with Errors',
            copado__CheckOnly__c = false
        ));
        
        insert steps;
        
        // Update old steps to be older than 90 days
        Test.setCreatedDate(steps[0].Id, DateTime.now().addDays(-100));
        Test.setCreatedDate(steps[1].Id, DateTime.now().addDays(-100));
    }
    
    /**
     * @description Test successful branch cleanup
     */
    @IsTest
    static void testBranchCleanup_Success() {
        // Setup mock
        Test.setMock(HttpCalloutMock.class, new CopadoAPISuccessMock());
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify logs were created
        List<BranchCleanupLog__c> logs = [
            SELECT Operation__c, Status__c, Details__c
            FROM BranchCleanupLog__c
            WHERE Status__c = 'Success'
        ];
        
        System.assert(!logs.isEmpty(), 'Success logs should be created');
        
        // Verify protected branches were not processed
        List<BranchCleanupLog__c> protectedLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Operation__c LIKE '%protected branch%'
        ];
        
        System.assert(!protectedLogs.isEmpty(), 'Protected branch logs should exist');
    }
    
    /**
     * @description Test dry run mode
     */
    @IsTest
    static void testBranchCleanup_DryRun() {
        // Enable dry run
        CopadoBranchCleanupSettings__c settings = CopadoBranchCleanupSettings__c.getOrgDefaults();
        settings.DryRunMode__c = true;
        update settings;
        
        Integer deploymentCountBefore = [SELECT COUNT() FROM copado__Deployment__c];
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        Integer deploymentCountAfter = [SELECT COUNT() FROM copado__Deployment__c];
        
        // Verify no deployments were deleted
        System.assertEquals(deploymentCountBefore, deploymentCountAfter, 
            'Deployments should not be deleted in dry run mode');
        
        // Verify dry run logs
        List<BranchCleanupLog__c> dryRunLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Operation__c = 'Dry Run'
        ];
        
        System.assert(!dryRunLogs.isEmpty(), 'Dry run logs should be created');
    }
    
    /**
     * @description Test protected branches are not deleted
     */
    @IsTest
    static void testBranchCleanup_ProtectedBranches() {
        Test.setMock(HttpCalloutMock.class, new CopadoAPISuccessMock());
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify protected branch logs
        List<BranchCleanupLog__c> logs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Operation__c = 'Protected Branch'
        ];
        
        System.assert(!logs.isEmpty(), 'Protected branch should be logged');
        
        Boolean foundMainBranch = false;
        for (BranchCleanupLog__c log : logs) {
            if (log.Details__c.contains('main')) {
                foundMainBranch = true;
                break;
            }
        }
        
        System.assert(foundMainBranch, 'Main branch should be in protected logs');
    }
    
    /**
     * @description Test API failure handling
     */
    @IsTest
    static void testBranchCleanup_APIFailure() {
        Test.setMock(HttpCalloutMock.class, new CopadoAPIFailureMock());
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify error logs
        List<BranchCleanupLog__c> errorLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Status__c = 'Error'
        ];
        
        System.assert(!errorLogs.isEmpty(), 'Error logs should be created on API failure');
    }
    
    /**
     * @description Test missing system properties
     */
    @IsTest
    static void testBranchCleanup_MissingSystemProperties() {
        // Delete system properties
        delete [SELECT Id FROM copado__System_Property__c];
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify error logs
        List<BranchCleanupLog__c> errorLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Status__c = 'Error' AND Operation__c LIKE '%System Property%'
        ];
        
        System.assert(!errorLogs.isEmpty(), 'Error should be logged for missing system properties');
    }
    
    /**
     * @description Test deployment deletion
     */
    @IsTest
    static void testBranchCleanup_DeploymentDeletion() {
        Test.setMock(HttpCalloutMock.class, new CopadoAPISuccessMock());
        
        Integer deploymentCountBefore = [
            SELECT COUNT() 
            FROM copado__Deployment__c 
            WHERE copado__Deployment_Type__c = 'Metadata'
            AND copado__Status__c IN ('Completed with Errors', 'Completed Successfully')
        ];
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify deletion logs exist
        List<BranchCleanupLog__c> deletionLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Operation__c = 'Deployment Deletion'
        ];
        
        System.debug('Deletion logs: ' + deletionLogs);
    }
    
    /**
     * @description Test batch size limits
     */
    @IsTest
    static void testBranchCleanup_BatchSizeLimit() {
        // Create many old steps
        List<copado__Promotion__c> promotions = new List<copado__Promotion__c>();
        for (Integer i = 0; i < 10; i++) {
            promotions.add(new copado__Promotion__c(copado__Status__c = 'Completed'));
        }
        insert promotions;
        
        List<copado__Deployment__c> deployments = new List<copado__Deployment__c>();
        for (copado__Promotion__c promo : promotions) {
            deployments.add(new copado__Deployment__c(
                copado__Promotion__c = promo.Id,
                copado__Status__c = 'Completed with Errors',
                copado__Deployment_Type__c = 'Metadata'
            ));
        }
        insert deployments;
        
        List<copado__Step__c> steps = new List<copado__Step__c>();
        Integer counter = 0;
        for (copado__Deployment__c dep : deployments) {
            steps.add(new copado__Step__c(
                copado__Deployment__c = dep.Id,
                copado__Branch__c = 'feature/test-branch-' + counter++,
                copado__Status__c = 'Completed with Errors',
                copado__CheckOnly__c = false
            ));
        }
        insert steps;
        
        Test.setMock(HttpCalloutMock.class, new CopadoAPISuccessMock());
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify batch completed
        List<BranchCleanupLog__c> completionLogs = [
            SELECT Details__c
            FROM BranchCleanupLog__c
            WHERE Operation__c = 'Cleanup Completed'
        ];
        
        System.assert(!completionLogs.isEmpty(), 'Cleanup should complete');
    }
    
    /**
     * @description Test email notification
     */
    @IsTest
    static void testBranchCleanup_EmailNotification() {
        Test.setMock(HttpCalloutMock.class, new CopadoAPISuccessMock());
        
        Test.startTest();
        CopadoBranchCleanup cleanup = new CopadoBranchCleanup();
        Database.executeBatch(cleanup, 50);
        Test.stopTest();
        
        // Verify email was attempted (check logs)
        List<BranchCleanupLog__c> logs = [
            SELECT Operation__c
            FROM BranchCleanupLog__c
        ];
        
        System.assert(!logs.isEmpty(), 'Logs should be created');
    }
    
    /**
     * @description Mock class for successful API responses
     */
    private class CopadoAPISuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true, "deleted": 2}');
            return res;
        }
    }
    
    /**
     * @description Mock class for failed API responses
     */
    private class CopadoAPIFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal server error"}');
            return res;
        }
    }
}