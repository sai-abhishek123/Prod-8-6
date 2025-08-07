public class LineItemTriggerHelper {
    private static Set<Id> processedDocIds = new Set<Id>();
    
    public static void afterInsert(List<bt_stripe__Line_Item__c> newLineItems) {
        handleAfterInsert(newLineItems);
    }
    
    public static void handleAfterInsert(List<bt_stripe__Line_Item__c> newItems) {
        CSISIntegrationManager.setLineItemProcessing(true);
        CSISIntegrationManager.setSkipParentTrigger(true);
        
        Set<String> orderExternalIds = new Set<String>();
        for (bt_stripe__Line_Item__c li : newItems) {
            if (String.isNotBlank(li.bt_stripe__Sales_Document__r.externalId__c)) {
                orderExternalIds.add(li.bt_stripe__Sales_Document__r.externalId__c);
            }
        }
        
        if (!orderExternalIds.isEmpty()) {
            Map<String, Object> params = new Map<String, Object>{
            'orderExternalIds' => new List<String>(orderExternalIds)
        };
        CSISScheduledQueueable.scheduleQueueableJob('CSISOrderQueueable', params, 3);
        }
    }

    public static void afterUpdate(List<bt_stripe__Line_Item__c> newLineItems, Map<Id, bt_stripe__Line_Item__c> oldMap) {
        CSISIntegrationManager.setSkipParentTrigger(true);
        CSISIntegrationManager.setLineItemProcessing(true);
        processLineItems(newLineItems, oldMap);
    }
    
    private static void processLineItems(List<bt_stripe__Line_Item__c> lineItems, Map<Id, bt_stripe__Line_Item__c> oldMap) {
        Set<Id> salesDocIds = new Set<Id>();
        Map<Id, Id> lineItemToAttendeeMap = new Map<Id, Id>();
        
        for (bt_stripe__Line_Item__c lineItem : lineItems) {
            if (lineItem.bt_stripe__Sales_Document__c != null) {
                boolean shouldProcess = true;
                
                if (processedDocIds.contains(lineItem.bt_stripe__Sales_Document__c)) {
                    shouldProcess = false;
                }
                
                if (oldMap != null) {
                    bt_stripe__Line_Item__c oldLineItem = oldMap.get(lineItem.Id);
                    
                    if (lineItem.bt_stripe__Quantity__c == oldLineItem.bt_stripe__Quantity__c && 
                        lineItem.bt_stripe__List_Price__c == oldLineItem.bt_stripe__List_Price__c &&
                        lineItem.bt_stripe__Tax_Amount__c == oldLineItem.bt_stripe__Tax_Amount__c &&
                        lineItem.conference360__Attendee__c == oldLineItem.conference360__Attendee__c &&
                        lineItem.Line_Item_Status__c == oldLineItem.Line_Item_Status__c) {
                        shouldProcess = false;
                    }
                }
                
                if (shouldProcess) {
                    salesDocIds.add(lineItem.bt_stripe__Sales_Document__c);
                    processedDocIds.add(lineItem.bt_stripe__Sales_Document__c);
                    
                    if (lineItem.conference360__Attendee__c != null) {
                        lineItemToAttendeeMap.put(lineItem.Id, lineItem.conference360__Attendee__c);
                    }
                }
            }
        }
        
        if (!salesDocIds.isEmpty()) {
            if (!lineItemToAttendeeMap.isEmpty()) {
                updateAttendeeInvoiceRelationship(salesDocIds, lineItemToAttendeeMap);
            }
            LineItemTriggerHandler.handleAfterChange(salesDocIds);
        }
    }
    
    private static void updateAttendeeInvoiceRelationship(Set<Id> salesDocIds, Map<Id, Id> lineItemToAttendeeMap) {
        try {
            List<conference360__Attendee__c> attendeesToUpdate = new List<conference360__Attendee__c>();
            Map<Id, Id> attendeeToInvoiceMap = new Map<Id, Id>();
            
            for (Id lineItemId : lineItemToAttendeeMap.keySet()) {
                Id attendeeId = lineItemToAttendeeMap.get(lineItemId);
                
                for (bt_stripe__Line_Item__c li : [SELECT Id, bt_stripe__Sales_Document__c, conference360__Attendee__c 
                                                  FROM bt_stripe__Line_Item__c 
                                                  WHERE Id = :lineItemId AND bt_stripe__Sales_Document__c IN :salesDocIds]) {
                    attendeeToInvoiceMap.put(li.conference360__Attendee__c, li.bt_stripe__Sales_Document__c);
                }
            }
            
            for (Id attendeeId : attendeeToInvoiceMap.keySet()) {
                attendeesToUpdate.add(new conference360__Attendee__c(
                    Id = attendeeId,
                    conference360__Sales_Document__c = attendeeToInvoiceMap.get(attendeeId)
                ));
            }
            
            if (!attendeesToUpdate.isEmpty()) {
                update attendeesToUpdate;
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error updating attendee invoice relationship: ' + ex.getMessage());
        }
    }
}