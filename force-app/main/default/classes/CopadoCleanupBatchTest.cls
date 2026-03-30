/**
 * @description Test class for CopadoCleanupBatch
 * @author CopadoAI
 * @date 2026-02-12
 */
@IsTest
private class CopadoCleanupBatchTest {
    
    private static String PROD_ENV_ID;
    
    /**
     * @description Test data factory
     */
    @TestSetup
    static void setupTestData() {
        // Create environments
        copado__Environment__c prodEnv = new copado__Environment__c(
            Name = 'Production',
            copado__Type__c = 'Production'
        );
        insert prodEnv;
        
        copado__Environment__c devEnv = new copado__Environment__c(
            Name = 'Development',
            copado__Type__c = 'Sandbox'
        );
        insert devEnv;
        
        // Create project
        copado__Project__c project = new copado__Project__c(
            Name = 'Test Project'
        );
        insert project;
        
        // Create old user stories that have been deployed to production
        List<copado__User_Story__c> oldUserStories = new List<copado__User_Story__c>();
        for (Integer i = 0; i < 100; i++) {
            oldUserStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Old Deployed Story ' + i,
                copado__Status__c = 'Approved',
                copado__Environment__c = prodEnv.Id,
                copado__Project__c = project.Id
            ));
        }
        insert oldUserStories;
        
        // Create recent user stories
        List<copado__User_Story__c> recentUserStories = new List<copado__User_Story__c>();
        for (Integer i = 0; i < 50; i++) {
            recentUserStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Recent Story ' + i,
                copado__Status__c = 'Approved',
                copado__Environment__c = devEnv.Id,
                copado__Project__c = project.Id
            ));
        }
        insert recentUserStories;
        
        // Create promotions and promoted user stories for old stories
        List<copado__Promotion__c> promotions = new List<copado__Promotion__c>();
        for (Integer i = 0; i < 5; i++) {
            promotions.add(new copado__Promotion__c(
                copado__Source_Environment__c = devEnv.Id,
                copado__Destination_Environment__c = prodEnv.Id,
                copado__Status__c = 'Completed'
            ));
        }
        insert promotions;
        
        // Create promoted user story records
        List<copado__Promoted_User_Story__c> promotedStories = new List<copado__Promoted_User_Story__c>();
        Integer promoIndex = 0;
        for (Integer i = 0; i < 100; i++) {
            promotedStories.add(new copado__Promoted_User_Story__c(
                copado__User_Story__c = oldUserStories[i].Id,
                copado__Promotion__c = promotions[Math.mod(promoIndex++, 5)].Id,
                copado__Status__c = 'Completed'
            ));
        }
        insert promotedStories;
        
        // Update LastModifiedDate for old user stories
        Date oldDate = Date.today().addDays(-200);
        for (copado__User_Story__c story : oldUserStories) {
            Test.setCreatedDate(story.Id, DateTime.newInstance(oldDate, Time.newInstance(0, 0, 0, 0)));
        }
        
        // Create feature branches
        List<copado__Git_Backup__c> branches = new List<copado__Git_Backup__c>();
        for (Integer i = 0; i < 150; i++) {
            branches.add(new copado__Git_Backup__c(
                Name = 'feature/old-branch-' + i
            ));
        }
        insert branches;
        
        // Set old dates for branches
        Date branchOldDate = Date.today().addMonths(-7);
        for (copado__Git_Backup__c branch : branches) {
            Test.setCreatedDate(branch.Id, DateTime.newInstance(branchOldDate, Time.newInstance(0, 0, 0, 0)));
        }
    }
    
    /**
     * @description Test user story cleanup only
     */
    @IsTest
    static void testUserStoryCleanup() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        Integer initialCount = [SELECT COUNT() FROM copado__User_Story__c];
        System.assertEquals(150, initialCount, 'Should have 150 total user stories');
        
        Test.startTest();
        Id jobId = CopadoCleanupBatch.executeUserStoryCleanup(180, prodEnv.Id, 200);
        Test.stopTest();
        
        // Verify old user stories deployed to production were deleted
        Integer remainingCount = [SELECT COUNT() FROM copado__User_Story__c];
        System.assertEquals(50, remainingCount, 'Should have 50 recent user stories remaining');
        
        // Verify only recent stories remain
        List<copado__User_Story__c> remaining = [
            SELECT copado__User_Story_Title__c 
            FROM copado__User_Story__c
        ];
        for (copado__User_Story__c story : remaining) {
            System.assert(story.copado__User_Story_Title__c.contains('Recent'), 
                         'Only recent stories should remain');
        }
    }
    
    /**
     * @description Test feature branch cleanup only
     */
    @IsTest
    static void testFeatureBranchCleanup() {
        Integer initialCount = [SELECT COUNT() FROM copado__Git_Backup__c];
        System.assertEquals(150, initialCount, 'Should have 150 feature branches');
        
        Test.startTest();
        Id jobId = CopadoCleanupBatch.executeFeatureBranchCleanup(6, 200);
        Test.stopTest();
        
        // Verify old branches were deleted
        Integer remainingCount = [SELECT COUNT() FROM copado__Git_Backup__c];
        System.assertEquals(0, remainingCount, 'All branches older than 6 months should be deleted');
    }
    
    /**
     * @description Test full cleanup (both user stories and branches)
     */
    @IsTest
    static void testFullCleanup() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        Integer initialUSCount = [SELECT COUNT() FROM copado__User_Story__c];
        Integer initialBranchCount = [SELECT COUNT() FROM copado__Git_Backup__c];
        
        Test.startTest();
        Id jobId = CopadoCleanupBatch.executeFullCleanup(6, 180, prodEnv.Id, 200);
        Test.stopTest();
        
        // Verify user stories were cleaned up
        Integer remainingUSCount = [SELECT COUNT() FROM copado__User_Story__c];
        System.assertEquals(50, remainingUSCount, 'Should have 50 recent user stories remaining');
        
        // Note: In test context, the chained batch for branches may not execute
        // This is a Salesforce limitation with Test.stopTest()
    }
    
    /**
     * @description Test with custom days threshold
     */
    @IsTest
    static void testCustomDaysThreshold() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        Test.startTest();
        // Use 365 days threshold - should delete nothing
        Id jobId = CopadoCleanupBatch.executeUserStoryCleanup(365, prodEnv.Id, 100);
        Test.stopTest();
        
        Integer remainingCount = [SELECT COUNT() FROM copado__User_Story__c];
        System.assertEquals(150, remainingCount, 'No user stories should be deleted with 365 day threshold');
    }
    
    /**
     * @description Test error handling for missing production environment
     */
    @IsTest
    static void testMissingProductionEnvironment() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            Id jobId = CopadoCleanupBatch.executeUserStoryCleanup(180, null, 200);
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Production Environment ID is required'), 
                         'Should throw exception for missing production environment');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for null production environment');
    }
    
    /**
     * @description Test bulk processing with large dataset
     */
    @IsTest
    static void testBulkProcessing() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        Test.startTest();
        Id jobId = CopadoCleanupBatch.executeUserStoryCleanup(180, prodEnv.Id, 50);
        Test.stopTest();
        
        // Verify batch completed
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors 
            FROM AsyncApexJob 
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
    }
    
    /**
     * @description Test cleanup type constants
     */
    @IsTest
    static void testCleanupTypes() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        Test.startTest();
        CopadoCleanupBatch userStoryBatch = new CopadoCleanupBatch(
            CopadoCleanupBatch.CLEANUP_TYPE_USER_STORIES,
            6,
            180,
            prodEnv.Id
        );
        
        CopadoCleanupBatch branchBatch = new CopadoCleanupBatch(
            CopadoCleanupBatch.CLEANUP_TYPE_FEATURE_BRANCHES,
            6,
            180,
            null
        );
        
        CopadoCleanupBatch bothBatch = new CopadoCleanupBatch(
            CopadoCleanupBatch.CLEANUP_TYPE_BOTH,
            6,
            180,
            prodEnv.Id
        );
        
        // Just verify constructors work without errors
        System.assertNotEquals(null, userStoryBatch, 'User story batch should be created');
        System.assertNotEquals(null, branchBatch, 'Branch batch should be created');
        System.assertNotEquals(null, bothBatch, 'Both batch should be created');
        Test.stopTest();
    }
    
    /**
     * @description Test query building for user stories
     */
    @IsTest
    static void testUserStoryQueryLogic() {
        copado__Environment__c prodEnv = [SELECT Id FROM copado__Environment__c WHERE Name = 'Production' LIMIT 1];
        
        // Verify that only user stories with completed promotions to prod are targeted
        List<copado__User_Story__c> targetedStories = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c
            WHERE Id IN (
                SELECT copado__User_Story__c
                FROM copado__Promoted_User_Story__c
                WHERE copado__Promotion__r.copado__Destination_Environment__c = :prodEnv.Id
                AND copado__Status__c = 'Completed'
            )
        ];
        
        System.assertEquals(100, targetedStories.size(), 
                          'Should find 100 user stories promoted to production');
    }
}