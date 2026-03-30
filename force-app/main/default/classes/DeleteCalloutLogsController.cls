public class DeleteCalloutLogsController {
    private final copado__Project__c project;
    
    public DeleteCalloutLogsController(ApexPages.StandardController stdController) {
        this.project = (copado__Project__c)stdController.getRecord();
    }
    
    public PageReference executeBatch() {
        try {
            DeleteCalloutLogs batch = new DeleteCalloutLogs(5, 2000); // Using default values
            Database.executeBatch(batch);
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Batch job to delete old Callout Logs has been queued successfully.'
            ));
        } catch(Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error executing batch: ' + e.getMessage()
            ));
        }
        return null;
    }
    
    public PageReference cancel() {
        return new PageReference('/' + project.Id);
    }
}