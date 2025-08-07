trigger LineItemTrigger on bt_stripe__Line_Item__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            LineItemTriggerHelper.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            LineItemTriggerHelper.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}