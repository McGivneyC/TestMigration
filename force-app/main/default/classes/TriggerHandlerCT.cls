public class TriggerHandlerCT {
    private static boolean isRecursive = false;
    private static boolean cleanupJobEnqueued = false;

    public static boolean isTriggerRecursive() {
        return isRecursive;
    }

    public static void setTriggerRecursive(boolean value) {
        isRecursive = value;
    }

    public static boolean hasCleanupJobBeenEnqueued() {
        return cleanupJobEnqueued;
    }

    public static void setCleanupJobEnqueued(boolean value) {
        cleanupJobEnqueued = value;
    }

 public static void handleCopadoTips(List<CopadoTips__c> newTips, Map<Id, CopadoTips__c> oldMap) {
        if (isRecursive) {
            return;
        }
        try {
            isRecursive = true;

            // Find if there's any new default tip being set
            Id defaultTipId = null;
            for (CopadoTips__c tip : newTips) {
                if (tip.DefaultTip__c) {
                    if (defaultTipId != null) {
                        tip.addError('Only one CopadoTip record can be set as default.');
                    } else {
                        defaultTipId = tip.Id;
                    }
                }
            }

            // Check against all other existing default tips if a new default is being set
            if (defaultTipId != null) {
                for (CopadoTips__c existingTip : [SELECT Id, DefaultTip__c FROM CopadoTips__c WHERE DefaultTip__c = true AND Id != :defaultTipId]) {
                    existingTip.DefaultTip__c = false;
                    update existingTip;
                }
            }
        } finally {
            isRecursive = false;
        }
    }
}