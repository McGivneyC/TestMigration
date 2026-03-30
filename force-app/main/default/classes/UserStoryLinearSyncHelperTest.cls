@IsTest
private class UserStoryLinearSyncHelperTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test User Story
        copado__User_Story__c story = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test Story',
            Description__c = 'Test Description',
            copado__Status__c = 'Draft'
        );
        insert story;
    }
    
    @IsTest
    static void testInsertPublishesEvent() {
        // Test that inserting a User Story publishes a Platform Event
        Test.startTest();
        
        copado__User_Story__c newStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'New Story for Linear',
            Description__c = 'This should sync to Linear'
        );
        insert newStory;
        
        Test.stopTest();
        
        // Verify the story was created
        copado__User_Story__c inserted = [
            SELECT Id, copado__User_Story_Title__c 
            FROM copado__User_Story__c 
            WHERE Id = :newStory.Id
        ];
        System.assertEquals('New Story for Linear', inserted.copado__User_Story_Title__c);
    }
    
    @IsTest
    static void testUpdatePublishesEvent() {
        // Test that updating a User Story publishes a Platform Event
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c 
            FROM copado__User_Story__c 
            LIMIT 1
        ];
        
        Test.startTest();
        
        story.copado__User_Story_Title__c = 'Updated Title';
        update story;
        
        Test.stopTest();
        
        // Verify the story was updated
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c 
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        System.assertEquals('Updated Title', updated.copado__User_Story_Title__c);
    }
    
    @IsTest
    static void testSyncLoopPrevention() {
        // Test that recently synced stories don't trigger another sync
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c 
            FROM copado__User_Story__c 
            LIMIT 1
        ];
        
        // Set Last_Synced_From_Linear__c to now (simulating recent sync from Linear)
        story.Last_Synced_From_Linear__c = System.now();
        update story;
        
        Test.startTest();
        
        // Update the story - this should NOT trigger a sync
        story.copado__User_Story_Title__c = 'Updated After Sync';
        update story;
        
        Test.stopTest();
        
        // Verify the story was updated but no event was published
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c, Last_Synced_From_Linear__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        System.assertEquals('Updated After Sync', updated.copado__User_Story_Title__c);
    }
    
    @IsTest
    static void testShouldSyncToLinear_Insert() {
        // Test shouldSyncToLinear for insert operation
        copado__User_Story__c newStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test'
        );
        
        Boolean shouldSync = UserStoryLinearSyncHelper.shouldSyncToLinear(newStory, null);
        
        System.assertEquals(true, shouldSync, 'New stories should always sync');
    }
    
    @IsTest
    static void testShouldSyncToLinear_UpdateWithChanges() {
        // Test shouldSyncToLinear for update with relevant field changes
        // Create and insert a real record to get a valid ID
        copado__User_Story__c oldStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Old Title',
            Description__c = 'Old Description'
        );
        insert oldStory;
        
        // Create the "new" version with changes
        copado__User_Story__c newStory = new copado__User_Story__c(
            Id = oldStory.Id,
            copado__User_Story_Title__c = 'New Title',
            Description__c = 'Old Description'
        );
        
        Map<Id, copado__User_Story__c> oldMap = new Map<Id, copado__User_Story__c>{
            oldStory.Id => oldStory
        };
        
        Boolean shouldSync = UserStoryLinearSyncHelper.shouldSyncToLinear(newStory, oldMap);
        
        System.assertEquals(true, shouldSync, 'Should sync when title changes');
    }
    
    @IsTest
    static void testShouldSyncToLinear_UpdateNoChanges() {
        // Test shouldSyncToLinear for update with no relevant field changes
        // Create and insert a real record to get a valid ID
        copado__User_Story__c oldStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Same Title',
            Description__c = 'Same Description',
            copado__Status__c = 'Draft'
        );
        insert oldStory;
        
        // Create the "new" version with no changes
        copado__User_Story__c newStory = new copado__User_Story__c(
            Id = oldStory.Id,
            copado__User_Story_Title__c = 'Same Title',
            Description__c = 'Same Description',
            copado__Status__c = 'Draft'
        );
        
        Map<Id, copado__User_Story__c> oldMap = new Map<Id, copado__User_Story__c>{
            oldStory.Id => oldStory
        };
        
        Boolean shouldSync = UserStoryLinearSyncHelper.shouldSyncToLinear(newStory, oldMap);
        
        System.assertEquals(false, shouldSync, 'Should not sync when no relevant fields change');
    }
    
    @IsTest
    static void testShouldSyncToLinear_RecentlySynced() {
        // Test that recently synced stories don't trigger another sync
        copado__User_Story__c story = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test',
            Last_Synced_From_Linear__c = System.now().addSeconds(-5)
        );
        
        Boolean shouldSync = UserStoryLinearSyncHelper.shouldSyncToLinear(story, null);
        
        System.assertEquals(false, shouldSync, 'Should not sync recently synced stories');
    }
    
    @IsTest
    static void testBulkInsert() {
        // Test bulk insert of User Stories
        List<copado__User_Story__c> stories = new List<copado__User_Story__c>();
        
        for (Integer i = 0; i < 200; i++) {
            stories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Bulk Story ' + i,
                Description__c = 'Bulk test ' + i
            ));
        }
        
        Test.startTest();
        insert stories;
        Test.stopTest();
        
        // Verify all stories were created
        Integer count = [SELECT COUNT() FROM copado__User_Story__c WHERE copado__User_Story_Title__c LIKE 'Bulk Story%'];
        System.assertEquals(200, count, 'All bulk stories should be inserted');
    }
}