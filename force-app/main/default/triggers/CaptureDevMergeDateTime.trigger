trigger CaptureDevMergeDateTime on copado__User_Story__c (before update) {
    for (copado__User_Story__c record : Trigger.new) {
        copado__User_Story__c oldRecord = Trigger.oldMap.get(record.Id);
        
        // Check if the environment changed to "DevMerge"
        if (record.Copado__Environment__c == 'a0c5e000001RQlRAAW' && 
            (oldRecord == null || oldRecord.Copado__Environment__c != 'a0c5e000001RQlRAAW')) {
            
            // Set the DevMerge_DateTime__c field to the current date/time
            record.Deployed_to_DevMerge__c = DateTime.now();
        }
    }
}