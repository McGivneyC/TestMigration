public class CheckExcludedMetadataTypes {
    @InvocableMethod(label='Check Excluded Metadata Types' description='Checks for excluded metadata types in a User Story')
    public static List<String> execute(List<ID> userStoryIds) {
        if (userStoryIds.isEmpty()) {
            return new List<String>{'Error: No User Story ID provided'};
        }
        
        ID userStoryId = userStoryIds[0];
        List<String> results = new List<String>();
        
        try {
            // Query for metadata items associated with the User Story
            List<copado__User_Story_Metadata__c> metadataItems = [
                SELECT copado__Metadata_API_Name__c 
                FROM copado__User_Story_Metadata__c 
                WHERE copado__User_Story__c = :userStoryId
            ];
            
            // Define excluded metadata types
            Set<String> excludedTypes = new Set<String>{'CaseSettings'};
            
            // Check for excluded types
            for (copado__User_Story_Metadata__c item : metadataItems) {
                if (excludedTypes.contains(item.copado__Metadata_API_Name__c)) {
                    results.add('Error: Excluded metadata type ' + item.copado__Metadata_API_Name__c + ' found');
                    return results;
                }
            }
            
            results.add('Success: No excluded metadata types found');
        } catch (Exception e) {
            results.add('Error: ' + e.getMessage());
        }
        
        return results;
    }
}