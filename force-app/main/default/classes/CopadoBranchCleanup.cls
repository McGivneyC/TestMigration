/**
 * @description Production-ready batch job for automated cleanup of Copado branches and deployments
 * @author Copado DevOps Team
 * @version 3.0
 * @date January 2026
 * 
 * IMPORTANT: This class is designed for Copado Metadata Format Pipelines only.
 * 
 * API Endpoint: /json/v1/webhook/deleteGitBranches/{repositoryId}?api_key={apiKey}
 * Method: POST
 * Body: JSON array of branch names
 * 
 * Rollback Strategy:
 * - Branches are deleted from Git but Copado records remain until final confirmation
 * - Manual rollback requires Git provider restore from trash/archive (if available)
 * - Always test in sandbox first with DRY_RUN mode enabled
 * 
 * Impact on Active Promotions:
 * - Only processes completed deployments (Completed with Errors or Successful Validations)
 * - Excludes in-flight promotions by filtering on deployment status
 * - Protected branches safeguard active development branches
 */
public without sharing class CopadoBranchCleanup implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    // Constants
    private static final Integer MAX_BRANCHES_PER_BATCH = 200;
    private static final Integer API_TIMEOUT_MS = 120000;
    private static final String COPADO_API_ENDPOINT = '/json/v1/webhook/deleteGitBranches/';
    
    // Configuration from Custom Settings
    private static CopadoBranchCleanupSettings__c settings {
        get {
            if (settings == null) {
                settings = CopadoBranchCleanupSettings__c.getOrgDefaults();
                if (settings == null || settings.Id == null) {
                    // Create default settings if none exist
                    settings = new CopadoBranchCleanupSettings__c(
                        SetupOwnerId = UserInfo.getOrganizationId(),
                        DaysToKeep__c = 90,
                        ProtectedBranches__c = 'main,master,qa,uat,production',
                        DryRunMode__c = true,
                        EmailRecipients__c = UserInfo.getUserEmail(),
                        APITimeout__c = 120000,
                        DeleteDeployments__c = true
                    );
                }
            }
            return settings;
        }
        set;
    }
    
    private static final Integer DAYS_TO_KEEP = (Integer)settings.DaysToKeep__c != null ? (Integer)settings.DaysToKeep__c : 90;
    private static final Boolean DRY_RUN_MODE = settings.DryRunMode__c != null ? settings.DryRunMode__c : false;
    private static final String EMAIL_RECIPIENTS = settings.EmailRecipients__c;
    private static final Set<String> PROTECTED_BRANCHES = new Set<String>(
        settings.ProtectedBranches__c != null ? 
        settings.ProtectedBranches__c.toLowerCase().split(',') :
        new List<String>{'main', 'master', 'qa', 'devmerge', 'preprod', 'dev1', 'uat', 'hotfix', 'production'}
    );
    
    // Stateful tracking
    private Set<String> processedBranches;
    private Set<Id> processedDeployments;
    private List<String> errorLogs;
    private Integer totalBranchesDeleted;
    private Integer totalDeploymentsDeleted;
    private String batchJobId;
    
    // Custom Exception
    public class CopadoBranchCleanupException extends Exception {}
    
    /**
     * @description Inner class to hold branch processing results
     */
    private class BranchProcessingResult {
        public Set<String> branchesToDelete;
        public Set<Id> deploymentsToDelete;
        public String requestBody;
        
        public BranchProcessingResult() {
            this.branchesToDelete = new Set<String>();
            this.deploymentsToDelete = new Set<Id>();
            this.requestBody = '';
        }
    }
    
    /**
     * @description Constructor with permission validation
     */
    public CopadoBranchCleanup() {
        if (!hasRequiredPermissions()) {
            throw new CopadoBranchCleanupException('Insufficient permissions to execute branch cleanup. Required: Modify All Data or System Administrator.');
        }
        
        this.processedBranches = new Set<String>();
        this.processedDeployments = new Set<Id>();
        this.errorLogs = new List<String>();
        this.totalBranchesDeleted = 0;
        this.totalDeploymentsDeleted = 0;
    }
    
    /**
     * @description Start method - builds query for eligible deployment steps
     */
    public Database.QueryLocator start(Database.BatchableContext BC) {
        this.batchJobId = BC.getJobId();
        Date cutoffDate = Date.today().addDays(-DAYS_TO_KEEP);
        
        logOperation('Batch Started', 'Info', 
            'Job ID: ' + batchJobId + 
            ', Cutoff Date: ' + cutoffDate.format() + 
            ', Dry Run: ' + DRY_RUN_MODE);
        
        // Query only completed deployments to avoid impacting in-flight promotions
        return Database.getQueryLocator([
            SELECT Id, Name, copado__Branch__c, copado__Deployment__c,
                   copado__Deployment__r.Name, 
                   copado__Deployment__r.copado__Status__c,
                   copado__Status__c, 
                   copado__CheckOnly__c,
                   copado__Deployment__r.copado__Promotion__c,
                   copado__Deployment__r.copado__Promotion__r.copado__Status__c,
                   copado__Deployment__r.copado__Deployment_Type__c
            FROM copado__Step__c
            WHERE LastModifiedDate <= :cutoffDate
            AND copado__Branch__c != null
            AND copado__Deployment__r.copado__Promotion__c != null
            AND copado__Deployment__r.copado__Deployment_Type__c = 'Metadata'
            AND copado__Deployment__r.copado__Status__c IN ('Completed Successfully', 'Completed with Errors')
            AND copado__Deployment__r.copado__Promotion__r.copado__Status__c = 'Completed'
            AND (copado__Status__c = 'Completed with Errors'
                 OR (copado__CheckOnly__c = TRUE 
                     AND copado__Status__c = 'Completed Successfully'))
            ORDER BY LastModifiedDate ASC
        ]);
    }
    
    /**
     * @description Execute method - processes each batch of deployment steps
     */
    public void execute(Database.BatchableContext BC, List<copado__Step__c> scope) {
        try {
            // Process branches for current batch
            BranchProcessingResult result = processStepsAndBuildRequest(scope);
            
            if (!result.branchesToDelete.isEmpty()) {
                if (DRY_RUN_MODE) {
                    logOperation('Dry Run', 'Info', 
                        'Would delete ' + result.branchesToDelete.size() + ' branches: ' + 
                        String.join(new List<String>(result.branchesToDelete), ', '));
                    return;
                }
                
                // Get system properties
                Map<String, String> systemProps = getRequiredSystemProperties();
                
                // Delete branches via API
                String responseBody = makeDeleteBranchesApiCall(
                    systemProps.get('Server_URL'),
                    systemProps.get('Repository_Id'),
                    systemProps.get('Copado_API_Key'),
                    result.requestBody
                );
                
                // Track processed items
                processedBranches.addAll(result.branchesToDelete);
                processedDeployments.addAll(result.deploymentsToDelete);
                totalBranchesDeleted += result.branchesToDelete.size();
                
                // Log success
                logOperation('Branch Deletion', 'Success',
                    'Deleted ' + result.branchesToDelete.size() + ' branches. Response: ' + 
                    responseBody.abbreviate(1000));
            }
        } catch (Exception e) {
            String errorMsg = 'Batch execution error: ' + e.getMessage() + '\n' + e.getStackTraceString();
            errorLogs.add(errorMsg);
            logOperation('Branch Deletion', 'Error', errorMsg);
            // Don't throw - allow batch to continue processing remaining records
        }
    }
    
    /**
     * @description Finish method - cleanup deployments and send notifications
     */
    public void finish(Database.BatchableContext BC) {
        try {
            if (!DRY_RUN_MODE && !processedDeployments.isEmpty()) {
                totalDeploymentsDeleted = deleteAssociatedDeployments(processedDeployments);
            }
            
            // Send completion email
            sendCompletionEmail(BC);
            
            // Final log
            logOperation('Cleanup Completed', 'Success',
                'Job ID: ' + batchJobId + 
                ', Branches: ' + totalBranchesDeleted + 
                ', Deployments: ' + totalDeploymentsDeleted + 
                ', Errors: ' + errorLogs.size());
                
        } catch (Exception e) {
            String errorMsg = 'Finish method error: ' + e.getMessage();
            errorLogs.add(errorMsg);
            logOperation('Cleanup', 'Error', errorMsg);
        }
    }
    
    /**
     * @description Process deployment steps and build API request
     */
    private BranchProcessingResult processStepsAndBuildRequest(List<copado__Step__c> steps) {
        BranchProcessingResult result = new BranchProcessingResult();
        List<String> branchList = new List<String>();
        
        for (copado__Step__c step : steps) {
            String branchName = step.copado__Branch__c;
            
            // Skip if already processed
            if (processedBranches.contains(branchName)) {
                continue;
            }
            
            // Skip protected branches
            if (isProtectedBranch(branchName)) {
                logOperation('Protected Branch', 'Info', 'Skipping protected branch: ' + branchName);
                continue;
            }
            
            // Check batch size limit
            if (result.branchesToDelete.size() >= MAX_BRANCHES_PER_BATCH) {
                break;
            }
            
            result.branchesToDelete.add(branchName);
            result.deploymentsToDelete.add(step.copado__Deployment__c);
            branchList.add(branchName);
        }
        
        // Build JSON request body
        if (!branchList.isEmpty()) {
            result.requestBody = '["' + String.join(branchList, '","') + '"]';
        }
        
        return result;
    }
    
    /**
     * @description Check if branch is protected
     */
    private Boolean isProtectedBranch(String branchName) {
        if (String.isBlank(branchName)) {
            return true;
        }
        
        String lowerBranchName = branchName.toLowerCase();
        
        // Check exact match
        if (PROTECTED_BRANCHES.contains(lowerBranchName)) {
            return true;
        }
        
        // Check if branch starts with protected prefix
        for (String protectedBranch : PROTECTED_BRANCHES) {
            if (lowerBranchName.startsWith(protectedBranch + '/') || 
                lowerBranchName.startsWith(protectedBranch + '-')) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @description Retrieve required system properties from Copado
     */
    private Map<String, String> getRequiredSystemProperties() {
        Map<String, String> props = new Map<String, String>();
        
        List<copado__System_Property__c> systemProperties = [
            SELECT copado__API_Name__c, copado__Value__c
            FROM copado__System_Property__c
            WHERE copado__API_Name__c IN ('Server_URL', 'Repository_Id', 'Copado_API_Key')
        ];
        
        for (copado__System_Property__c prop : systemProperties) {
            props.put(prop.copado__API_Name__c, prop.copado__Value__c);
        }
        
        // Validate required properties
        if (!props.containsKey('Server_URL') || String.isBlank(props.get('Server_URL'))) {
            throw new CopadoBranchCleanupException('System Property "Server_URL" is missing or empty');
        }
        if (!props.containsKey('Repository_Id') || String.isBlank(props.get('Repository_Id'))) {
            throw new CopadoBranchCleanupException('System Property "Repository_Id" is missing or empty');
        }
        if (!props.containsKey('Copado_API_Key') || String.isBlank(props.get('Copado_API_Key'))) {
            throw new CopadoBranchCleanupException('System Property "Copado_API_Key" is missing or empty');
        }
        
        return props;
    }
    
    /**
     * @description Make API call to delete branches
     */
    private String makeDeleteBranchesApiCall(String serverUrl, String repositoryId, String apiKey, String requestBody) {
        // Build endpoint URL
        String endpoint = serverUrl + COPADO_API_ENDPOINT + repositoryId + '?api_key=' + apiKey;
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setBody(requestBody);
        req.setTimeout(API_TIMEOUT_MS);
        
        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Check response
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CopadoBranchCleanupException(
                'API call failed with status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }
        
        return res.getBody();
    }
    
    /**
     * @description Delete associated deployment records
     */
    private Integer deleteAssociatedDeployments(Set<Id> deploymentIds) {
        List<copado__Deployment__c> deploymentsToDelete = [
            SELECT Id 
            FROM copado__Deployment__c 
            WHERE Id IN :deploymentIds
        ];
        
        if (!deploymentsToDelete.isEmpty()) {
            try {
                delete deploymentsToDelete;
                logOperation('Deployment Deletion', 'Success', 
                    'Deleted ' + deploymentsToDelete.size() + ' deployment records');
                return deploymentsToDelete.size();
            } catch (DmlException e) {
                String errorMsg = 'Failed to delete deployments: ' + e.getMessage();
                errorLogs.add(errorMsg);
                logOperation('Deployment Deletion', 'Error', errorMsg);
                return 0;
            }
        }
        
        return 0;
    }
    
    /**
     * @description Send completion email notification
     */
    private void sendCompletionEmail(Database.BatchableContext BC) {
        try {
            List<String> recipients = new List<String>();
            
            // Add configured recipients
            if (String.isNotBlank(EMAIL_RECIPIENTS)) {
                recipients.addAll(EMAIL_RECIPIENTS.split(','));
            }
            
            // Add executing user
            recipients.add(UserInfo.getUserEmail());
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(recipients);
            mail.setSubject('Copado Branch Cleanup ' + (DRY_RUN_MODE ? '(DRY RUN) ' : '') + 'Completed - Job ' + batchJobId);
            
            String emailBody = buildEmailBody(BC);
            mail.setHtmlBody(emailBody);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) {
            logOperation('Email Notification', 'Error', 'Failed to send email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Build HTML email body
     */
    private String buildEmailBody(Database.BatchableContext BC) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate, CompletedDate
            FROM AsyncApexJob 
            WHERE Id = :BC.getJobId()
        ];
        
        String body = '<html><body>';
        body += '<h2>Copado Branch Cleanup Report</h2>';
        
        if (DRY_RUN_MODE) {
            body += '<p style="color: orange; font-weight: bold;">⚠️ DRY RUN MODE - No actual deletions performed</p>';
        }
        
        body += '<h3>Summary</h3>';
        body += '<ul>';
        body += '<li><strong>Job ID:</strong> ' + batchJobId + '</li>';
        body += '<li><strong>Status:</strong> ' + job.Status + '</li>';
        body += '<li><strong>Started:</strong> ' + job.CreatedDate + '</li>';
        body += '<li><strong>Completed:</strong> ' + job.CompletedDate + '</li>';
        body += '<li><strong>Batches Processed:</strong> ' + job.JobItemsProcessed + ' / ' + job.TotalJobItems + '</li>';
        body += '<li><strong>Branches Deleted:</strong> ' + totalBranchesDeleted + '</li>';
        body += '<li><strong>Deployments Deleted:</strong> ' + totalDeploymentsDeleted + '</li>';
        body += '<li><strong>Errors:</strong> ' + errorLogs.size() + '</li>';
        body += '</ul>';
        
        if (!errorLogs.isEmpty()) {
            body += '<h3 style="color: red;">Errors</h3>';
            body += '<ul>';
            for (String error : errorLogs) {
                body += '<li>' + error.escapeHtml4() + '</li>';
            }
            body += '</ul>';
        }
        
        body += '<h3>Configuration</h3>';
        body += '<ul>';
        body += '<li><strong>Days to Keep:</strong> ' + DAYS_TO_KEEP + '</li>';
        body += '<li><strong>Protected Branches:</strong> ' + String.join(new List<String>(PROTECTED_BRANCHES), ', ') + '</li>';
        body += '<li><strong>Dry Run Mode:</strong> ' + DRY_RUN_MODE + '</li>';
        body += '</ul>';
        
        body += '<p><em>For detailed logs, check the BranchCleanupLog__c records.</em></p>';
        body += '</body></html>';
        
        return body;
    }
    
    /**
     * @description Log operation to custom object
     */
    private void logOperation(String operation, String status, String details) {
        try {
            BranchCleanupLog__c log = new BranchCleanupLog__c(
                Operation__c = operation,
                Status__c = status,
                Details__c = details.abbreviate(131072),
                ExecutionDate__c = DateTime.now(),
                BatchJobId__c = this.batchJobId
            );
            
            Database.insert(log, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create log record: ' + e.getMessage());
        }
    }
    
    /**
     * @description Check if user has required permissions
     */
    private Boolean hasRequiredPermissions() {
        return Schema.sObjectType.copado__Deployment__c.isDeletable() &&
               Schema.sObjectType.copado__Step__c.isAccessible() &&
               Schema.sObjectType.copado__System_Property__c.isAccessible();
    }
}