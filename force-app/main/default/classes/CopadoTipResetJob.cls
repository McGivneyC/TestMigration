public class CopadoTipResetJob implements Queueable {
    public void execute(QueueableContext context) {
        
        Datetime nowUtc = Datetime.now();
        
        List<CopadoTips__c> tipsToReset = [
            SELECT Id, DefaultTip__c, TipEndTime__c
            FROM CopadoTips__c
            WHERE DefaultTip__c = true AND TipEndTime__c < :nowUtc
        ];

        if (!tipsToReset.isEmpty()) {
            for (CopadoTips__c tip : tipsToReset) {
                tip.DefaultTip__c = false;
            }
            try {
                update tipsToReset;
            } catch (DmlException e) {
                System.debug('Error updating Copado Tips: ' + e.getMessage());
            }
        }
    }
}