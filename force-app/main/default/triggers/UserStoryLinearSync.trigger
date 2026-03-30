trigger UserStoryLinearSync on copado__User_Story__c (after insert, after update) {
    List<LinearSync__e> events = new List<LinearSync__e>();
    
    for (copado__User_Story__c story : Trigger.new) {
        if (UserStoryLinearSyncHelper.shouldSyncToLinear(story, Trigger.oldMap)) {
            LinearSync__e event = new LinearSync__e();
            event.Linear_Issue_ID__c = story.Linear_Issue_ID__c;
            event.Action__c = Trigger.isInsert ? 'create' : 'update';
            event.User_Story_ID__c = story.Id;
            events.add(event);
        }
    }
    
    if (!events.isEmpty()) {
        EventBus.publish(events);
    }
}