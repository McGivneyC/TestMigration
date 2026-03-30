/**
 * @description Resolves Git Repository credentials for an Environment
 * Supports both Metadata Format and Source Format Pipelines
 *
 * Usage: Called from a Flow on the Environment record to get Git credentials
 * for running SFDX Code Analyzer or other Functions
 *
 * @author CopadoAI
 * @date 2025-12-17
 * @version 1.0 - Original working version (RESTORED)
 */
public with sharing class GitCredentialResolver {

    @InvocableMethod(
        label='Get Git Credential for Environment'
        description='Resolves Git Repository credential for Metadata or Source Format Pipeline'
        category='Copado'
    )
    public static List<GitCredentialResponse> getGitCredential(List<EnvironmentRequest> requests) {
        List<GitCredentialResponse> responses = new List<GitCredentialResponse>();

        if (requests == null || requests.isEmpty()) {
            throw new GitCredentialException('No Environment ID provided');
        }

        String environmentId = requests[0].environmentId;

        try {
            PipelineInfo pipelineInfo = getPipelineInfo(environmentId);
            GitRepositoryInfo gitRepoInfo = getGitRepositoryInfo(pipelineInfo);

            GitCredentialResponse response = new GitCredentialResponse();
            response.repositoryId = gitRepoInfo.repositoryId;
            response.repositoryName = gitRepoInfo.repositoryName;
            response.repositoryUri = gitRepoInfo.repositoryUri;
            response.branchName = gitRepoInfo.branchName;
            response.pipelineType = pipelineInfo.pipelineType;
            response.success = true;

            responses.add(response);

        } catch (Exception e) {
            GitCredentialResponse errorResponse = new GitCredentialResponse();
            errorResponse.success = false;
            errorResponse.errorMessage = e.getMessage();
            errorResponse.stackTrace = e.getStackTraceString();
            responses.add(errorResponse);
        }

        return responses;
    }

    private static PipelineInfo getPipelineInfo(String environmentId) {
        List<copado__Environment__c> environments = [
            SELECT Id, Name, copado__Type__c, copado__Org_ID__c
            FROM copado__Environment__c
            WHERE Id = :environmentId
            LIMIT 1
        ];

        if (environments.isEmpty()) {
            throw new GitCredentialException('Environment not found: ' + environmentId);
        }

        copado__Environment__c env = environments[0];

        // Get pipeline connection for this environment
        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id,
                   copado__Deployment_Flow__c,
                   copado__Deployment_Flow__r.Name,
                   copado__Deployment_Flow__r.copado__Platform__c,
                   copado__Deployment_Flow__r.copado__Main_Branch__c,
                   copado__Deployment_Flow__r.copado__Active__c,
                   copado__Branch__c,
                   copado__Destination_Branch__c,
                   copado__Source_Environment__c,
                   copado__Destination_Environment__c
            FROM copado__Deployment_Flow_Step__c
            WHERE (copado__Source_Environment__c = :environmentId
                OR copado__Destination_Environment__c = :environmentId)
              AND copado__Deployment_Flow__r.copado__Active__c = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (pipelineConnections.isEmpty()) {
            throw new GitCredentialException('No active Pipeline found for Environment: ' + env.Name);
        }

        copado__Deployment_Flow_Step__c pipeConn = pipelineConnections[0];

        PipelineInfo info = new PipelineInfo();
        info.pipelineId = pipeConn.copado__Deployment_Flow__c;
        info.pipelineName = pipeConn.copado__Deployment_Flow__r.Name;
        info.environmentId = environmentId;
        info.environmentName = env.Name;
        info.environmentType = env.copado__Type__c;
        info.orgId = env.copado__Org_ID__c;

        // Platform 'Salesforce' = Metadata Format (classic Copado with Git Snapshots)
        // Platform 'SFDX' = Source Format (2nd gen with Pipeline Git Repository)
        String platform = pipeConn.copado__Deployment_Flow__r.copado__Platform__c;
        info.pipelineType = (platform == 'SFDX') ? 'Source Format' : 'Metadata Format';
        info.mainBranch = pipeConn.copado__Deployment_Flow__r.copado__Main_Branch__c;

        if (pipeConn.copado__Source_Environment__c == environmentId) {
            info.environmentBranch = pipeConn.copado__Branch__c;
        } else {
            info.environmentBranch = pipeConn.copado__Destination_Branch__c;
        }

        return info;
    }

    private static GitRepositoryInfo getGitRepositoryInfo(PipelineInfo pipelineInfo) {
        GitRepositoryInfo gitInfo = new GitRepositoryInfo();

        if (pipelineInfo.pipelineType == 'Source Format') {
            gitInfo = getGitRepoFromPipeline(pipelineInfo);
        } else {
            gitInfo = getGitRepoFromSnapshot(pipelineInfo);
        }

        return gitInfo;
    }

    private static GitRepositoryInfo getGitRepoFromPipeline(PipelineInfo pipelineInfo) {
        GitRepositoryInfo gitInfo = new GitRepositoryInfo();

        List<copado__Deployment_Flow__c> pipelines = [
            SELECT Id,
                   copado__Git_Repository__c,
                   copado__Git_Repository__r.Name,
                   copado__Git_Repository__r.copado__URI__c
            FROM copado__Deployment_Flow__c
            WHERE Id = :pipelineInfo.pipelineId
            LIMIT 1
        ];

        if (pipelines.isEmpty() || pipelines[0].copado__Git_Repository__c == null) {
            throw new GitCredentialException('No Git Repository found on Pipeline: ' + pipelineInfo.pipelineName);
        }

        copado__Deployment_Flow__c pipeline = pipelines[0];

        gitInfo.repositoryId = pipeline.copado__Git_Repository__c;
        gitInfo.repositoryName = pipeline.copado__Git_Repository__r.Name;
        gitInfo.repositoryUri = pipeline.copado__Git_Repository__r.copado__URI__c;
        gitInfo.branchName = String.isNotBlank(pipelineInfo.environmentBranch)
            ? pipelineInfo.environmentBranch
            : pipelineInfo.mainBranch;

        return gitInfo;
    }

    private static GitRepositoryInfo getGitRepoFromSnapshot(PipelineInfo pipelineInfo) {
        GitRepositoryInfo gitInfo = new GitRepositoryInfo();

        // First, try to find Org Credential by matching SFDC_Org_ID__c with Environment's Org_ID__c
        List<copado__Org__c> credentials = [
            SELECT Id, Name, copado__SFDC_Org_ID__c
            FROM copado__Org__c
            WHERE copado__SFDC_Org_ID__c = :pipelineInfo.orgId
            LIMIT 1
        ];

        // If not found by Org ID, try to find by Environment Name match
        if (credentials.isEmpty()) {
            credentials = [
                SELECT Id, Name, copado__SFDC_Org_ID__c
                FROM copado__Org__c
                WHERE Name = :pipelineInfo.environmentName
                LIMIT 1
            ];
        }

        // If still not found, look for any Org Credential that has a Git Snapshot
        // and is associated with this environment through Git Snapshot
        if (credentials.isEmpty()) {
            List<copado__Git_Backup__c> gitSnapshotsForEnv = [
                SELECT Id, copado__Org__c, copado__Org__r.Name
                FROM copado__Git_Backup__c
                WHERE copado__Org__r.copado__Environment__c = :pipelineInfo.environmentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!gitSnapshotsForEnv.isEmpty()) {
                credentials = [
                    SELECT Id, Name, copado__SFDC_Org_ID__c
                    FROM copado__Org__c
                    WHERE Id = :gitSnapshotsForEnv[0].copado__Org__c
                    LIMIT 1
                ];
            }
        }

        if (credentials.isEmpty()) {
            throw new GitCredentialException(
                'No Org Credential found for Environment: ' + pipelineInfo.environmentName +
                ' (Org ID: ' + pipelineInfo.orgId + '). ' +
                'Please ensure the Environment has an Org Credential with a Git Snapshot configured.'
            );
        }

        String credentialId = credentials[0].Id;

        List<copado__Git_Backup__c> gitSnapshots = [
            SELECT Id,
                   Name,
                   copado__Git_Repository__c,
                   copado__Git_Repository__r.Name,
                   copado__Git_Repository__r.copado__URI__c,
                   copado__Branch__c
            FROM copado__Git_Backup__c
            WHERE copado__Org__c = :credentialId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (gitSnapshots.isEmpty()) {
            throw new GitCredentialException(
                'No Git Snapshot found for Environment: ' + pipelineInfo.environmentName +
                ' (Org Credential: ' + credentials[0].Name + '). ' +
                'Please create a Git Snapshot for this environment.'
            );
        }

        copado__Git_Backup__c gitSnapshot = gitSnapshots[0];

        if (gitSnapshot.copado__Git_Repository__c == null) {
            throw new GitCredentialException('Git Snapshot has no Git Repository configured');
        }

        gitInfo.repositoryId = gitSnapshot.copado__Git_Repository__c;
        gitInfo.repositoryName = gitSnapshot.copado__Git_Repository__r.Name;
        gitInfo.repositoryUri = gitSnapshot.copado__Git_Repository__r.copado__URI__c;
        gitInfo.branchName = gitSnapshot.copado__Branch__c;

        return gitInfo;
    }

    // ========== INNER CLASSES ==========

    public class EnvironmentRequest {
        @InvocableVariable(required=true label='Environment ID')
        public String environmentId;
    }

    public class GitCredentialResponse {
        @InvocableVariable(label='Repository ID')
        public String repositoryId;

        @InvocableVariable(label='Repository Name')
        public String repositoryName;

        @InvocableVariable(label='Repository URI')
        public String repositoryUri;

        @InvocableVariable(label='Branch Name')
        public String branchName;

        @InvocableVariable(label='Pipeline Type')
        public String pipelineType;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Stack Trace')
        public String stackTrace;
    }

    private class PipelineInfo {
        public String pipelineId;
        public String pipelineName;
        public String environmentId;
        public String environmentName;
        public String environmentType;
        public String environmentBranch;
        public String pipelineType;
        public String mainBranch;
        public String orgId;
    }

    private class GitRepositoryInfo {
        public String repositoryId;
        public String repositoryName;
        public String repositoryUri;
        public String branchName;
    }

    public class GitCredentialException extends Exception {}
}