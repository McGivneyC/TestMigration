public class CreateUserStory {
    public static void createUserStories() {
        List<copado__User_Story__c> userStories = new List<copado__User_Story__c>();

        for (Integer i = 1; i <= 300; i++) {
            copado__User_Story__c userStory = new copado__User_Story__c();
            userStory.copado__Functional_Specifications__c = 'Description for User Story ' + i;
            userStory.copado__Project__c = 'a0z5e000000COcWAAW';
            userStory.copado__Org_Credential__c = 'a0v5e000000GKI0AAO';
            // Set other necessary fields and custom fields as required
            // Example: userStory.copado__Project__c = 'YourProjectId';
            // Example: userStory.copado__Sprint__c = 'YourSprintId';

            userStories.add(userStory);
        }

        try {
            insert userStories; // Insert all user stories in one DML operation
            System.debug('Successfully created 300 user stories.');
        } catch (Exception e) {
            System.debug('Error creating user stories: ' + e.getMessage());
        }
    }
}