trigger SalesDocumentTrigger on bt_stripe__Sales_Document__c (before insert, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        SalesDocumentTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        SalesDocumentTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}