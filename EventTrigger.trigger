trigger EventTrigger on conference360__Event__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            EventTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EventTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}