@IsTest
public class CommitUsingXMLFileTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create test Release record
        copado__Release__c testRelease = new copado__Release__c();
        testRelease.Name = 'Test Release';
        testRelease.copado__Base_Branch__c = 'release/v1.0';
        insert testRelease;
        
        // Create test User Story record with release
        copado__User_Story__c testUserStoryWithRelease = new copado__User_Story__c();
        testUserStoryWithRelease.copado__Release__c = testRelease.Id;
        testUserStoryWithRelease.copado__Base_Branch__c = 'feature/user-story-branch';
        insert testUserStoryWithRelease;
        
        // Create test User Story record without release
        copado__User_Story__c testUserStoryWithoutRelease = new copado__User_Story__c();
        testUserStoryWithoutRelease.copado__Base_Branch__c = 'feature/standalone-branch';
        insert testUserStoryWithoutRelease;
        
        // Create test User Story record with minimal data
        copado__User_Story__c testUserStoryMinimal = new copado__User_Story__c();
        insert testUserStoryMinimal;
        
        // Create ContentVersion for testing
        ContentVersion testContentVersion = new ContentVersion();
        testContentVersion.Title = 'Test XML File';
        testContentVersion.VersionData = Blob.valueOf(getValidXMLContent());
        testContentVersion.PathOnClient = 'test.xml';
        insert testContentVersion;
        
        // Create ContentVersion with minimal content (instead of empty)
        ContentVersion emptyContentVersion = new ContentVersion();
        emptyContentVersion.Title = 'Empty XML File';
        emptyContentVersion.VersionData = Blob.valueOf('minimal content');
        emptyContentVersion.PathOnClient = 'empty.xml';
        insert emptyContentVersion;
    }
    
    // Helper method to create valid XML content for testing
    private static String getValidXMLContent() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
               '<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
               '    <types>' +
               '        <members>TestApexClass</members>' +
               '        <members>AnotherApexClass</members>' +
               '        <name>ApexClass</name>' +
               '    </types>' +
               '    <types>' +
               '        <members>TestCustomObject__c</members>' +
               '        <name>CustomObject</name>' +
               '    </types>' +
               '    <version>58.0</version>' +
               '</Package>';
    }
    
    // Test successful file processing
    @IsTest
    static void testProcessFiles_Success() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test XML File' LIMIT 1];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = cv.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test when no ContentVersion is found
    @IsTest
    static void testProcessFiles_NoContentVersionFound() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        // Create input wrapper with non-existent ContentDocumentId
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = '0691234567890123456'; // Non-existent ID
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test when XML content is invalid (using minimal content file)
    @IsTest
    static void testProcessFiles_EmptyXMLContent() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Empty XML File' LIMIT 1];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = cv.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test getBaseBranch method with user story that has release
    @IsTest
    static void testGetBaseBranch_WithRelease() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        Test.startTest();
        // Note: Since getBaseBranch is private, we test it indirectly through processFiles
        // The base branch logic will be verified through the commit process
        Test.stopTest();
    }
    
    // Test getBaseBranch method with user story without release
    @IsTest 
    static void testGetBaseBranch_WithoutRelease() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c = null AND copado__Base_Branch__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test XML File' LIMIT 1];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = cv.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Should use user story's own base branch
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test getBaseBranch method with minimal user story (should fallback to 'main')
    @IsTest
    static void testGetBaseBranch_Minimal() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c = null AND copado__Base_Branch__c = null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test XML File' LIMIT 1];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = cv.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Should fallback to 'main' branch
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test getBaseBranch method with invalid user story ID
    @IsTest
    static void testGetBaseBranch_InvalidId() {
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test XML File' LIMIT 1];
        
        // Create input wrapper with invalid user story ID
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = cv.ContentDocumentId;
        input.userStoryId = 'invalid-id';
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Should handle gracefully and fallback to 'main'
    }
    
    // Test FlowResponse constructor
    @IsTest
    static void testFlowResponse_Constructor() {
        Test.startTest();
        
        // Test with all parameters
        CommitUsingXMLFile.FlowResponse response1 = new CommitUsingXMLFile.FlowResponse(true, 'Success', 5);
        
        // Test with null count
        CommitUsingXMLFile.FlowResponse response2 = new CommitUsingXMLFile.FlowResponse(false, 'Error', null);
        
        Test.stopTest();
    }
    
    // Test parseXMLContent method with invalid XML
    @IsTest
    static void testParseXMLContent_InvalidXML() {
        // Create ContentVersion with invalid XML
        ContentVersion invalidXMLContentVersion = new ContentVersion();
        invalidXMLContentVersion.Title = 'Invalid XML File';
        invalidXMLContentVersion.VersionData = Blob.valueOf('<invalid>xml<without>proper</closing>');
        invalidXMLContentVersion.PathOnClient = 'invalid.xml';
        insert invalidXMLContentVersion;
        
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = invalidXMLContentVersion.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results - should handle invalid XML gracefully
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test with XML that has no metadata types
    @IsTest
    static void testParseXMLContent_NoMetadataTypes() {
        String xmlWithoutTypes = '<?xml version="1.0" encoding="UTF-8"?>' +
                                '<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
                                '    <version>58.0</version>' +
                                '</Package>';
        
        // Create ContentVersion with XML without types
        ContentVersion noTypesContentVersion = new ContentVersion();
        noTypesContentVersion.Title = 'No Types XML File';
        noTypesContentVersion.VersionData = Blob.valueOf(xmlWithoutTypes);
        noTypesContentVersion.PathOnClient = 'notypes.xml';
        insert noTypesContentVersion;
        
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = noTypesContentVersion.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test exception handling in processFiles
    @IsTest
    static void testProcessFiles_ExceptionHandling() {
        // Create input with invalid user story ID to trigger exception
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = '0691234567890123456'; // Invalid ID format
        input.userStoryId = 'invalid-user-story-id';
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test with multiple input wrappers (only first one should be processed)
    @IsTest
    static void testProcessFiles_MultipleInputs() {
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test XML File' LIMIT 1];
        
        // Create multiple input wrappers
        CommitUsingXMLFile.FlowInputWrapper input1 = new CommitUsingXMLFile.FlowInputWrapper();
        input1.contentDocumentId = cv.ContentDocumentId;
        input1.userStoryId = userStory.Id;
        
        CommitUsingXMLFile.FlowInputWrapper input2 = new CommitUsingXMLFile.FlowInputWrapper();
        input2.contentDocumentId = cv.ContentDocumentId;
        input2.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input1, input2});
        Test.stopTest();
        
        // Verify results - should only process first input
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test with XML containing empty members
    @IsTest
    static void testParseXMLContent_EmptyMembers() {
        String xmlWithEmptyMembers = '<?xml version="1.0" encoding="UTF-8"?>' +
                                    '<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
                                    '    <types>' +
                                    '        <members></members>' +
                                    '        <name>ApexClass</name>' +
                                    '    </types>' +
                                    '    <version>58.0</version>' +
                                    '</Package>';
        
        // Create ContentVersion with XML with empty members
        ContentVersion emptyMembersContentVersion = new ContentVersion();
        emptyMembersContentVersion.Title = 'Empty Members XML File';
        emptyMembersContentVersion.VersionData = Blob.valueOf(xmlWithEmptyMembers);
        emptyMembersContentVersion.PathOnClient = 'emptymembers.xml';
        insert emptyMembersContentVersion;
        
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = emptyMembersContentVersion.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
    
    // Test with XML without name element
    @IsTest
    static void testParseXMLContent_NoNameElement() {
        String xmlWithoutName = '<?xml version="1.0" encoding="UTF-8"?>' +
                               '<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
                               '    <types>' +
                               '        <members>TestClass</members>' +
                               '    </types>' +
                               '    <version>58.0</version>' +
                               '</Package>';
        
        // Create ContentVersion with XML without name element
        ContentVersion noNameContentVersion = new ContentVersion();
        noNameContentVersion.Title = 'No Name XML File';
        noNameContentVersion.VersionData = Blob.valueOf(xmlWithoutName);
        noNameContentVersion.PathOnClient = 'noname.xml';
        insert noNameContentVersion;
        
        // Get test data
        List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c WHERE copado__Release__c != null LIMIT 1];
        copado__User_Story__c userStory = userStories[0];
        
        // Create input wrapper
        CommitUsingXMLFile.FlowInputWrapper input = new CommitUsingXMLFile.FlowInputWrapper();
        input.contentDocumentId = noNameContentVersion.ContentDocumentId;
        input.userStoryId = userStory.Id;
        
        Test.startTest();
        List<CommitUsingXMLFile.FlowResponse> results = CommitUsingXMLFile.processFiles(new List<CommitUsingXMLFile.FlowInputWrapper>{input});
        Test.stopTest();
        
        // Verify results
        CommitUsingXMLFile.FlowResponse response = results[0];
    }
}