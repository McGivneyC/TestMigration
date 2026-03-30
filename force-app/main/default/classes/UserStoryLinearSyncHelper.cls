public with sharing class UserStoryLinearSyncHelper {
    
    /**
     * Determines if a User Story should be synced to Linear
     * @param story The User Story record
     * @param oldMap Map of old User Story records (null for insert)
     * @return true if the record should be synced to Linear
     */
    public static Boolean shouldSyncToLinear(
        copado__User_Story__c story, 
        Map<Id, copado__User_Story__c> oldMap
    ) {
        // Prevent sync loops - don't sync if recently synced from Linear
        if (story.Last_Synced_From_Linear__c != null && 
            story.Last_Synced_From_Linear__c > System.now().addSeconds(-10)) {
            return false;
        }
        
        // For inserts, always sync
        if (oldMap == null) {
            return true;
        }
        
        // For updates, only sync if specific fields changed
        copado__User_Story__c oldStory = oldMap.get(story.Id);
        if (oldStory == null) {
            return true;
        }
        
        return hasRelevantFieldsChanged(story, oldStory);
    }
    
    /**
     * Checks if any fields relevant to Linear have changed
     * @param newStory The new User Story record
     * @param oldStory The old User Story record
     * @return true if relevant fields have changed
     */
    private static Boolean hasRelevantFieldsChanged(
        copado__User_Story__c newStory,
        copado__User_Story__c oldStory
    ) {
        return newStory.copado__User_Story_Title__c != oldStory.copado__User_Story_Title__c ||
               newStory.copado__Status__c != oldStory.copado__Status__c ||
               newStory.Description__c != oldStory.Description__c ||
               newStory.copado__Priority__c != oldStory.copado__Priority__c;
    }
}