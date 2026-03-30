@IsTest(seeAllData=true)
private class testUmit {
    @IsTest
    static void testMethod1() {
        User objUser = [SELECT Id, Name FROM User WHERE Id = '0055e000006OxbwAAC'];
        system.RunAs(objUser){
            try {
                List<copado__Deployment__c> deps = [SELECT Id, Name, copado__Paused__c, copado__Promotion__c, copado__Status__c, copado__Promotion__r.copado__Status__c, (SELECT Id, Name FROM copado__JobExecutions__r), copado__Date__c, copado__Flag_Status__c, copado__Completed__c, copado__Deployed__c, copado__From_Org__c, copado__Promotion__r.copado__Back_Promotion__c FROM copado__Deployment__c WHERE (copado__Promotion__r.copado__Destination_Environment__c = 'a0c5e000001RQl2AAG') AND copado__Status__c != 'Draft' AND copado__Status__c != 'Validated' WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC LIMIT 500];
            } catch(Exception ex){
                System.debug('ex===> '+ex.getMessage());
            }
            SObjectAccessDecision strippedRecords = Security.stripInaccessible(AccessType.READABLE, [SELECT Id, Name, copado__Paused__c, copado__Promotion__c, copado__Status__c, copado__Promotion__r.copado__Status__c, (SELECT Id, Name FROM copado__JobExecutions__r), copado__Date__c, copado__Flag_Status__c, copado__Completed__c, copado__Deployed__c, copado__From_Org__c, copado__Promotion__r.copado__Back_Promotion__c FROM copado__Deployment__c WHERE (copado__Promotion__r.copado__Destination_Environment__c = 'a0c5e000001RQl2AAG') AND copado__Status__c != 'Draft' AND copado__Status__c != 'Validated' ORDER BY LastModifiedDate DESC LIMIT 500]);
            System.debug('strippedRecords.getRemovedFields()====> '+strippedRecords.getRemovedFields());
        }
    }
}