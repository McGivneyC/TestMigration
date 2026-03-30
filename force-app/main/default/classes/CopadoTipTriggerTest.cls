@isTest
public class CopadoTipTriggerTest {

    /** Test inserting a single default tip
  @isTest
static void testInsertSingleDefaultTip() {
    // Reset static variables
    TriggerHandlerCT.setCleanupJobEnqueued(false);

    Test.startTest();
    CopadoTips__c tip = new CopadoTips__c(
        Name = 'Test Tip 1',
        DefaultTip__c = true
    );
    insert tip;
    Test.stopTest();

    // Verify the tip was inserted and is set as default
    CopadoTips__c insertedTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :tip.Id];
    System.assert(insertedTip.DefaultTip__c, 'The tip should be set as default.');

    // Verify that the cleanup job was enqueued
    System.assertEquals(1, Limits.getQueueableJobs(), 'A cleanup job should have been enqueued.');
}
**/
    // Test updating a tip to set it as default when another default already exists
    @isTest
    static void testUpdateTipToDefault() {
        // Setup existing default tip
        CopadoTips__c existingTip = new CopadoTips__c(
            Name = 'Existing Default Tip',
            DefaultTip__c = true
        );
        insert existingTip;

        // Setup new tip
        CopadoTips__c newTip = new CopadoTips__c(
            Name = 'New Tip'
        );
        insert newTip;

        Test.startTest();
        newTip.DefaultTip__c = true;
        update newTip;
        Test.stopTest();

        // Verify that the existing tip is no longer default
        CopadoTips__c updatedExistingTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :existingTip.Id];
        System.assert(!updatedExistingTip.DefaultTip__c, 'Existing tip should no longer be default.');

        // Verify that the new tip is set as default
        CopadoTips__c updatedNewTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :newTip.Id];
        System.assert(updatedNewTip.DefaultTip__c, 'New tip should be set as default.');

        // Verify that the cleanup job was enqueued
        System.assertEquals(1, Limits.getQueueableJobs(), 'A cleanup job should have been enqueued.');
    }

    // Test to ensure no cleanup job is enqueued when no default tip is set or changed
    @isTest
    static void testNoCleanupJobEnqueuedWithoutDefaultChange() {
        CopadoTips__c tip = new CopadoTips__c(
            Name = 'Test Tip 1'
        );

        Test.startTest();
        insert tip;
        Test.stopTest();

        // Verify that no cleanup job was enqueued
        System.assertEquals(0, Limits.getQueueableJobs(), 'No cleanup job should have been enqueued.');
    }
}