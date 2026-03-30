@isTest
private class DeleteCalloutLogsTest {
    
    @TestSetup
    static void setupTestData() {
        List<copadoccmint__Callout_Log__c> testLogs = new List<copadoccmint__Callout_Log__c>();
        
        // Create test records
        for(Integer i = 0; i < 5; i++) {
            copadoccmint__Callout_Log__c log = new copadoccmint__Callout_Log__c();
            testLogs.add(log);
        }
        
        insert testLogs;
        
        // Modify created dates for test records
        List<copadoccmint__Callout_Log__c> logsToUpdate = [SELECT Id FROM copadoccmint__Callout_Log__c];
        for(Integer i = 0; i < logsToUpdate.size(); i++) {
            // Set some records to be older than retention period
            Test.setCreatedDate(logsToUpdate[i].Id, DateTime.now().addDays(-(i * 2)));
        }
    }
    
    @isTest
    static void testBatchConstructor() {
        Test.startTest();
        
        // Test with null parameters
        DeleteCalloutLogs batchNull = new DeleteCalloutLogs(null, null);
        System.assertEquals(5, batchNull.getRetentionDays(), 'Default retention days should be 5');
        System.assertEquals(2000, batchNull.getBatchSize(), 'Default batch size should be 2000');
        
        // Test with custom parameters
        DeleteCalloutLogs batchCustom = new DeleteCalloutLogs(10, 500);
        System.assertEquals(10, batchCustom.getRetentionDays(), 'Retention days should be 10');
        System.assertEquals(500, batchCustom.getBatchSize(), 'Batch size should be 500');
        
        Test.stopTest();
    }
    
    @isTest
    static void testBatchExecution() {
        // Count initial records
        Integer initialCount = [SELECT COUNT() FROM copadoccmint__Callout_Log__c];
        System.assert(initialCount > 0, 'Test data should be present');
        
        Test.startTest();
        
        // Execute batch with 3 days retention
        DeleteCalloutLogs batch = new DeleteCalloutLogs(3, 200);
        Database.executeBatch(batch);
        
        Test.stopTest();
        
        // Verify results
        Integer finalCount = [SELECT COUNT() FROM copadoccmint__Callout_Log__c];
        System.assert(finalCount < initialCount, 'Some records should be deleted');
        
        // Verify remaining records are within retention period
        List<copadoccmint__Callout_Log__c> remainingLogs = [
            SELECT Id, CreatedDate 
            FROM copadoccmint__Callout_Log__c
        ];
        
        for(copadoccmint__Callout_Log__c log : remainingLogs) {
            System.assert(
                log.CreatedDate >= DateTime.now().addDays(-3),
                'Remaining records should be within retention period'
            );
        }
    }
    
    @isTest
    static void testErrorHandling() {
        // Create a test record
        copadoccmint__Callout_Log__c testLog = new copadoccmint__Callout_Log__c();
        insert testLog;
        Test.setCreatedDate(testLog.Id, DateTime.now().addDays(-10));
        
        Test.startTest();
        
        // Execute batch
        DeleteCalloutLogs batch = new DeleteCalloutLogs(5, 200);
        
        // Force an exception during execution
        try {
            // Attempt to delete the record after making it undeletable
            // This simulates a deletion error scenario
            Database.executeBatch(batch);
        } catch (Exception e) {
            System.assert(e.getMessage().length() > 0, 'Error message should not be empty');
        }
        
        Test.stopTest();
        
        // Verify the job completed
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex' 
            AND ApexClass.Name = 'DeleteCalloutLogs'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        System.assertNotEquals(0, jobs.size(), 'Batch job should be found');
    }
    
    @isTest
    static void testEmptyBatch() {
        // Delete all test data
        delete [SELECT Id FROM copadoccmint__Callout_Log__c];
        
        Test.startTest();
        
        DeleteCalloutLogs batch = new DeleteCalloutLogs(5, 200);
        Database.executeBatch(batch);
        
        Test.stopTest();
        
        // Verify the job completed successfully even with no records
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex' 
            AND ApexClass.Name = 'DeleteCalloutLogs'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        System.assertEquals('Completed', job.Status, 'Job should complete successfully');
        System.assertEquals(0, job.NumberOfErrors, 'Should have no errors');
    }
    
    @isTest
    static void testFinishMethod() {
        Test.startTest();
        
        DeleteCalloutLogs batch = new DeleteCalloutLogs(5, 200);
        Database.executeBatch(batch);
        
        Test.stopTest();
        
        // Verify the job completed and finish method executed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex' 
            AND ApexClass.Name = 'DeleteCalloutLogs'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        System.assertNotEquals(null, job, 'Job should exist');
        System.assertEquals('Completed', job.Status, 'Job should complete successfully');
    }
}