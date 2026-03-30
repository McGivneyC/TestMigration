trigger CopadoTipTrigger on CopadoTips__c (before insert, before update) {
    if (Trigger.isBefore) {
        // Handle setting and resetting the recursion flag within the handler to ensure it's always correctly managed
        TriggerHandlerCT.handleCopadoTips(Trigger.new, Trigger.oldMap);

        // Enqueue job to clean up old default tips only once per transaction
        if (!TriggerHandlerCT.hasCleanupJobBeenEnqueued()) {
            System.enqueueJob(new CopadoTipResetJob());
            TriggerHandlerCT.setCleanupJobEnqueued(true);
        }
    }
}