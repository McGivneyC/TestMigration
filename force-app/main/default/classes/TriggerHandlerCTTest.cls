@isTest
public class TriggerHandlerCTTest {

    // Test inserting a single default tip
    @isTest
    static void testInsertSingleDefaultTip() {
        CopadoTips__c tip = new CopadoTips__c(
            Name = 'Test Tip 1',
            DefaultTip__c = true
        );

        Test.startTest();
        insert tip;
        Test.stopTest();

        CopadoTips__c insertedTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :tip.Id];
        System.assert(insertedTip.DefaultTip__c, 'The tip should be set as default.');
    }

    // Test inserting multiple tips where more than one is set as default
    @isTest
    static void testInsertMultipleDefaultTips() {
        CopadoTips__c tip1 = new CopadoTips__c(
            Name = 'Test Tip 1',
            DefaultTip__c = true
        );

        CopadoTips__c tip2 = new CopadoTips__c(
            Name = 'Test Tip 2',
            DefaultTip__c = true
        );

        List<CopadoTips__c> tips = new List<CopadoTips__c>{tip1, tip2};

        Test.startTest();
        try {
            insert tips;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Only one CopadoTip record can be set as default'), 'Error message should be correct');
        }
        Test.stopTest();
    }

    // Test updating a tip to be the default when another default already exists
    @isTest
    static void testUpdateTipToDefault() {
        CopadoTips__c existingTip = new CopadoTips__c(
            Name = 'Existing Default Tip',
            DefaultTip__c = true
        );
        insert existingTip;

        CopadoTips__c newTip = new CopadoTips__c(
            Name = 'New Tip'
        );
        insert newTip;

        Test.startTest();
        newTip.DefaultTip__c = true;
        update newTip;
        Test.stopTest();

        CopadoTips__c updatedExistingTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :existingTip.Id];
        CopadoTips__c updatedNewTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :newTip.Id];

        System.assert(!updatedExistingTip.DefaultTip__c, 'Existing tip should no longer be default.');
        System.assert(updatedNewTip.DefaultTip__c, 'New tip should be set as default.');
    }
}