trigger AttendeeTrigger on conference360__Attendee__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            updateRelatedLineItems(Trigger.new, null);
            AttendeeIntegrationHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            updateRelatedLineItems(Trigger.new, Trigger.oldMap);
            AttendeeIntegrationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    
    private static void updateRelatedLineItems(List<conference360__Attendee__c> newAttendees, 
                                             Map<Id, conference360__Attendee__c> oldMap) {
        Set<Id> attendeeIdsToProcess = new Set<Id>();
        
        for (conference360__Attendee__c attendee : newAttendees) {
            if (oldMap == null || 
                attendee.conference360__Registration_Status__c != oldMap.get(attendee.Id).conference360__Registration_Status__c) {
                attendeeIdsToProcess.add(attendee.Id);
            }
        }
        
        if (attendeeIdsToProcess.isEmpty()) {
            return;
        }
        
        Map<Id, String> attendeeStatusMap = new Map<Id, String>();
        for (conference360__Attendee__c attendee : newAttendees) {
            if (attendeeIdsToProcess.contains(attendee.Id)) {
                attendeeStatusMap.put(attendee.Id, attendee.conference360__Registration_Status__c);
            }
        }
        
        List<bt_stripe__Line_Item__c> lineItemsToUpdate = new List<bt_stripe__Line_Item__c>();
        
        for (bt_stripe__Line_Item__c lineItem : [SELECT Id, conference360__Attendee__c, line_item_status__c 
                                      FROM bt_stripe__Line_Item__c 
                                      WHERE conference360__Attendee__c IN :attendeeIdsToProcess]) {
            
            String attendeeStatus = attendeeStatusMap.get(lineItem.conference360__Attendee__c);
            String newLineItemStatus;
            
            if (attendeeStatus.contains('Cancel')) {
                newLineItemStatus = 'Canceled';
            } else if (attendeeStatus == 'Registered') {
                newLineItemStatus = 'Active';
            }
            
            if (lineItem.line_item_status__c != newLineItemStatus) {
                lineItem.line_item_status__c = newLineItemStatus;
                lineItemsToUpdate.add(lineItem);
            }
        }
        
        if (!lineItemsToUpdate.isEmpty()) {
            try {
                update lineItemsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating line items: ' + e.getMessage());
            }
        }
    }
}