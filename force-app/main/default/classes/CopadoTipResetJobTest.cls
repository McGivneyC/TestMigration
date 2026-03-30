@isTest
public class CopadoTipResetJobTest {

    // Helper method to create test data
    private static CopadoTips__c createTip(Boolean isDefault, Datetime endTime) {
        CopadoTips__c tip = new CopadoTips__c(
            Name = 'Test Tip',
            DefaultTip__c = isDefault,
            TipEndTime__c = endTime
        );
        insert tip;
        return tip;
    }

    // Test method to verify that default tips with past end times are reset
    @isTest
    static void testResetPastDefaultTips() {
        // Setup: Create a default tip with a past end time
        Datetime pastTime = Datetime.now().addDays(-1);
        CopadoTips__c pastTip = createTip(true, pastTime);

        // Setup: Create a default tip with a future end time (should not be reset)
        Datetime futureTime = Datetime.now().addDays(1);
        CopadoTips__c futureTip = createTip(true, futureTime);

        // Execute the Queueable job
        Test.startTest();
        CopadoTipResetJob job = new CopadoTipResetJob();
        System.enqueueJob(job);
        Test.stopTest();

        // Refresh the records from the database
        pastTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :pastTip.Id];
        futureTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :futureTip.Id];

        // Assert: The past tip should have DefaultTip__c set to false
        System.assert(!pastTip.DefaultTip__c, 'Past tip should be reset to not default.');

        // Assert: The future tip should still have DefaultTip__c set to true
        System.assert(futureTip.DefaultTip__c, 'Future tip should remain default.');
    }

    // Test method to verify that no action is taken if there are no default tips with past end times
    @isTest
    static void testNoActionForFutureDefaultTips() {
        // Setup: Create a default tip with a future end time
        Datetime futureTime = Datetime.now().addDays(1);
        CopadoTips__c futureTip = createTip(true, futureTime);

        // Execute the Queueable job
        Test.startTest();
        CopadoTipResetJob job = new CopadoTipResetJob();
        System.enqueueJob(job);
        Test.stopTest();

        // Refresh the record from the database
        futureTip = [SELECT DefaultTip__c FROM CopadoTips__c WHERE Id = :futureTip.Id];

        // Assert: The future tip should still have DefaultTip__c set to true
        System.assert(futureTip.DefaultTip__c, 'Future tip should remain default.');
    }
}