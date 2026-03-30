/**
 * @description Apex class to parse JSON attachment from Apex Test Result objects
 * This class extracts detailed coverage data from the ApexTestResult attachment
 * and provides structured access to the four tabs data: Summary, Class coverage, Trigger coverage, Methods
 *
 * @author Copado AI Assistant
 * @version 2.0
 */
public class ApexTestResultParser {

    // Inner classes to represent the parsed data structure
    public class ApexTestResultData {
        public TestSummary summary;
        public List<ClassCoverage> classCoverage;
        public List<TriggerCoverage> triggerCoverage;
        public List<MethodCoverage> methodCoverage;
        public String rawJson;

        public ApexTestResultData() {
            this.classCoverage = new List<ClassCoverage>();
            this.triggerCoverage = new List<TriggerCoverage>();
            this.methodCoverage = new List<MethodCoverage>();
        }
    }

    public class TestSummary {
        public Decimal totalCoverage;
        public Integer totalLines;
        public Integer coveredLines;
        public Integer uncoveredLines;
        public Integer totalClasses;
        public Integer totalTriggers;
        public Integer totalMethods;
        public String testRunId;
        public DateTime testRunDate;
        public Integer totalTests;
        public Integer passedTests;
        public Integer failedTests;
        public Decimal totalTime;
    }

    public class ClassCoverage {
        public String className;
        public Decimal coverage;
        public Integer numLocations;
        public Integer numLocationsNotCovered;
        public List<Integer> uncoveredLines;

        public ClassCoverage() {
            this.uncoveredLines = new List<Integer>();
        }
    }

    public class TriggerCoverage {
        public String triggerName;
        public Decimal coverage;
        public Integer numLocations;
        public Integer numLocationsNotCovered;
        public List<Integer> uncoveredLines;

        public TriggerCoverage() {
            this.uncoveredLines = new List<Integer>();
        }
    }

    public class MethodCoverage {
        public String className;
        public String methodName;
        public Integer numLocations;
        public Integer numLocationsNotCovered;
        public Decimal coverage;
    }

    /**
     * @description Parse ApexTestResult attachment from an Apex Test Result record
     * @param apexTestResultId The ID of the copado__Apex_Test_Result__c record
     * @return ApexTestResultData parsed data or null if not found
     */
    public static ApexTestResultData parseFromApexTestResult(Id apexTestResultId) {
        try {
            // Query for the attachment from Apex Test Result
            List<Attachment> attachments = [
                SELECT Id, Name, Body
                FROM Attachment
                WHERE ParentId = :apexTestResultId
                AND (Name = 'ApexTestResult' OR Name LIKE '%test%result%' OR Name LIKE '%coverage%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (attachments.isEmpty()) {
                System.debug('No ApexTestResult attachment found for Apex Test Result ID: ' + apexTestResultId);
                return null;
            }

            String jsonContent = attachments[0].Body.toString();
            ApexTestResultData parsedData = parseJsonContent(jsonContent);
            
            // Enhance with data from the Apex Test Result record itself
            enhanceWithApexTestResultData(parsedData, apexTestResultId);
            
            return parsedData;

        } catch (Exception e) {
            System.debug('Error parsing ApexTestResult from Apex Test Result: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Parse ApexTestResult attachment from a Result record (legacy support)
     * @param resultId The ID of the copado__Result__c record
     * @return ApexTestResultData parsed data or null if not found
     */
    public static ApexTestResultData parseApexTestResult(Id resultId) {
        try {
            // Query for the attachment
            List<Attachment> attachments = [
                SELECT Id, Name, Body
                FROM Attachment
                WHERE ParentId = :resultId
                AND Name = 'ApexTestResult'
                LIMIT 1
            ];

            if (attachments.isEmpty()) {
                System.debug('No ApexTestResult attachment found for Result ID: ' + resultId);
                return null;
            }

            String jsonContent = attachments[0].Body.toString();
            return parseJsonContent(jsonContent);

        } catch (Exception e) {
            System.debug('Error parsing ApexTestResult: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Get all Apex Test Results for a specific credential/org
     * @param orgCredentialId The ID of the copado__Org__c record
     * @return List of ApexTestResultData from all test results for the org
     */
    public static List<ApexTestResultData> parseApexTestResultsFromOrg(Id orgCredentialId) {
        List<ApexTestResultData> results = new List<ApexTestResultData>();

        try {
            List<copado__Apex_Test_Result__c> apexTestResults = [
                SELECT Id
                FROM copado__Apex_Test_Result__c
                WHERE copado__Org__c = :orgCredentialId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            for (copado__Apex_Test_Result__c apexTestResult : apexTestResults) {
                ApexTestResultData parsedData = parseFromApexTestResult(apexTestResult.Id);
                if (parsedData != null) {
                    results.add(parsedData);
                }
            }

        } catch (Exception e) {
            System.debug('Error parsing ApexTestResults from Org: ' + e.getMessage());
        }

        return results;
    }

    /**
     * @description Enhance parsed data with information from the Apex Test Result record
     * @param parsedData The parsed data to enhance
     * @param apexTestResultId The Apex Test Result record ID
     */
    private static void enhanceWithApexTestResultData(ApexTestResultData parsedData, Id apexTestResultId) {
        try {
            List<copado__Apex_Test_Result__c> apexTestResults = [
                SELECT Id, Name, copado__Tests_run__c, copado__Failures__c, copado__Successes__c, 
                       copado__Total_time__c, copado__Status__c, CreatedDate, copado__Details__c
                FROM copado__Apex_Test_Result__c
                WHERE Id = :apexTestResultId
                LIMIT 1
            ];

            if (!apexTestResults.isEmpty()) {
                copado__Apex_Test_Result__c apexTestResult = apexTestResults[0];
                
                if (parsedData.summary == null) {
                    parsedData.summary = new TestSummary();
                }

                // Enhance summary with Apex Test Result data
                parsedData.summary.testRunId = apexTestResult.Name;
                parsedData.summary.testRunDate = apexTestResult.CreatedDate;
                
                if (apexTestResult.copado__Tests_run__c != null) {
                    parsedData.summary.totalTests = Integer.valueOf(apexTestResult.copado__Tests_run__c);
                }
                
                if (apexTestResult.copado__Failures__c != null) {
                    parsedData.summary.failedTests = Integer.valueOf(apexTestResult.copado__Failures__c);
                    if (parsedData.summary.totalTests != null) {
                        parsedData.summary.passedTests = parsedData.summary.totalTests - parsedData.summary.failedTests;
                    }
                }
                
                if (apexTestResult.copado__Total_time__c != null) {
                    parsedData.summary.totalTime = apexTestResult.copado__Total_time__c;
                }
            }

        } catch (Exception e) {
            System.debug('Error enhancing with Apex Test Result data: ' + e.getMessage());
        }
    }

    /**
     * @description Parse JSON content from ApexTestResult attachment
     * @param jsonContent The JSON string content
     * @return ApexTestResultData parsed data
     */
    @TestVisible
    private static ApexTestResultData parseJsonContent(String jsonContent) {
        ApexTestResultData result = new ApexTestResultData();
        result.rawJson = jsonContent;

        try {
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(jsonContent);

            // Parse summary information
            result.summary = parseSummary(jsonData);

            // Parse class coverage
            result.classCoverage = parseClassCoverage(jsonData);

            // Parse trigger coverage
            result.triggerCoverage = parseTriggerCoverage(jsonData);

            // Parse method coverage
            result.methodCoverage = parseMethodCoverage(jsonData);

        } catch (Exception e) {
            System.debug('Error parsing JSON content: ' + e.getMessage());
            System.debug('JSON Content: ' + jsonContent);
        }

        return result;
    }

    /**
     * @description Parse summary information from JSON data
     */
    @TestVisible
    private static TestSummary parseSummary(Map<String, Object> jsonData) {
        TestSummary summary = new TestSummary();

        try {
            // Extract overall coverage information
            if (jsonData.containsKey('totalCoverage')) {
                summary.totalCoverage = Decimal.valueOf(String.valueOf(jsonData.get('totalCoverage')));
            }

            if (jsonData.containsKey('totalLines')) {
                summary.totalLines = Integer.valueOf(jsonData.get('totalLines'));
            }

            if (jsonData.containsKey('coveredLines')) {
                summary.coveredLines = Integer.valueOf(jsonData.get('coveredLines'));
            }

            if (jsonData.containsKey('uncoveredLines')) {
                summary.uncoveredLines = Integer.valueOf(jsonData.get('uncoveredLines'));
            }

            // Extract test execution information
            if (jsonData.containsKey('totalTests')) {
                summary.totalTests = Integer.valueOf(jsonData.get('totalTests'));
            }

            if (jsonData.containsKey('passedTests')) {
                summary.passedTests = Integer.valueOf(jsonData.get('passedTests'));
            }

            if (jsonData.containsKey('failedTests')) {
                summary.failedTests = Integer.valueOf(jsonData.get('failedTests'));
            }

            if (jsonData.containsKey('totalTime')) {
                summary.totalTime = Decimal.valueOf(String.valueOf(jsonData.get('totalTime')));
            }

            // Count classes, triggers, and methods
            summary.totalClasses = 0;
            summary.totalTriggers = 0;
            summary.totalMethods = 0;

            for (String key : jsonData.keySet()) {
                if (jsonData.get(key) instanceof Map<String, Object>) {
                    Map<String, Object> itemData = (Map<String, Object>) jsonData.get(key);

                    // Determine if it's a class, trigger, or method based on structure
                    if (itemData.containsKey('coverage')) {
                        if (key.toLowerCase().contains('trigger')) {
                            summary.totalTriggers++;
                        } else {
                            summary.totalClasses++;
                        }
                    }
                }
            }

        } catch (Exception e) {
            System.debug('Error parsing summary: ' + e.getMessage());
        }

        return summary;
    }

    /**
     * @description Parse class coverage information from JSON data
     */
    @TestVisible
    private static List<ClassCoverage> parseClassCoverage(Map<String, Object> jsonData) {
        List<ClassCoverage> classCoverageList = new List<ClassCoverage>();

        try {
            for (String key : jsonData.keySet()) {
                if (jsonData.get(key) instanceof Map<String, Object>) {
                    Map<String, Object> itemData = (Map<String, Object>) jsonData.get(key);

                    // Skip triggers and focus on classes
                    if (!key.toLowerCase().contains('trigger') && itemData.containsKey('coverage')) {
                        ClassCoverage classCov = new ClassCoverage();
                        classCov.className = key;

                        if (itemData.containsKey('coverage')) {
                            classCov.coverage = Decimal.valueOf(String.valueOf(itemData.get('coverage')));
                        }

                        if (itemData.containsKey('numLocations')) {
                            classCov.numLocations = Integer.valueOf(itemData.get('numLocations'));
                        }

                        if (itemData.containsKey('numLocationsNotCovered')) {
                            classCov.numLocationsNotCovered = Integer.valueOf(itemData.get('numLocationsNotCovered'));
                        }

                        // Parse uncovered lines if available
                        if (itemData.containsKey('uncoveredLines') && itemData.get('uncoveredLines') instanceof List<Object>) {
                            List<Object> uncoveredLinesObj = (List<Object>) itemData.get('uncoveredLines');
                            for (Object lineObj : uncoveredLinesObj) {
                                classCov.uncoveredLines.add(Integer.valueOf(lineObj));
                            }
                        }

                        classCoverageList.add(classCov);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing class coverage: ' + e.getMessage());
        }

        return classCoverageList;
    }

    /**
     * @description Parse trigger coverage information from JSON data
     */
    @TestVisible
    private static List<TriggerCoverage> parseTriggerCoverage(Map<String, Object> jsonData) {
        List<TriggerCoverage> triggerCoverageList = new List<TriggerCoverage>();

        try {
            for (String key : jsonData.keySet()) {
                if (jsonData.get(key) instanceof Map<String, Object>) {
                    Map<String, Object> itemData = (Map<String, Object>) jsonData.get(key);

                    // Focus on triggers
                    if (key.toLowerCase().contains('trigger') && itemData.containsKey('coverage')) {
                        TriggerCoverage triggerCov = new TriggerCoverage();
                        triggerCov.triggerName = key;

                        if (itemData.containsKey('coverage')) {
                            triggerCov.coverage = Decimal.valueOf(String.valueOf(itemData.get('coverage')));
                        }

                        if (itemData.containsKey('numLocations')) {
                            triggerCov.numLocations = Integer.valueOf(itemData.get('numLocations'));
                        }

                        if (itemData.containsKey('numLocationsNotCovered')) {
                            triggerCov.numLocationsNotCovered = Integer.valueOf(itemData.get('numLocationsNotCovered'));
                        }

                        // Parse uncovered lines if available
                        if (itemData.containsKey('uncoveredLines') && itemData.get('uncoveredLines') instanceof List<Object>) {
                            List<Object> uncoveredLinesObj = (List<Object>) itemData.get('uncoveredLines');
                            for (Object lineObj : uncoveredLinesObj) {
                                triggerCov.uncoveredLines.add(Integer.valueOf(lineObj));
                            }
                        }

                        triggerCoverageList.add(triggerCov);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing trigger coverage: ' + e.getMessage());
        }

        return triggerCoverageList;
    }

    /**
     * @description Parse method coverage information from JSON data
     */
    @TestVisible
    private static List<MethodCoverage> parseMethodCoverage(Map<String, Object> jsonData) {
        List<MethodCoverage> methodCoverageList = new List<MethodCoverage>();

        try {
            for (String key : jsonData.keySet()) {
                if (jsonData.get(key) instanceof Map<String, Object>) {
                    Map<String, Object> itemData = (Map<String, Object>) jsonData.get(key);

                    // Look for method-level data within classes
                    if (itemData.containsKey('methods') && itemData.get('methods') instanceof Map<String, Object>) {
                        Map<String, Object> methodsData = (Map<String, Object>) itemData.get('methods');

                        for (String methodName : methodsData.keySet()) {
                            if (methodsData.get(methodName) instanceof Map<String, Object>) {
                                Map<String, Object> methodData = (Map<String, Object>) methodsData.get(methodName);

                                MethodCoverage methodCov = new MethodCoverage();
                                methodCov.className = key;
                                methodCov.methodName = methodName;

                                if (methodData.containsKey('numLocations')) {
                                    methodCov.numLocations = Integer.valueOf(methodData.get('numLocations'));
                                }

                                if (methodData.containsKey('numLocationsNotCovered')) {
                                    methodCov.numLocationsNotCovered = Integer.valueOf(methodData.get('numLocationsNotCovered'));
                                }

                                // Calculate coverage percentage
                                if (methodCov.numLocations != null && methodCov.numLocations > 0) {
                                    Integer covered = methodCov.numLocations - (methodCov.numLocationsNotCovered != null ? methodCov.numLocationsNotCovered : 0);
                                    methodCov.coverage = (Decimal.valueOf(covered) / Decimal.valueOf(methodCov.numLocations)) * 100;
                                }

                                methodCoverageList.add(methodCov);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing method coverage: ' + e.getMessage());
        }

        return methodCoverageList;
    }

    /**
     * @description Generate a comprehensive report of the parsed data
     * @param data The parsed ApexTestResultData
     * @return String formatted comprehensive report
     */
    public static String generateComprehensiveReport(ApexTestResultData data) {
        if (data == null) {
            return 'No test result data available.';
        }

        String report = '=== APEX TEST RESULT COMPREHENSIVE REPORT ===\n\n';

        // Test Execution Summary
        if (data.summary != null) {
            report += '=== TEST EXECUTION SUMMARY ===\n';
            report += 'Test Run ID: ' + (data.summary.testRunId != null ? data.summary.testRunId : 'N/A') + '\n';
            report += 'Test Run Date: ' + (data.summary.testRunDate != null ? data.summary.testRunDate.format() : 'N/A') + '\n';
            report += 'Total Tests: ' + (data.summary.totalTests != null ? String.valueOf(data.summary.totalTests) : 'N/A') + '\n';
            report += 'Passed Tests: ' + (data.summary.passedTests != null ? String.valueOf(data.summary.passedTests) : 'N/A') + '\n';
            report += 'Failed Tests: ' + (data.summary.failedTests != null ? String.valueOf(data.summary.failedTests) : 'N/A') + '\n';
            report += 'Total Time: ' + (data.summary.totalTime != null ? data.summary.totalTime + ' ms' : 'N/A') + '\n\n';

            // Coverage Summary
            report += '=== COVERAGE SUMMARY ===\n';
            report += 'OVERALL COVERAGE: ' + (data.summary.totalCoverage != null ? data.summary.totalCoverage.setScale(2) + '%' : 'N/A') + '\n';
            report += 'Total Lines: ' + (data.summary.totalLines != null ? String.valueOf(data.summary.totalLines) : 'N/A') + '\n';
            report += 'Covered Lines: ' + (data.summary.coveredLines != null ? String.valueOf(data.summary.coveredLines) : 'N/A') + '\n';
            report += 'Uncovered Lines: ' + (data.summary.uncoveredLines != null ? String.valueOf(data.summary.uncoveredLines) : 'N/A') + '\n';
            report += 'Total Classes: ' + String.valueOf(data.summary.totalClasses) + '\n';
            report += 'Total Triggers: ' + String.valueOf(data.summary.totalTriggers) + '\n\n';
        }

        // Class coverage section
        if (!data.classCoverage.isEmpty()) {
            report += '=== CLASS COVERAGE DETAILS ===\n';
            for (ClassCoverage classCov : data.classCoverage) {
                report += classCov.className + ': ' + (classCov.coverage != null ? classCov.coverage.setScale(2) + '%' : 'N/A');
                report += ' (' + (classCov.numLocationsNotCovered != null ? String.valueOf(classCov.numLocationsNotCovered) : '0') + '/' + (classCov.numLocations != null ? String.valueOf(classCov.numLocations) : '0') + ' uncovered)';
                
                if (!classCov.uncoveredLines.isEmpty()) {
                    report += ' - Uncovered lines: ' + String.join(classCov.uncoveredLines, ', ');
                }
                report += '\n';
            }
            report += '\n';
        }

        // Trigger coverage section
        if (!data.triggerCoverage.isEmpty()) {
            report += '=== TRIGGER COVERAGE DETAILS ===\n';
            for (TriggerCoverage triggerCov : data.triggerCoverage) {
                report += triggerCov.triggerName + ': ' + (triggerCov.coverage != null ? triggerCov.coverage.setScale(2) + '%' : 'N/A');
                report += ' (' + (triggerCov.numLocationsNotCovered != null ? String.valueOf(triggerCov.numLocationsNotCovered) : '0') + '/' + (triggerCov.numLocations != null ? String.valueOf(triggerCov.numLocations) : '0') + ' uncovered)';
                
                if (!triggerCov.uncoveredLines.isEmpty()) {
                    report += ' - Uncovered lines: ' + String.join(triggerCov.uncoveredLines, ', ');
                }
                report += '\n';
            }
            report += '\n';
        }

        // Method coverage section
        if (!data.methodCoverage.isEmpty()) {
            report += '=== METHOD COVERAGE DETAILS ===\n';
            for (MethodCoverage methodCov : data.methodCoverage) {
                report += methodCov.className + '.' + methodCov.methodName + ': ';
                report += (methodCov.coverage != null ? methodCov.coverage.setScale(2) + '%' : 'N/A');
                report += ' (' + (methodCov.numLocationsNotCovered != null ? String.valueOf(methodCov.numLocationsNotCovered) : '0') + '/' + (methodCov.numLocations != null ? String.valueOf(methodCov.numLocations) : '0') + ' uncovered)\n';
            }
            report += '\n';
        }

        return report;
    }

    /**
     * @description Generate a summary report of the parsed data (legacy method)
     * @param data The parsed ApexTestResultData
     * @return String formatted summary report
     */
    public static String generateSummaryReport(ApexTestResultData data) {
        if (data == null) {
            return 'No test result data available.';
        }

        String report = '=== APEX TEST RESULT SUMMARY ===\n\n';

        // Summary section
        if (data.summary != null) {
            report += 'OVERALL COVERAGE: ' + (data.summary.totalCoverage != null ? data.summary.totalCoverage.setScale(2) + '%' : 'N/A') + '\n';
            report += 'Total Lines: ' + (data.summary.totalLines != null ? String.valueOf(data.summary.totalLines) : 'N/A') + '\n';
            report += 'Covered Lines: ' + (data.summary.coveredLines != null ? String.valueOf(data.summary.coveredLines) : 'N/A') + '\n';
            report += 'Uncovered Lines: ' + (data.summary.uncoveredLines != null ? String.valueOf(data.summary.uncoveredLines) : 'N/A') + '\n';
            report += 'Total Classes: ' + String.valueOf(data.summary.totalClasses) + '\n';
            report += 'Total Triggers: ' + String.valueOf(data.summary.totalTriggers) + '\n\n';
        }

        // Class coverage section
        if (!data.classCoverage.isEmpty()) {
            report += '=== CLASS COVERAGE ===\n';
            for (ClassCoverage classCov : data.classCoverage) {
                report += classCov.className + ': ' + (classCov.coverage != null ? classCov.coverage.setScale(2) + '%' : 'N/A');
                report += ' (' + (classCov.numLocationsNotCovered != null ? String.valueOf(classCov.numLocationsNotCovered) : '0') + '/' + (classCov.numLocations != null ? String.valueOf(classCov.numLocations) : '0') + ' uncovered)\n';
            }
            report += '\n';
        }

        // Trigger coverage section
        if (!data.triggerCoverage.isEmpty()) {
            report += '=== TRIGGER COVERAGE ===\n';
            for (TriggerCoverage triggerCov : data.triggerCoverage) {
                report += triggerCov.triggerName + ': ' + (triggerCov.coverage != null ? triggerCov.coverage.setScale(2) + '%' : 'N/A');
                report += ' (' + (triggerCov.numLocationsNotCovered != null ? String.valueOf(triggerCov.numLocationsNotCovered) : '0') + '/' + (triggerCov.numLocations != null ? String.valueOf(triggerCov.numLocations) : '0') + ' uncovered)\n';
            }
            report += '\n';
        }

        return report;
    }

    /**
     * @description Get classes with coverage below threshold
     * @param data The parsed ApexTestResultData
     * @param threshold The coverage threshold (e.g., 75.0 for 75%)
     * @return List of ClassCoverage objects below threshold
     */
    public static List<ClassCoverage> getClassesBelowThreshold(ApexTestResultData data, Decimal threshold) {
        List<ClassCoverage> belowThreshold = new List<ClassCoverage>();

        if (data != null && data.classCoverage != null) {
            for (ClassCoverage classCov : data.classCoverage) {
                if (classCov.coverage != null && classCov.coverage < threshold) {
                    belowThreshold.add(classCov);
                }
            }
        }

        return belowThreshold;
    }

    /**
     * @description Get triggers with coverage below threshold
     * @param data The parsed ApexTestResultData
     * @param threshold The coverage threshold (e.g., 75.0 for 75%)
     * @return List of TriggerCoverage objects below threshold
     */
    public static List<TriggerCoverage> getTriggersBelowThreshold(ApexTestResultData data, Decimal threshold) {
        List<TriggerCoverage> belowThreshold = new List<TriggerCoverage>();

        if (data != null && data.triggerCoverage != null) {
            for (TriggerCoverage triggerCov : data.triggerCoverage) {
                if (triggerCov.coverage != null && triggerCov.coverage < threshold) {
                    belowThreshold.add(triggerCov);
                }
            }
        }

        return belowThreshold;
    }

    /**
     * @description Create a Salesforce report record with the test results
     * @param data The parsed ApexTestResultData
     * @param reportName The name for the report record
     * @return Id of the created report record or null if failed
     */
    public static Id createSalesforceReport(ApexTestResultData data, String reportName) {
        if (data == null) {
            return null;
        }

        try {
            // Create a custom object record to store the report
            // Note: You'll need to create a custom object for storing reports
            // This is a placeholder implementation
            
            String reportContent = generateComprehensiveReport(data);
            
            // Example: Create a ContentVersion to store the report
            ContentVersion cv = new ContentVersion();
            cv.Title = reportName;
            cv.PathOnClient = reportName + '.txt';
            cv.VersionData = Blob.valueOf(reportContent);
            cv.IsMajorVersion = true;
            
            insert cv;
            
            return cv.Id;

        } catch (Exception e) {
            System.debug('Error creating Salesforce report: ' + e.getMessage());
            return null;
        }
    }
}