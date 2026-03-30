public class CommitUsingXMLFile {
    // Wrapper class to return results to the flow
    public class FlowResponse {
        @InvocableVariable(label='Success' description='Indicates if the operation was successful')
        public Boolean isSuccess;
        @InvocableVariable(label='Message' description='Status or error message')
        public String message;
        @InvocableVariable(label='Changes Count' description='Number of metadata changes processed')
        public Integer changesCount;
        public FlowResponse(Boolean success, String msg, Integer count) {
            this.isSuccess = success;
            this.message = msg;
            this.changesCount = count != null ? count : 0;
        }
    }

    // Inner wrapper class to hold multiple variables
    public class FlowInputWrapper {
        @InvocableVariable(label='Content Document Id Label' description='Description for first variable' required=true)
        public String contentDocumentId;
        @InvocableVariable(label='User Story Id Label' description='Description for second variable' required=true)
        public String userStoryId;
    }

    // This method is invoked by the Salesforce Flow
    @InvocableMethod(label='Process Uploaded File' description='Performs an action on the uploaded file.')
    public static List<FlowResponse> processFiles(List<FlowInputWrapper> requestList) {
        
        FlowInputWrapper input = requestList[0];
        // Access your variables
        String contentDocumentId = input.contentDocumentId;
        String userStoryId = input.userStoryId;
        // Implement your Apex logic using var1 and var2

        try {
            // Query for ContentVersion with bounds checking
            List<ContentVersion> contentVersions = [
                SELECT Checksum, ContentBodyId, ContentDocumentId, ContentLocation,
                       Title, VersionData, VersionNumber FROM ContentVersion  WHERE ContentDocumentId = :contentDocumentId  LIMIT 1 ];
            // Check if query returned results
            if (contentVersions.isEmpty()) {
                return new List<FlowResponse>{ new FlowResponse(false, 'No ContentVersion found for the provided ContentDocument IDs', 0) };
            }
            ContentVersion cv = contentVersions[0];
            // Check if VersionData exists
            if (cv.VersionData == null) {
                return new List<FlowResponse>{ new FlowResponse(false, 'No file data found in ContentVersion', 0) };
            }
            // Simplified blob-to-string conversion
            String xmlContent = cv.VersionData.toString();
            // Parse XML and create changes
            List<copado.CommitAction.Change> changes = parseXMLContent(xmlContent);
            if (changes.isEmpty()) {
                return new List<FlowResponse>{ new FlowResponse(false, 'No metadata changes found in XML file', 0)  };
            }
            // Get the appropriate base branch
            String baseBranch = getBaseBranch(userStoryId);
            // Create and execute commit request
            copado.CommitAction.Request request = new copado.CommitAction.Request();
            request.userStoryId = userStoryId;
            request.changes = changes;
            request.commitId = '';
            request.message = 'Automated commit from XML file';
            request.baseBranch = baseBranch;
            request.recreateFeatureBranch = true;
            request.executeCommit = true;
            copado.CommitAction.commitChanges(new List<copado.CommitAction.Request> {request});
            return new List<FlowResponse>{ new FlowResponse(true, 'Successfully processed ' + changes.size() + ' metadata changes', changes.size())  };
        } catch (Exception e) {
            return new List<FlowResponse>{ new FlowResponse(false, 'Error processing uploaded file: ' + e.getMessage(), 0) };
        }
    }
    
    // Helper method to determine the appropriate base branch
    private static String getBaseBranch(String userStoryId) {
        try {
            // First, get the user story and its release information
            List<copado__User_Story__c> userStories = [
                SELECT Id, copado__Release__c, copado__Base_Branch__c FROM copado__User_Story__c  WHERE Id = :userStoryId  LIMIT 1 ];
            
            if (userStories.isEmpty()) {
                return 'main'; // Default fallback
            }
            
            copado__User_Story__c userStory = userStories[0];
            // If user story has a release, check if the release has a base branch
            if (userStory.copado__Release__c != null) {
                List<copado__Release__c> releases = [
                    SELECT Id, copado__Base_Branch__c
                    FROM copado__Release__c
                    WHERE Id = :userStory.copado__Release__c
                    LIMIT 1
                ];
                if (!releases.isEmpty() && String.isNotBlank(releases[0].copado__Base_Branch__c)) {
                    return releases[0].copado__Base_Branch__c;
                }
            }
            // If release doesn't have a base branch, use user story's base branch
            if (String.isNotBlank(userStory.copado__Base_Branch__c)) {
                return userStory.copado__Base_Branch__c;
            }
        } catch (Exception e) {
            // Silent failure - fall back to default
        }
        // Ultimate fallback
        return 'main';
    }
    // Helper method to parse XML content and create changes
    private static List<copado.CommitAction.Change> parseXMLContent(String xmlContent) {
        List<copado.CommitAction.Change> changes = new List<copado.CommitAction.Change>();
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlContent);
            Dom.XmlNode rootElement = doc.getRootElement();
            if (rootElement == null) {
                return changes;
            }
            List<Dom.XmlNode> metadataTypes = rootElement.getChildElements();
            for (Dom.XmlNode metadataType : metadataTypes) {
                if (metadataType.getName() == 'types') {
                    // Get metadata type name with null check
                    Dom.XmlNode nameElement = metadataType.getChildElement('name', 'http://soap.sforce.com/2006/04/metadata');
                    if (nameElement == null) {
                        continue;
                    }
                    String metadataTypeName = nameElement.getText();
                    if (String.isBlank(metadataTypeName)) {
                        continue;
                    }
                    // Process members
                    List<Dom.XmlNode> metadataMembers = metadataType.getChildElements();
                    for (Dom.XmlNode metadataMember : metadataMembers) {
                        if (metadataMember.getName() == 'members') {
                            String memberText = metadataMember.getText();
                            if (String.isNotBlank(memberText)) {
                                copado.CommitAction.Change change = new copado.CommitAction.Change();
                                change.a = 'Add';
                                change.n = memberText;
                                change.t = metadataTypeName;
                                change.c = 'SFDX';
                                changes.add(change);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Silent failure - return empty list
        }
        return changes;
    }
}