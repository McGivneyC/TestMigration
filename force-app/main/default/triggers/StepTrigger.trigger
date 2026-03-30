trigger StepTrigger on copado__Step__c (before insert) {
    
    if (Trigger.isBefore) {
        List<copado__Step__c> steps = new List<copado__Step__c>();
        
        for(copado__Step__c step : Trigger.new) {
            
            if(step.copado__Type__c == 'Data Template') {
                System.debug('A data template step is created.');
                
                // Check if the target Org is enforcing Data Backups
                for (copado__Destination_Org__c dorg : [Select Id, copado__To_Org__r.copado__Environment__c, copado__To_Org__r.copado__Environment__r.Data_Backup_Enforcement__c From copado__Destination_Org__c Where copado__Deployment__c = :step.copado__Deployment__c]) {
                    String backupSteps = dorg.copado__To_Org__r.copado__Environment__r.Data_Backup_Enforcement__c;
                    
                    if (!String.isEmpty(backupSteps)) {
                        System.debug('This Environment enforces data backups for data deployments.: ' + backupSteps);
                        
                        String dataJson = '{"type":"wait","method":"GET","url":"https://www.ownbackup.com/","body":"","queryParameters":[],"headers":[]}';
                        
                        if (backupSteps != 'After deployment') {
                            // Create URL Callout before the Data Template Step
                            copado__Step__c sb = new copado__Step__c();
                            sb.name = OwnBackupIntegration.ownBackupStepName;
                            sb.copado__dataJson__c = dataJson;
                            sb.copado__Deployment__c = step.copado__Deployment__c;
                            sb.copado__Order__c = step.copado__Order__c -2;
                            sb.copado__Status__c = 'Not started';
                            sb.copado__Type__c = 'URL Callout';
                            steps.add(sb);
                            
                            System.debug('****** '+ backupSteps + ' - ' + sb.copado__Order__c + ' - ' + sb.Name);
                            System.debug('****** '+ backupSteps + ' - ' + step.copado__Order__c + ' - ' + step.Name);
                        }
                        
                        if (backupSteps != 'Before deployment') {
                            // Create URL Callout after the Data Template Step
                            copado__Step__c sb2 = new copado__Step__c();
                            sb2.name = OwnBackupIntegration.ownBackupStepName;
                            sb2.copado__dataJson__c = dataJson;
                            sb2.copado__Deployment__c = step.copado__Deployment__c;
                            sb2.copado__Order__c = step.copado__Order__c+2;
                            sb2.copado__Status__c = 'Not started';
                            sb2.copado__Type__c = 'URL Callout';
                            steps.add(sb2);
                            if (backupSteps == 'After deployment'){
                                step.copado__Order__c = step.copado__Order__c - 1;
                            }
                            
                            System.debug('****** '+ backupSteps + ' - ' + step.copado__Order__c + ' - ' + step.Name);
                            System.debug('****** '+ backupSteps + ' - ' + sb2.copado__Order__c + ' - ' + sb2.Name);
                        }                
                    } else {
                        System.debug('This Org does not enforce Data Backups.');
                    }
                }
            }
        }
        
        if (steps.size() > 0) {
            insert steps;
            for (copado__Step__c s:steps){
                System.debug('trigger ends - new steps to add ****** ' + s.copado__Order__c + ' - ' + s.Name);
            }
        }
    }
}