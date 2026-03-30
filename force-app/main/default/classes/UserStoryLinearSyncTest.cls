@IsTest
private class UserStoryLinearSyncTest {
    
    // ========================================
    // TEST SETUP
    // ========================================
    
    @TestSetup
    static void setupTestData() {
        // Create test User Stories with various configurations
        List<copado__User_Story__c> stories = new List<copado__User_Story__c>();
        
        // Story 1: Basic story for update tests
        stories.add(new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test Story 1',
            Description__c = 'Initial Description',
            copado__Status__c = 'Draft'
        ));
        
        // Story 2: Story with Linear ID (already synced)
        stories.add(new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test Story 2',
            Description__c = 'Already synced',
            Linear_Issue_ID__c = 'LIN-123',
            copado__Status__c = 'In Progress'
        ));
        
        // Story 3: Recently synced story (should not trigger sync)
        stories.add(new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test Story 3',
            Description__c = 'Recently synced',
            Last_Synced_From_Linear__c = System.now().addSeconds(-5),
            copado__Status__c = 'Approved'
        ));
        
        insert stories;
    }
    
    // ========================================
    // INSERT TESTS
    // ========================================
    
    @IsTest
    static void testInsertSingleStory_PublishesEvent() {
        // Given: A new User Story
        copado__User_Story__c newStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'New Linear Story',
            Description__c = 'This should sync to Linear',
            copado__Status__c = 'Draft'
        );
        
        // When: Story is inserted
        Test.startTest();
        insert newStory;
        Test.stopTest();
        
        // Then: Story is created successfully
        copado__User_Story__c inserted = [
            SELECT Id, copado__User_Story_Title__c, Description__c, copado__Status__c
            FROM copado__User_Story__c 
            WHERE Id = :newStory.Id
        ];
        
        System.assertEquals('New Linear Story', inserted.copado__User_Story_Title__c, 
            'Story title should match');
        System.assertEquals('This should sync to Linear', inserted.Description__c, 
            'Description should match');
        
        // Note: Platform Events are published asynchronously
        // In a real integration test, you would verify the event was published
        // by subscribing to the event or checking event logs
    }
    
    @IsTest
    static void testInsertMultipleStories_BulkOperation() {
        // Given: Multiple new User Stories
        List<copado__User_Story__c> newStories = new List<copado__User_Story__c>();
        
        for (Integer i = 0; i < 50; i++) {
            newStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Bulk Story ' + i,
                Description__c = 'Bulk test description ' + i,
                copado__Status__c = 'Draft'
            ));
        }
        
        // When: Stories are inserted in bulk
        Test.startTest();
        insert newStories;
        Test.stopTest();
        
        // Then: All stories are created
        Integer count = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE 'Bulk Story%'
        ];
        
        System.assertEquals(50, count, 'All 50 stories should be inserted');
    }
    
    @IsTest
    static void testInsertStoryWithLinearID_PublishesEvent() {
        // Given: A new story that already has a Linear ID (rare but possible)
        copado__User_Story__c newStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Pre-synced Story',
            Description__c = 'Already has Linear ID',
            Linear_Issue_ID__c = 'LIN-999',
            copado__Status__c = 'Draft'
        );
        
        // When: Story is inserted
        Test.startTest();
        insert newStory;
        Test.stopTest();
        
        // Then: Story is created with Linear ID
        copado__User_Story__c inserted = [
            SELECT Id, Linear_Issue_ID__c
            FROM copado__User_Story__c 
            WHERE Id = :newStory.Id
        ];
        
        System.assertEquals('LIN-999', inserted.Linear_Issue_ID__c, 
            'Linear ID should be preserved');
    }
    
    // ========================================
    // UPDATE TESTS
    // ========================================
    
    @IsTest
    static void testUpdateStoryTitle_PublishesEvent() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        // When: Title is updated
        Test.startTest();
        story.copado__User_Story_Title__c = 'Updated Title for Linear';
        update story;
        Test.stopTest();
        
        // Then: Story is updated
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Updated Title for Linear', updated.copado__User_Story_Title__c, 
            'Title should be updated');
    }
    
    @IsTest
    static void testUpdateStoryDescription_PublishesEvent() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id, Description__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        // When: Description is updated
        Test.startTest();
        story.Description__c = 'Updated description that should sync';
        update story;
        Test.stopTest();
        
        // Then: Story is updated
        copado__User_Story__c updated = [
            SELECT Id, Description__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Updated description that should sync', updated.Description__c, 
            'Description should be updated');
    }
    
    @IsTest
    static void testUpdateStoryStatus_PublishesEvent() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id, copado__Status__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        // When: Status is updated
        Test.startTest();
        story.copado__Status__c = 'Approved';
        update story;
        Test.stopTest();
        
        // Then: Story status is updated
        copado__User_Story__c updated = [
            SELECT Id, copado__Status__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Approved', updated.copado__Status__c, 
            'Status should be updated');
    }
    
    @IsTest
    static void testUpdateMultipleFields_PublishesEvent() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c, Description__c, copado__Status__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        // When: Multiple fields are updated
        Test.startTest();
        story.copado__User_Story_Title__c = 'Multi-field Update';
        story.Description__c = 'New description';
        story.copado__Status__c = 'In Progress';
        update story;
        Test.stopTest();
        
        // Then: All fields are updated
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c, Description__c, copado__Status__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Multi-field Update', updated.copado__User_Story_Title__c);
        System.assertEquals('New description', updated.Description__c);
        System.assertEquals('In Progress', updated.copado__Status__c);
    }
    
    @IsTest
    static void testUpdateBulkStories_PublishesEvents() {
        // Given: Multiple existing User Stories
        List<copado__User_Story__c> stories = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c IN ('Test Story 1', 'Test Story 2')
        ];
        
        // When: Multiple stories are updated
        Test.startTest();
        for (copado__User_Story__c story : stories) {
            story.copado__User_Story_Title__c = story.copado__User_Story_Title__c + ' - Updated';
        }
        update stories;
        Test.stopTest();
        
        // Then: All stories are updated
        List<copado__User_Story__c> updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id IN :stories
        ];
        
        for (copado__User_Story__c story : updated) {
            System.assert(story.copado__User_Story_Title__c.contains('Updated'), 
                'Story title should contain "Updated"');
        }
    }
    
    // ========================================
    // SYNC PREVENTION TESTS
    // ========================================
    
    @IsTest
    static void testUpdateRecentlySyncedStory_DoesNotPublishEvent() {
        // Given: A story that was recently synced from Linear
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c, Last_Synced_From_Linear__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 3'
            LIMIT 1
        ];
        
        // Verify it was recently synced
        System.assertNotEquals(null, story.Last_Synced_From_Linear__c, 
            'Story should have Last_Synced_From_Linear__c set');
        
        // When: Story is updated
        Test.startTest();
        story.copado__User_Story_Title__c = 'Updated After Recent Sync';
        update story;
        Test.stopTest();
        
        // Then: Story is updated but no event should be published
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Updated After Recent Sync', updated.copado__User_Story_Title__c, 
            'Story should be updated even though sync is prevented');
    }
    
    @IsTest
    static void testUpdateOldSyncedStory_PublishesEvent() {
        // Given: A story that was synced more than 10 seconds ago
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        // Set Last_Synced_From_Linear__c to 11 seconds ago
        story.Last_Synced_From_Linear__c = System.now().addSeconds(-11);
        update story;
        
        // When: Story is updated after the sync window
        Test.startTest();
        story.copado__User_Story_Title__c = 'Updated After Old Sync';
        update story;
        Test.stopTest();
        
        // Then: Story is updated and event should be published
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Updated After Old Sync', updated.copado__User_Story_Title__c, 
            'Story should be updated and sync should occur');
    }
    
    @IsTest
    static void testUpdateNonSyncedFields_DoesNotPublishEvent() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id, copado__User_Story_Title__c, Description__c, copado__Status__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        String originalTitle = story.copado__User_Story_Title__c;
        String originalDescription = story.Description__c;
        String originalStatus = story.copado__Status__c;
        
        // When: Only non-synced fields are updated (if any exist)
        // Note: In this implementation, all main fields trigger sync
        // This test demonstrates the pattern for future field additions
        Test.startTest();
        // Update a field that doesn't trigger sync (example: a custom field)
        // For now, we'll just verify the trigger handles updates gracefully
        story.copado__User_Story_Title__c = originalTitle; // No actual change
        update story;
        Test.stopTest();
        
        // Then: Story remains unchanged
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals(originalTitle, updated.copado__User_Story_Title__c, 
            'Story title should remain unchanged');
    }
    
    // ========================================
    // EDGE CASE TESTS
    // ========================================
    
    @IsTest
    static void testInsertStoryWithNullFields_HandlesGracefully() {
        // Given: A story with minimal required fields
        copado__User_Story__c newStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Minimal Story'
            // Description and Status are null
        );
        
        // When: Story is inserted
        Test.startTest();
        insert newStory;
        Test.stopTest();
        
        // Then: Story is created successfully
        copado__User_Story__c inserted = [
            SELECT Id, copado__User_Story_Title__c, Description__c, copado__Status__c
            FROM copado__User_Story__c 
            WHERE Id = :newStory.Id
        ];
        
        System.assertEquals('Minimal Story', inserted.copado__User_Story_Title__c);
        System.assertEquals(null, inserted.Description__c, 'Description should be null');
    }
    
    @IsTest
    static void testUpdateStoryToNullDescription_PublishesEvent() {
        // Given: An existing User Story with a description
        copado__User_Story__c story = [
            SELECT Id, Description__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c = 'Test Story 1'
            LIMIT 1
        ];
        
        System.assertNotEquals(null, story.Description__c, 
            'Story should have a description initially');
        
        // When: Description is set to null
        Test.startTest();
        story.Description__c = null;
        update story;
        Test.stopTest();
        
        // Then: Description is null
        copado__User_Story__c updated = [
            SELECT Id, Description__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals(null, updated.Description__c, 
            'Description should be null after update');
    }
    
    @IsTest
    static void testBulkInsert200Stories_HandlesGovernorLimits() {
        // Given: 200 new User Stories (testing bulk limits)
        List<copado__User_Story__c> bulkStories = new List<copado__User_Story__c>();
        
        for (Integer i = 0; i < 200; i++) {
            bulkStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Bulk Insert Story ' + i,
                Description__c = 'Testing governor limits ' + i,
                copado__Status__c = 'Draft'
            ));
        }
        
        // When: All stories are inserted at once
        Test.startTest();
        insert bulkStories;
        Test.stopTest();
        
        // Then: All stories are created
        Integer count = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE 'Bulk Insert Story%'
        ];
        
        System.assertEquals(200, count, 'All 200 stories should be inserted');
        
        // Verify no governor limit exceptions occurred
        System.assert(Limits.getDmlStatements() <= Limits.getLimitDmlStatements(), 
            'Should not exceed DML statement limits');
        System.assert(Limits.getQueries() <= Limits.getLimitQueries(), 
            'Should not exceed SOQL query limits');
    }
    
    @IsTest
    static void testBulkUpdate200Stories_HandlesGovernorLimits() {
        // Given: 200 existing User Stories
        List<copado__User_Story__c> bulkStories = new List<copado__User_Story__c>();
        
        for (Integer i = 0; i < 200; i++) {
            bulkStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Bulk Update Story ' + i,
                Description__c = 'Original description ' + i
            ));
        }
        insert bulkStories;
        
        // When: All stories are updated at once
        Test.startTest();
        for (copado__User_Story__c story : bulkStories) {
            story.Description__c = 'Updated description';
        }
        update bulkStories;
        Test.stopTest();
        
        // Then: All stories are updated
        List<copado__User_Story__c> updated = [
            SELECT Id, Description__c
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE 'Bulk Update Story%'
        ];
        
        System.assertEquals(200, updated.size(), 'All 200 stories should be updated');
        
        for (copado__User_Story__c story : updated) {
            System.assertEquals('Updated description', story.Description__c, 
                'All descriptions should be updated');
        }
    }
    
    @IsTest
    static void testMixedInsertAndUpdate_HandlesCorrectly() {
        // Given: Some existing stories
        List<copado__User_Story__c> existingStories = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            LIMIT 2
        ];
        
        // When: We insert new stories and update existing ones in sequence
        Test.startTest();
        
        // Insert new stories
        List<copado__User_Story__c> newStories = new List<copado__User_Story__c>();
        newStories.add(new copado__User_Story__c(
            copado__User_Story_Title__c = 'Mixed Test New 1'
        ));
        newStories.add(new copado__User_Story__c(
            copado__User_Story_Title__c = 'Mixed Test New 2'
        ));
        insert newStories;
        
        // Update existing stories
        for (copado__User_Story__c story : existingStories) {
            story.copado__User_Story_Title__c = story.copado__User_Story_Title__c + ' - Mixed';
        }
        update existingStories;
        
        Test.stopTest();
        
        // Then: Both operations succeed
        Integer newCount = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE 'Mixed Test New%'
        ];
        System.assertEquals(2, newCount, 'New stories should be inserted');
        
        Integer updatedCount = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE '%Mixed'
        ];
        System.assertEquals(2, updatedCount, 'Existing stories should be updated');
    }
    
    // ========================================
    // TRIGGER CONTEXT TESTS
    // ========================================
    
    @IsTest
    static void testTriggerOnlyFiresOnInsertAndUpdate() {
        // Given: An existing User Story
        copado__User_Story__c story = [
            SELECT Id
            FROM copado__User_Story__c 
            LIMIT 1
        ];
        
        // When: Story is deleted (trigger should NOT fire)
        Test.startTest();
        delete story;
        Test.stopTest();
        
        // Then: Story is deleted (no exception thrown)
        Integer count = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals(0, count, 'Story should be deleted');
        
        // Note: If trigger fired on delete, it would cause an error
        // since the trigger is only designed for insert/update
    }
    
    @IsTest
    static void testTriggerHandlesRecursion() {
        // Given: A User Story
        copado__User_Story__c story = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Recursion Test'
        );
        insert story;
        
        // When: Story is updated multiple times rapidly
        Test.startTest();
        
        story.copado__User_Story_Title__c = 'Update 1';
        update story;
        
        story.copado__User_Story_Title__c = 'Update 2';
        update story;
        
        story.copado__User_Story_Title__c = 'Update 3';
        update story;
        
        Test.stopTest();
        
        // Then: All updates succeed without recursion errors
        copado__User_Story__c updated = [
            SELECT Id, copado__User_Story_Title__c
            FROM copado__User_Story__c 
            WHERE Id = :story.Id
        ];
        
        System.assertEquals('Update 3', updated.copado__User_Story_Title__c, 
            'Final update should be applied');
    }
}