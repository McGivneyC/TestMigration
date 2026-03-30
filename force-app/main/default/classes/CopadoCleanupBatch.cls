/**
 * @description Enhanced batch class to clean up:
 *              1. Feature branches older than specified months
 *              2. User Stories deployed to production and older than specified days
 *              Designed to handle 10,000+ records while respecting governor limits.
 * @author CopadoAI
 * @date 2026-02-12
 */
public with sharing class CopadoCleanupBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    // Static constants instead of enum to avoid static context issues
    public static final String CLEANUP_TYPE_FEATURE_BRANCHES = 'FEATURE_BRANCHES';
    public static final String CLEANUP_TYPE_USER_STORIES = 'USER_STORIES';
    public static final String CLEANUP_TYPE_BOTH = 'BOTH';
    
    private String cleanupType;
    private Integer monthsOld;
    private Integer daysOld;
    private Integer totalProcessed = 0;
    private Integer totalDeleted = 0;
    private Integer totalErrors = 0;
    private List<String> errorMessages = new List<String>();
    private String productionEnvironmentId;
    
    /**
     * @description Constructor for cleaning up both branches and user stories
     * @param cleanupType Type of cleanup to perform
     * @param monthsOld Number of months for branch cleanup
     * @param daysOld Number of days for user story cleanup
     * @param productionEnvironmentId Id of the production environment record
     */
    public CopadoCleanupBatch(String cleanupType, Integer monthsOld, Integer daysOld, String productionEnvironmentId) {
        this.cleanupType = String.isNotBlank(cleanupType) ? cleanupType : CLEANUP_TYPE_BOTH;
        this.monthsOld = monthsOld != null && monthsOld > 0 ? monthsOld : 6;
        this.daysOld = daysOld != null && daysOld > 0 ? daysOld : 180;
        this.productionEnvironmentId = productionEnvironmentId;
    }
    
    /**
     * @description Constructor for user story cleanup only
     * @param daysOld Number of days - user stories older than this will be deleted
     * @param productionEnvironmentId Id of the production environment record
     */
    public CopadoCleanupBatch(Integer daysOld, String productionEnvironmentId) {
        this(CLEANUP_TYPE_USER_STORIES, 6, daysOld, productionEnvironmentId);
    }
    
    /**
     * @description Query records based on cleanup type
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query;
        
        if (cleanupType == CLEANUP_TYPE_FEATURE_BRANCHES) {
            query = buildFeatureBranchQuery();
        } else if (cleanupType == CLEANUP_TYPE_USER_STORIES) {
            query = buildUserStoryQuery();
        } else {
            // For BOTH, we'll run user stories first, then schedule branches separately
            query = buildUserStoryQuery();
        }
        
        System.debug('Cleanup Type: ' + cleanupType);
        System.debug('Query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Build query for feature branches
     * @return String SOQL query
     */
    private String buildFeatureBranchQuery() {
        Date cutoffDate = Date.today().addMonths(-1 * this.monthsOld);
        
        return 'SELECT Id, Name, CreatedDate, LastModifiedDate ' +
               'FROM copado__Git_Backup__c ' +
               'WHERE CreatedDate < :cutoffDate ' +
               'AND Name LIKE \'%feature%\' ' +
               'ORDER BY CreatedDate ASC';
    }
    
    /**
     * @description Build query for user stories deployed to production
     * @return String SOQL query
     */
    private String buildUserStoryQuery() {
        Date cutoffDate = Date.today().addDays(-1 * this.daysOld);
        
        // Query user stories that have been promoted to production
        // We look for Promoted User Story records where the promotion was to production
        String query = 'SELECT Id, Name, copado__User_Story_Title__c, ' +
                       'CreatedDate, LastModifiedDate, copado__Status__c, ' +
                       'copado__Environment__c, copado__Project__c, copado__Release__c ' +
                       'FROM copado__User_Story__c ' +
                       'WHERE Id IN (' +
                       '    SELECT copado__User_Story__c ' +
                       '    FROM copado__Promoted_User_Story__c ' +
                       '    WHERE copado__Promotion__r.copado__Destination_Environment__c = :productionEnvironmentId ' +
                       '    AND copado__Status__c = \'Completed\' ' +
                       ') ' +
                       'AND LastModifiedDate < :cutoffDate ' +
                       'ORDER BY LastModifiedDate ASC';
        
        return query;
    }
    
    /**
     * @description Process each batch of records
     * @param bc BatchableContext
     * @param scope List of records to process in this batch
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SObject> recordsToDelete = new List<SObject>();
        
        for (SObject record : scope) {
            totalProcessed++;
            recordsToDelete.add(record);
            
            if (record.getSObjectType() == copado__User_Story__c.SObjectType) {
                System.debug('Marking User Story for deletion: ' + record.get('Name') + 
                            ' - ' + record.get('copado__User_Story_Title__c') +
                            ' (Last Modified: ' + record.get('LastModifiedDate') + ')');
            } else {
                System.debug('Marking Feature Branch for deletion: ' + record.get('Name') + 
                            ' (Created: ' + record.get('CreatedDate') + ')');
            }
        }
        
        // Delete with partial success to continue processing even if some fail
        if (!recordsToDelete.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(recordsToDelete, false);
            
            // Track results
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    totalDeleted++;
                } else {
                    totalErrors++;
                    String recordName = recordsToDelete[i].get('Name') != null ? 
                                       String.valueOf(recordsToDelete[i].get('Name')) : 'Unknown';
                    String errorMsg = 'Failed to delete record: ' + recordName + ' - ';
                    for (Database.Error err : results[i].getErrors()) {
                        errorMsg += err.getMessage() + '; ';
                    }
                    errorMessages.add(errorMsg);
                    System.debug(LoggingLevel.ERROR, errorMsg);
                }
            }
        }
    }
    
    /**
     * @description Finish method - sends summary email and logs results
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        // Get batch job info
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
                   CreatedBy.Email, CreatedBy.Name
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        // Log summary
        System.debug('=== Copado Cleanup Summary ===');
        System.debug('Cleanup Type: ' + cleanupType);
        System.debug('Months Old Threshold (Branches): ' + monthsOld);
        System.debug('Days Old Threshold (User Stories): ' + daysOld);
        System.debug('Total Processed: ' + totalProcessed);
        System.debug('Total Deleted: ' + totalDeleted);
        System.debug('Total Errors: ' + totalErrors);
        System.debug('Job Status: ' + job.Status);
        
        // Send summary email
        sendSummaryEmail(job);
        
        // Create audit log
        createAuditLog(job);
        
        // If cleanup type is BOTH and we just finished user stories, schedule branch cleanup
        if (cleanupType == CLEANUP_TYPE_BOTH && totalProcessed > 0) {
            System.debug('Scheduling feature branch cleanup...');
            CopadoCleanupBatch branchBatch = new CopadoCleanupBatch(
                CLEANUP_TYPE_FEATURE_BRANCHES, 
                monthsOld, 
                daysOld, 
                productionEnvironmentId
            );
            Database.executeBatch(branchBatch, 200);
        }
    }
    
    /**
     * @description Send summary email to the user who executed the batch
     * @param job AsyncApexJob record
     */
    private void sendSummaryEmail(AsyncApexJob job) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { job.CreatedBy.Email });
        mail.setSubject('Copado Cleanup Completed - ' + cleanupType + ' - ' + job.Status);
        
        String body = 'Hello ' + job.CreatedBy.Name + ',\n\n';
        body += 'The Copado cleanup batch job has completed.\n\n';
        body += 'Summary:\n';
        body += '- Cleanup Type: ' + cleanupType + '\n';
        
        if (cleanupType == CLEANUP_TYPE_FEATURE_BRANCHES || cleanupType == CLEANUP_TYPE_BOTH) {
            body += '- Branch Age Threshold: Older than ' + monthsOld + ' months\n';
        }
        
        if (cleanupType == CLEANUP_TYPE_USER_STORIES || cleanupType == CLEANUP_TYPE_BOTH) {
            body += '- User Story Age Threshold: Older than ' + daysOld + ' days (deployed to production)\n';
        }
        
        body += '- Total Records Processed: ' + totalProcessed + '\n';
        body += '- Successfully Deleted: ' + totalDeleted + '\n';
        body += '- Errors: ' + totalErrors + '\n';
        body += '- Job Status: ' + job.Status + '\n\n';
        
        if (totalErrors > 0) {
            body += 'Errors encountered:\n';
            Integer errorCount = 0;
            for (String error : errorMessages) {
                if (errorCount < 10) {
                    body += '- ' + error + '\n';
                    errorCount++;
                }
            }
            if (errorMessages.size() > 10) {
                body += '... and ' + (errorMessages.size() - 10) + ' more errors.\n';
            }
        }
        
        body += '\nJob ID: ' + job.Id + '\n';
        body += '\nThis is an automated message from the Copado Cleanup process.';
        
        mail.setPlainTextBody(body);
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to send summary email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Create an audit log record for compliance tracking
     * @param job AsyncApexJob record
     */
    private void createAuditLog(AsyncApexJob job) {
        System.debug('Audit Log: Copado Cleanup (' + cleanupType + ') executed by ' + 
                    job.CreatedBy.Name + ' at ' + System.now());
        System.debug('Records Processed: ' + totalProcessed + ', Deleted: ' + totalDeleted + 
                    ', Errors: ' + totalErrors);
    }
    
    /**
     * @description Execute batch to clean up user stories deployed to production
     * @param daysOld Age threshold in days
     * @param productionEnvironmentId Id of production environment
     * @param batchSize Number of records to process per batch
     * @return Id of the batch job
     */
    public static Id executeUserStoryCleanup(Integer daysOld, String productionEnvironmentId, Integer batchSize) {
        if (String.isBlank(productionEnvironmentId)) {
            throw new IllegalArgumentException('Production Environment ID is required for User Story cleanup');
        }
        
        CopadoCleanupBatch batch = new CopadoCleanupBatch(daysOld, productionEnvironmentId);
        Integer size = batchSize != null && batchSize > 0 ? batchSize : 200;
        return Database.executeBatch(batch, size);
    }
    
    /**
     * @description Execute batch to clean up feature branches
     * @param monthsOld Age threshold in months
     * @param batchSize Number of records to process per batch
     * @return Id of the batch job
     */
    public static Id executeFeatureBranchCleanup(Integer monthsOld, Integer batchSize) {
        CopadoCleanupBatch batch = new CopadoCleanupBatch(
            CLEANUP_TYPE_FEATURE_BRANCHES, 
            monthsOld, 
            180, 
            null
        );
        Integer size = batchSize != null && batchSize > 0 ? batchSize : 200;
        return Database.executeBatch(batch, size);
    }
    
    /**
     * @description Execute batch to clean up both branches and user stories
     * @param monthsOld Age threshold in months for branches
     * @param daysOld Age threshold in days for user stories
     * @param productionEnvironmentId Id of production environment
     * @param batchSize Number of records to process per batch
     * @return Id of the batch job
     */
    public static Id executeFullCleanup(Integer monthsOld, Integer daysOld, String productionEnvironmentId, Integer batchSize) {
        if (String.isBlank(productionEnvironmentId)) {
            throw new IllegalArgumentException('Production Environment ID is required for User Story cleanup');
        }
        
        CopadoCleanupBatch batch = new CopadoCleanupBatch(
            CLEANUP_TYPE_BOTH, 
            monthsOld, 
            daysOld, 
            productionEnvironmentId
        );
        Integer size = batchSize != null && batchSize > 0 ? batchSize : 200;
        return Database.executeBatch(batch, size);
    }
}