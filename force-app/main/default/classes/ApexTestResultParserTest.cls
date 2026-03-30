/**
 * @description Test class for ApexTestResultParser
 * @author Copado AI Assistant
 * @version 1.0
 */
@IsTest
private class ApexTestResultParserTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test User Story
        copado__User_Story__c userStory = new copado__User_Story__c(
            copado__User_Story_Title__c = 'Test Apex Coverage Parsing'
        );
        insert userStory;
        
        // Create test Result record
        copado__Result__c result = new copado__Result__c(
            copado__User_Story__c = userStory.Id,
            copado__Job_Type__c = 'Apex Test',
            copado__Status__c = 'Success'
        );
        insert result;
        
        // Create test attachment with sample JSON
        String sampleJson = createSampleApexTestResultJson();
        Attachment attachment = new Attachment(
            Name = 'ApexTestResult',
            ParentId = result.Id,
            Body = Blob.valueOf(sampleJson),
            ContentType = 'application/json'
        );
        insert attachment;
    }
    
    @IsTest
    static void testParseApexTestResult() {
        // Get test data
        copado__Result__c result = [SELECT Id FROM copado__Result__c LIMIT 1];
        
        Test.startTest();
        ApexTestResultParser.ApexTestResultData parsedData = ApexTestResultParser.parseApexTestResult(result.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, parsedData, 'Parsed data should not be null');
        System.assertNotEquals(null, parsedData.summary, 'Summary should not be null');
        System.assert(!parsedData.classCoverage.isEmpty(), 'Class coverage should not be empty');
        System.assert(!parsedData.triggerCoverage.isEmpty(), 'Trigger coverage should not be empty');
        
        // Verify summary data
        System.assertEquals(85.5, parsedData.summary.totalCoverage, 'Total coverage should match');
        System.assertEquals(2, parsedData.summary.totalClasses, 'Should have 2 classes');
        System.assertEquals(1, parsedData.summary.totalTriggers, 'Should have 1 trigger');
        
        // Verify class coverage
        ApexTestResultParser.ClassCoverage testClass = null;
        for (ApexTestResultParser.ClassCoverage classCov : parsedData.classCoverage) {
            if (classCov.className == 'TestClass') {
                testClass = classCov;
                break;
            }
        }
        System.assertNotEquals(null, testClass, 'TestClass should be found');
        System.assertEquals(90.0, testClass.coverage, 'TestClass coverage should be 90%');
        System.assertEquals(100, testClass.numLocations, 'TestClass should have 100 locations');
        System.assertEquals(10, testClass.numLocationsNotCovered, 'TestClass should have 10 uncovered locations');
    }
    
    @IsTest
    static void testParseApexTestResultsFromUserStory() {
        // Get test data
        copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];
        
        Test.startTest();
        List<ApexTestResultParser.ApexTestResultData> parsedDataList = ApexTestResultParser.parseApexTestResultsFromUserStory(userStory.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, parsedDataList.size(), 'Should have one parsed result');
        System.assertNotEquals(null, parsedDataList[0].summary, 'Summary should not be null');
    }
    
    @IsTest
    static void testGenerateSummaryReport() {
        // Get test data
        copado__Result__c result = [SELECT Id FROM copado__Result__c LIMIT 1];
        ApexTestResultParser.ApexTestResultData parsedData = ApexTestResultParser.parseApexTestResult(result.Id);
        
        Test.startTest();
        String report = ApexTestResultParser.generateSummaryReport(parsedData);
        Test.stopTest();
        
        // Assertions
        System.assert(report.contains('APEX TEST RESULT SUMMARY'), 'Report should contain summary header');
        System.assert(report.contains('85.50%'), 'Report should contain total coverage');
        System.assert(report.contains('CLASS COVERAGE'), 'Report should contain class coverage section');
        System.assert(report.contains('TRIGGER COVERAGE'), 'Report should contain trigger coverage section');
    }
    
    @IsTest
    static void testGetClassesBelowThreshold() {
        // Get test data
        copado__Result__c result = [SELECT Id FROM copado__Result__c LIMIT 1];
        ApexTestResultParser.ApexTestResultData parsedData = ApexTestResultParser.parseApexTestResult(result.Id);
        
        Test.startTest();
        List<ApexTestResultParser.ClassCoverage> belowThreshold = ApexTestResultParser.getClassesBelowThreshold(parsedData, 85.0);
        Test.stopTest();
        
        // Assertions - AnotherClass has 80% coverage, should be below 85% threshold
        System.assertEquals(1, belowThreshold.size(), 'Should have one class below threshold');
        System.assertEquals('AnotherClass', belowThreshold[0].className, 'AnotherClass should be below threshold');
    }
    
    @IsTest
    static void testGetTriggersBelowThreshold() {
        // Get test data
        copado__Result__c result = [SELECT Id FROM copado__Result__c LIMIT 1];
        ApexTestResultParser.ApexTestResultData parsedData = ApexTestResultParser.parseApexTestResult(result.Id);
        
        Test.startTest();
        List<ApexTestResultParser.TriggerCoverage> belowThreshold = ApexTestResultParser.getTriggersBelowThreshold(parsedData, 80.0);
        Test.stopTest();
        
        // Assertions - TestTrigger has 75% coverage, should be below 80% threshold
        System.assertEquals(1, belowThreshold.size(), 'Should have one trigger below threshold');
        System.assertEquals('TestTrigger', belowThreshold[0].triggerName, 'TestTrigger should be below threshold');
    }
    
    @IsTest
    static void testParseNonExistentResult() {
        Test.startTest();
        ApexTestResultParser.ApexTestResultData parsedData = ApexTestResultParser.parseApexTestResult('a005e000001XXXXAAA');
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, parsedData, 'Should return null for non-existent result');
    }
    
    @IsTest
    static void testGenerateSummaryReportWithNullData() {
        Test.startTest();
        String report = ApexTestResultParser.generateSummaryReport(null);
        Test.stopTest();
        
        // Assertions
        System.assertEquals('No test result data available.', report, 'Should return appropriate message for null data');
    }
    
    /**
     * @description Create sample JSON data that mimics the ApexTestResult attachment structure
     */
    private static String createSampleApexTestResultJson() {
        return '{\n' +
            '  "totalCoverage": 85.5,\n' +
            '  "totalLines": 300,\n' +
            '  "coveredLines": 256,\n' +
            '  "uncoveredLines": 44,\n' +
            '  "TestClass": {\n' +
            '    "coverage": 90.0,\n' +
            '    "numLocations": 100,\n' +
            '    "numLocationsNotCovered": 10,\n' +
            '    "uncoveredLines": [15, 23, 45, 67, 89, 92, 95, 98, 101, 105],\n' +
            '    "methods": {\n' +
            '      "testMethod1": {\n' +
            '        "numLocations": 20,\n' +
            '        "numLocationsNotCovered": 2\n' +
            '      },\n' +
            '      "testMethod2": {\n' +
            '        "numLocations": 30,\n' +
            '        "numLocationsNotCovered": 0\n' +
            '      }\n' +
            '    }\n' +
            '  },\n' +
            '  "AnotherClass": {\n' +
            '    "coverage": 80.0,\n' +
            '    "numLocations": 150,\n' +
            '    "numLocationsNotCovered": 30,\n' +
            '    "uncoveredLines": [12, 25, 38, 41, 55, 68, 72, 85, 91, 103, 115, 128, 134, 147, 152, 165, 178, 182, 195, 201, 213, 225, 238, 241, 255, 268, 272, 285, 291, 303],\n' +
            '    "methods": {\n' +
            '      "anotherMethod1": {\n' +
            '        "numLocations": 25,\n' +
            '        "numLocationsNotCovered": 5\n' +
            '      }\n' +
            '    }\n' +
            '  },\n' +
            '  "TestTrigger": {\n' +
            '    "coverage": 75.0,\n' +
            '    "numLocations": 50,\n' +
            '    "numLocationsNotCovered": 12,\n' +
            '    "uncoveredLines": [5, 12, 18, 25, 32, 38, 41, 45, 48, 52, 55, 58]\n' +
            '  }\n' +
            '}';
    }
}