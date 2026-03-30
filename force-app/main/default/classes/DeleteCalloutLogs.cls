/**
 * @description Batch class to delete Callout Log records older than the specified retention period
 * @author [Your Name]
 * @date [Current Date]
 * @group Maintenance
 */
global class DeleteCalloutLogs implements Database.Batchable<sObject> {
    private Integer retentionDays;
    private Integer batchSize;
    
    global Integer getRetentionDays() {
    return this.retentionDays;
    }

    global Integer getBatchSize() {
    return this.batchSize;
    }

    global DeleteCalloutLogs(Integer retentionDays, Integer batchSize) {
        this.retentionDays = retentionDays != null ? retentionDays : 5;
        this.batchSize = batchSize != null ? batchSize : 2000;
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id 
            FROM copadoccmint__Callout_Log__c 
            WHERE CreatedDate < :DateTime.now().addDays(-retentionDays)
        ]);
    }

    global void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            List<copadoccmint__Callout_Log__c> calloutLogsToDelete = (List<copadoccmint__Callout_Log__c>) scope;
            Database.DeleteResult[] results = Database.delete(calloutLogsToDelete, false);
            
            // Process any errors
            List<String> errors = new List<String>();
            for(Database.DeleteResult dr : results) {
                if (!dr.isSuccess()) {
                    errors.add(dr.getId() + ': ' + dr.getErrors()[0].getMessage());
                }
            }
            
            if(!errors.isEmpty()) {
                System.debug('Errors during deletion: ' + String.join(errors, '; '));
            }
        } catch(Exception e) {
            System.debug('Error in execute method: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    global void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob 
            WHERE Id = :bc.getJobId()
        ];
        
        String message = String.format('Batch job completed. Status: {0}. Records processed: {1}/{2}. Errors: {3}', 
            new List<String>{
                job.Status,
                String.valueOf(job.JobItemsProcessed),
                String.valueOf(job.TotalJobItems),
                String.valueOf(job.NumberOfErrors)
            }
        );
        
        System.debug(message);
    }

}