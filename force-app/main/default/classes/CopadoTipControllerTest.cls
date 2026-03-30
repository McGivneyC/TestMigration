@isTest
public class CopadoTipControllerTest {
    
    // Utility method to create test data
    private static List<CopadoTips__c> createTestData() {
        List<CopadoTips__c> tips = new List<CopadoTips__c>();
        DateTime now = DateTime.now();
        // Create a default tip that is currently active
        tips.add(new CopadoTips__c(
            Name='Default Active Tip',
            TipDescription__c='This is a default active tip.',
            TipCategory__c='Other',
            DefaultTip__c=true,
            TipStartTime__c=now.addDays(-1),
            TipEndTime__c=now.addDays(1)
        ));
        // Create an expired default tip
        tips.add(new CopadoTips__c(
            Name='Expired Default Tip',
            TipDescription__c='This is an expired default tip.',
            TipCategory__c='Other',
            DefaultTip__c=true,
            TipStartTime__c=now.addDays(-3),
            TipEndTime__c=now.addDays(-2)
        ));
        insert tips;
        return tips;
    }
    
    // Utility method to create test data without default tips
    private static List<CopadoTips__c> createTestDataWithoutDefault() {
        List<CopadoTips__c> randomTips = new List<CopadoTips__c>();
        DateTime now = DateTime.now();
        
        // Create multiple active tips but ensure no default tips are active
        randomTips.add(new CopadoTips__c(
            Name='Active Tip 1',
            TipDescription__c='This is an random tip.',
            TipCategory__c='other',
            DefaultTip__c=false
        ));
        randomTips.add(new CopadoTips__c(
            Name='Active Tip 2',
            TipDescription__c='This is another random tip.',
            TipCategory__c='Other',
            DefaultTip__c=false
        ));
        insert randomTips;
        return randomTips;
    }
    
    @isTest
    static void testGetTipsWithDefaultTip() {
        // Setup test data
        createTestData();
        
        Test.startTest();
        Map<String, CopadoTips__c> tips = CopadoTipController.getTips();
        Test.stopTest();
        
        // Assertions
        System.assert(tips.containsKey('defaultTip'), 'Should retrieve the default tip');
        System.assertEquals('Default Active Tip', tips.get('defaultTip').Name, 'The default tip should match the expected name');
    }

       @isTest
    static void testGetTipsWithRandomTip() {
        // Setup test data without default tips
        createTestDataWithoutDefault();
        
        Test.startTest();
        Map<String, CopadoTips__c> randomTips = CopadoTipController.getTips();
        Test.stopTest();
        
        // Assertions
        System.assert(randomTips.containsKey('randomTip'), 'Should retrieve a random tip');
        System.assertNotEquals(null, randomTips.get('randomTip'), 'The random tip should not be null');
    }


    @isTest
    static void testResetDefaultTip() {
        // Setup test data
        List<CopadoTips__c> tips = createTestData();
        
        Test.startTest();
        CopadoTipController.resetDefaultTip();
        Test.stopTest();
        
        // Refresh from DB
        List<CopadoTips__c> updatedTips = [SELECT Id, Name, DefaultTip__c FROM CopadoTips__c WHERE Id IN :tips];
        
        // Assertions
        for (CopadoTips__c tip : updatedTips) {
            if (tip.Name == 'Expired Default Tip') {
                System.assert(!tip.DefaultTip__c, 'Expired default tip should be reset');
            }
        }
    }
}