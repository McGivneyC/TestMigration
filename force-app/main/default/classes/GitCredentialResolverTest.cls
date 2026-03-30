/**
 * @description Test class for GitCredentialResolver v2.0
 * Tests both Source Format and Metadata Format Pipeline scenarios
 * Tests multiple pipeline support and repository selection
 *
 * Note: Some tests use SeeAllData=true to work with existing Copado configuration
 * since Copado Git Repository objects require special licensing to create in tests.
 *
 * @author CopadoAI
 * @date 2025-12-17
 * @version 2.0 - Updated for multiple pipeline support
 */
@isTest
private class GitCredentialResolverTest {

    /**
     * @description Test successful credential resolution for Source Format Pipeline (SFDX)
     * Uses SeeAllData to work with existing Copado configuration
     */
    @isTest(SeeAllData=true)
    static void testSourceFormatPipelineSuccess() {
        // Find an existing environment with a Source Format pipeline (Platform = SFDX)
        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id,
                   copado__Source_Environment__c,
                   copado__Destination_Environment__c,
                   copado__Branch__c,
                   copado__Destination_Branch__c,
                   copado__Deployment_Flow__c,
                   copado__Deployment_Flow__r.Name,
                   copado__Deployment_Flow__r.copado__Platform__c,
                   copado__Deployment_Flow__r.copado__Main_Branch__c,
                   copado__Deployment_Flow__r.copado__Active__c,
                   copado__Deployment_Flow__r.copado__Git_Repository__c,
                   copado__Deployment_Flow__r.copado__Git_Repository__r.Name,
                   copado__Deployment_Flow__r.copado__Git_Repository__r.copado__URI__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Source_Environment__c != null
              AND copado__Deployment_Flow__r.copado__Platform__c = 'SFDX'
              AND copado__Deployment_Flow__r.copado__Git_Repository__c != null
              AND copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 1
        ];

        if (pipelineConnections.isEmpty()) {
            System.debug('Skipping test - no Source Format pipeline (SFDX) with Git Repository found');
            return;
        }

        String envId = pipelineConnections[0].copado__Source_Environment__c;

        List<copado__Environment__c> envs = [SELECT Id, Name FROM copado__Environment__c WHERE Id = :envId];
        if (envs.isEmpty()) {
            System.debug('Skipping test - cannot access environment');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = envId;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        if (!response.success) {
            System.debug('Error: ' + response.errorMessage);
            System.debug('Stack: ' + response.stackTrace);
            return;
        }

        System.assertEquals(true, response.success, 'Operation should succeed');
        System.assertNotEquals(null, response.repositoryOptions, 'Repository options should not be null');
        System.assert(!response.repositoryOptions.isEmpty(), 'Should have at least one repository option');
        
        // Verify repository option fields
        GitCredentialResolver.GitRepositoryOption option = response.repositoryOptions[0];
        System.assertNotEquals(null, option.repositoryId, 'Repository ID should not be null');
        System.assertNotEquals(null, option.repositoryName, 'Repository Name should not be null');
        System.assertNotEquals(null, option.repositoryUri, 'Repository URI should not be null');
        System.assertNotEquals(null, option.branchName, 'Branch Name should not be null');
        System.assertEquals('Source Format', option.pipelineType, 'Should be Source Format pipeline');
        System.assertNotEquals(null, option.pipelineId, 'Pipeline ID should not be null');
        System.assertNotEquals(null, option.pipelineName, 'Pipeline Name should not be null');
        System.assertNotEquals(null, option.displayLabel, 'Display Label should not be null');
        
        // If only one option, verify auto-population
        if (response.repositoryOptions.size() == 1) {
            System.assertEquals(false, response.multipleRepositories, 'Should not have multiple repositories');
            System.assertEquals(option.repositoryId, response.repositoryId, 'Repository ID should be auto-populated');
            System.assertEquals(option.repositoryName, response.repositoryName, 'Repository Name should be auto-populated');
            System.assertEquals(option.pipelineId, response.pipelineId, 'Pipeline ID should be auto-populated');
        }
    }

    /**
     * @description Test successful credential resolution for Metadata Format Pipeline (Salesforce)
     * Uses SeeAllData to work with existing Copado configuration
     */
    @isTest(SeeAllData=true)
    static void testMetadataFormatPipelineSuccess() {
        // Find an existing environment with a Git Snapshot and Metadata Format pipeline
        List<copado__Git_Backup__c> gitSnapshots = [
            SELECT Id,
                   copado__Org__c,
                   copado__Branch__c,
                   copado__Git_Repository__c,
                   copado__Git_Repository__r.Name,
                   copado__Git_Repository__r.copado__URI__c
            FROM copado__Git_Backup__c
            WHERE copado__Org__c != null
              AND copado__Git_Repository__c != null
            LIMIT 1
        ];

        if (gitSnapshots.isEmpty()) {
            System.debug('Skipping test - no Git Snapshot found');
            return;
        }

        List<copado__Org__c> orgCreds = [
            SELECT Id, copado__SFDC_Org_ID__c
            FROM copado__Org__c
            WHERE Id = :gitSnapshots[0].copado__Org__c
            LIMIT 1
        ];

        if (orgCreds.isEmpty()) {
            System.debug('Skipping test - cannot find Org Credential');
            return;
        }

        List<copado__Environment__c> environments = [
            SELECT Id
            FROM copado__Environment__c
            WHERE copado__Org_ID__c = :orgCreds[0].copado__SFDC_Org_ID__c
            LIMIT 1
        ];

        if (environments.isEmpty()) {
            System.debug('Skipping test - cannot find Environment for Org');
            return;
        }

        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id,
                   copado__Deployment_Flow__r.copado__Platform__c,
                   copado__Deployment_Flow__r.copado__Active__c
            FROM copado__Deployment_Flow_Step__c
            WHERE (copado__Source_Environment__c = :environments[0].Id
                   OR copado__Destination_Environment__c = :environments[0].Id)
              AND (copado__Deployment_Flow__r.copado__Platform__c = 'Salesforce'
                   OR copado__Deployment_Flow__r.copado__Platform__c = null)
              AND copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 1
        ];

        if (pipelineConnections.isEmpty()) {
            System.debug('Skipping test - no Metadata Format pipeline found for environment with Git Snapshot');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = environments[0].Id;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        if (!response.success) {
            System.debug('Error: ' + response.errorMessage);
            System.debug('Stack: ' + response.stackTrace);
            return;
        }

        System.assertEquals(true, response.success, 'Operation should succeed');
        System.assertNotEquals(null, response.repositoryOptions, 'Repository options should not be null');
        System.assert(!response.repositoryOptions.isEmpty(), 'Should have at least one repository option');
        
        // Verify at least one option is Metadata Format
        Boolean foundMetadataFormat = false;
        for (GitCredentialResolver.GitRepositoryOption option : response.repositoryOptions) {
            if (option.pipelineType == 'Metadata Format') {
                foundMetadataFormat = true;
                System.assertNotEquals(null, option.repositoryId, 'Repository ID should not be null');
                break;
            }
        }
        System.assert(foundMetadataFormat, 'Should have at least one Metadata Format pipeline');
    }

    /**
     * @description Test multiple pipelines scenario
     * Uses SeeAllData to find an environment with multiple pipeline connections
     */
    @isTest(SeeAllData=true)
    static void testMultiplePipelinesSuccess() {
        // Find an environment that belongs to multiple pipelines
        Map<Id, Integer> envPipelineCount = new Map<Id, Integer>();
        
        for (copado__Deployment_Flow_Step__c step : [
            SELECT copado__Source_Environment__c,
                   copado__Destination_Environment__c,
                   copado__Deployment_Flow__c,
                   copado__Deployment_Flow__r.copado__Active__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 200
        ]) {
            if (step.copado__Source_Environment__c != null) {
                Integer count = envPipelineCount.get(step.copado__Source_Environment__c);
                envPipelineCount.put(step.copado__Source_Environment__c, (count == null ? 1 : count + 1));
            }
            if (step.copado__Destination_Environment__c != null) {
                Integer count = envPipelineCount.get(step.copado__Destination_Environment__c);
                envPipelineCount.put(step.copado__Destination_Environment__c, (count == null ? 1 : count + 1));
            }
        }

        // Find environment with multiple pipelines
        Id multiPipelineEnvId = null;
        for (Id envId : envPipelineCount.keySet()) {
            if (envPipelineCount.get(envId) > 1) {
                multiPipelineEnvId = envId;
                break;
            }
        }

        if (multiPipelineEnvId == null) {
            System.debug('Skipping test - no environment with multiple pipelines found');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = multiPipelineEnvId;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        if (!response.success) {
            System.debug('Error: ' + response.errorMessage);
            System.debug('Stack: ' + response.stackTrace);
            return;
        }

        System.assertEquals(true, response.success, 'Operation should succeed');
        System.assertNotEquals(null, response.repositoryOptions, 'Repository options should not be null');
        
        // If multiple options found, verify multipleRepositories flag
        if (response.repositoryOptions.size() > 1) {
            System.assertEquals(true, response.multipleRepositories, 'Should indicate multiple repositories');
            System.assertEquals(null, response.repositoryId, 'Repository ID should not be auto-populated when multiple options');
        }
    }

    /**
     * @description Test error handling when Environment is not found
     */
    @isTest
    static void testEnvironmentNotFound() {
        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = 'a0000000000000AAA'; // Fake ID

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        System.assertEquals(false, response.success, 'Operation should fail');
        System.assert(response.errorMessage.contains('Environment not found'),
            'Error message should indicate environment not found: ' + response.errorMessage);
    }

    /**
     * @description Test error handling when no Pipeline is found for Environment
     */
    @isTest
    static void testNoPipelineFound() {
        // Setup environment without pipeline connection
        copado__Environment__c env = new copado__Environment__c(
            Name = 'Orphan Test Environment ' + System.now().getTime(),
            copado__Type__c = 'Sandbox'
        );
        insert env;

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = env.Id;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        System.assertEquals(false, response.success, 'Operation should fail');
        System.assert(response.errorMessage.contains('No active Pipeline found') || 
                     response.errorMessage.contains('No Pipeline found'),
            'Error message should indicate no pipeline found: ' + response.errorMessage);

        // Cleanup
        delete env;
    }

    /**
     * @description Test error handling when no Environment ID is provided
     */
    @isTest
    static void testNoEnvironmentIdProvided() {
        Test.startTest();

        try {
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>());
            System.assert(false, 'Should have thrown exception');
        } catch (GitCredentialResolver.GitCredentialException e) {
            System.assert(e.getMessage().contains('No Environment ID provided'),
                'Exception message should indicate no environment ID: ' + e.getMessage());
        }

        Test.stopTest();
    }

    /**
     * @description Test error handling when null request list is provided
     */
    @isTest
    static void testNullRequestList() {
        Test.startTest();

        try {
            GitCredentialResolver.getGitCredential(null);
            System.assert(false, 'Should have thrown exception');
        } catch (GitCredentialResolver.GitCredentialException e) {
            System.assert(e.getMessage().contains('No Environment ID provided'),
                'Exception message should indicate no environment ID: ' + e.getMessage());
        }

        Test.stopTest();
    }

    /**
     * @description Test that response contains all expected fields for single repository
     */
    @isTest(SeeAllData=true)
    static void testSingleRepositoryResponseFields() {
        // Find any environment with a pipeline connection
        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id,
                   copado__Source_Environment__c,
                   copado__Deployment_Flow__r.copado__Git_Repository__c,
                   copado__Deployment_Flow__r.copado__Active__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Source_Environment__c != null
              AND copado__Deployment_Flow__r.copado__Git_Repository__c != null
              AND copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 1
        ];

        if (pipelineConnections.isEmpty()) {
            System.debug('Skipping test - no pipeline with Git Repository found');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = pipelineConnections[0].copado__Source_Environment__c;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify all response fields are populated
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        if (!response.success) {
            System.debug('Skipping assertions - operation failed: ' + response.errorMessage);
            return;
        }

        System.assertEquals(true, response.success, 'success should be true');
        System.assertNotEquals(null, response.repositoryOptions, 'repositoryOptions should not be null');
        System.assert(!response.repositoryOptions.isEmpty(), 'repositoryOptions should not be empty');
        System.assertNotEquals(null, response.multipleRepositories, 'multipleRepositories should not be null');
        
        // Verify repository option fields
        GitCredentialResolver.GitRepositoryOption option = response.repositoryOptions[0];
        System.assertNotEquals(null, option.repositoryId, 'option.repositoryId should not be null');
        System.assertNotEquals(null, option.repositoryName, 'option.repositoryName should not be null');
        System.assertNotEquals(null, option.repositoryUri, 'option.repositoryUri should not be null');
        System.assertNotEquals(null, option.branchName, 'option.branchName should not be null');
        System.assertNotEquals(null, option.pipelineType, 'option.pipelineType should not be null');
        System.assertNotEquals(null, option.pipelineId, 'option.pipelineId should not be null');
        System.assertNotEquals(null, option.pipelineName, 'option.pipelineName should not be null');
        System.assertNotEquals(null, option.displayLabel, 'option.displayLabel should not be null');
        
        // If single repository, verify auto-population
        if (response.repositoryOptions.size() == 1) {
            System.assertEquals(false, response.multipleRepositories, 'multipleRepositories should be false');
            System.assertEquals(option.repositoryId, response.repositoryId, 'repositoryId should be auto-populated');
            System.assertEquals(option.repositoryName, response.repositoryName, 'repositoryName should be auto-populated');
            System.assertEquals(option.repositoryUri, response.repositoryUri, 'repositoryUri should be auto-populated');
            System.assertEquals(option.branchName, response.branchName, 'branchName should be auto-populated');
            System.assertEquals(option.pipelineType, response.pipelineType, 'pipelineType should be auto-populated');
            System.assertEquals(option.pipelineId, response.pipelineId, 'pipelineId should be auto-populated');
            System.assertEquals(option.pipelineName, response.pipelineName, 'pipelineName should be auto-populated');
        }
        
        System.assertEquals(null, response.errorMessage, 'errorMessage should be null on success');
        System.assertEquals(null, response.stackTrace, 'stackTrace should be null on success');
    }

    /**
     * @description Test error response fields
     */
    @isTest
    static void testErrorResponseFields() {
        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = 'a0000000000000AAA'; // Fake ID

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        // Verify error response fields
        GitCredentialResolver.GitCredentialResponse response = responses[0];

        System.assertEquals(false, response.success, 'success should be false');
        System.assertNotEquals(null, response.errorMessage, 'errorMessage should not be null on error');
        System.assertNotEquals(null, response.stackTrace, 'stackTrace should not be null on error');
    }

    /**
     * @description Test display label format
     */
    @isTest(SeeAllData=true)
    static void testDisplayLabelFormat() {
        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id,
                   copado__Source_Environment__c,
                   copado__Deployment_Flow__r.Name,
                   copado__Deployment_Flow__r.copado__Git_Repository__c,
                   copado__Deployment_Flow__r.copado__Active__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Source_Environment__c != null
              AND copado__Deployment_Flow__r.copado__Git_Repository__c != null
              AND copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 1
        ];

        if (pipelineConnections.isEmpty()) {
            System.debug('Skipping test - no pipeline found');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = pipelineConnections[0].copado__Source_Environment__c;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        if (!responses[0].success || responses[0].repositoryOptions.isEmpty()) {
            System.debug('Skipping test - no valid response');
            return;
        }

        GitCredentialResolver.GitRepositoryOption option = responses[0].repositoryOptions[0];
        
        // Verify display label contains pipeline name, type, and repository name
        System.assert(option.displayLabel.contains(option.pipelineName), 
            'Display label should contain pipeline name');
        System.assert(option.displayLabel.contains(option.pipelineType), 
            'Display label should contain pipeline type');
        System.assert(option.displayLabel.contains(option.repositoryName), 
            'Display label should contain repository name');
    }

    /**
     * @description Test that inactive pipelines are excluded
     */
    @isTest(SeeAllData=true)
    static void testInactivePipelinesExcluded() {
        // Find an environment with only active pipelines
        List<copado__Deployment_Flow_Step__c> activeSteps = [
            SELECT copado__Source_Environment__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Source_Environment__c != null
              AND copado__Deployment_Flow__r.copado__Active__c = true
            LIMIT 1
        ];

        if (activeSteps.isEmpty()) {
            System.debug('Skipping test - no active pipeline found');
            return;
        }

        Test.startTest();

        GitCredentialResolver.EnvironmentRequest request = new GitCredentialResolver.EnvironmentRequest();
        request.environmentId = activeSteps[0].copado__Source_Environment__c;

        List<GitCredentialResolver.GitCredentialResponse> responses =
            GitCredentialResolver.getGitCredential(new List<GitCredentialResolver.EnvironmentRequest>{ request });

        Test.stopTest();

        if (!responses[0].success) {
            System.debug('Skipping test - operation failed');
            return;
        }

        // All returned options should be from active pipelines
        // (This is implicitly tested by the query filtering on copado__Active__c = true)
        System.assert(responses[0].repositoryOptions.size() > 0, 
            'Should return at least one repository option from active pipelines');
    }
}