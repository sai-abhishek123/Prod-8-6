public class CSISUtility {
    public static Id sendAllEventsToCsis() {
        CSISBatchQueueable.runFullIntegration();
        return null;
    }
    
    public static Id sendNonIntegratedEventsToCsis() {
        System.enqueueJob(new CSISBatchQueueable('EVENT', 100, true));
        return null;
    }
    
    public static Id sendEventsByDateRange(Date startDate, Date endDate) {
        System.enqueueJob(new CSISBatchQueueable('EVENT', 100, startDate, endDate));
        return null;
    }
    
    public static Boolean sendSpecificEvents(List<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) {
            return false;
        }
        
        CSISEventQueueable.enqueueEvents(eventIds);
        return true;
    }
    
    public static Boolean sendSpecificAttendees(List<Id> attendeeIds) {
        if (attendeeIds == null || attendeeIds.isEmpty()) {
            return false;
        }
        
        CSISAttendeeQueueable.enqueueAttendees(attendeeIds);
        return true;
    }
    
    public static Boolean sendEventAttendees(Id eventId) {
        if (eventId == null) {
            return false;
        }
        
        return sendSpecificEvents(new List<Id>{eventId});
    }
    
    public static Id sendAllAttendeesToCsis() {
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, false));
        return null;
    }
    
    public static Id sendNonIntegratedAttendeesToCsis() {
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, true));
        return null;
    }
    
    public static Boolean sendAttendeesByRegAccountCode(String regAccountCode) {
        if (String.isBlank(regAccountCode)) {
            return false;
        }
        
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, regAccountCode));
        return true;
    }
    
    public static Id runBatchByRegAccountCode(String regAccountCode) {
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, regAccountCode));
        return null;
    }

    public static Boolean sendSpecificEventsAndAttendees(List<Id> eventIds, List<Id> attendeeIds) {
        if (eventIds == null || eventIds.isEmpty()) {
            return false;
        }
        
        CSISEventQueueable.enqueueEvents(eventIds, attendeeIds);
        return true;
    }
    
    public static Id sendAllOrdersToCsis() {
        System.enqueueJob(new CSISBatchQueueable('ORDER', 100, false));
        return null;
    }
    
    public static Id sendNonIntegratedOrdersToCsis() {
        System.enqueueJob(new CSISBatchQueueable('ORDER', 100, true));
        return null;
    }
    
    public static Boolean sendSpecificOrder(Id orderId) {
        if (orderId == null) {
            return false;
        }
        
        bt_stripe__Sales_Document__c order = [
            SELECT externalId__c 
            FROM bt_stripe__Sales_Document__c 
            WHERE Id = :orderId 
            LIMIT 1
        ];
        
        if (order == null || String.isBlank(order.externalId__c)) {
            return false;
        }
        
        System.enqueueJob(new CSISOrderQueueable(order.externalId__c));
        return true;
    }
    
    public static Boolean sendSpecificOrders(List<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return false;
        }
        
        List<bt_stripe__Sales_Document__c> orders = [
            SELECT externalId__c 
            FROM bt_stripe__Sales_Document__c 
            WHERE Id IN :orderIds
        ];
        
        if (orders.isEmpty()) {
            return false;
        }
        
        List<String> externalIds = new List<String>();
        for (bt_stripe__Sales_Document__c order : orders) {
            if (String.isNotBlank(order.externalId__c)) {
                externalIds.add(order.externalId__c);
            }
        }
        
        if (!externalIds.isEmpty()) {
            System.enqueueJob(new CSISOrderQueueable(externalIds));
            return true;
        }
        
        return false;
    }
    
    public static void updateComputedIdAccountField(List<conference360__Event__c> events) {
        Set<Id> accountIds = new Set<Id>();
        Map<Id, conference360__Event__c> eventsToUpdateMap = new Map<Id, conference360__Event__c>();
        
        for (conference360__Event__c event : events) {
            if (event.conference360__Organizer_Account__c != null) {
                accountIds.add(event.conference360__Organizer_Account__c);
                eventsToUpdateMap.put(event.Id, event);
            }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Computed_ID__c 
            FROM Account 
            WHERE Id IN :accountIds
        ]);
        
        List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
        for (conference360__Event__c event : eventsToUpdateMap.values()) {
            if (accountMap.containsKey(event.conference360__Organizer_Account__c) &&
                accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c != null) {
                
                conference360__Event__c updatedEvent = new conference360__Event__c(
                    Id = event.Id
                );
                eventsToUpdate.add(updatedEvent);
            }
        }
        
        if (!eventsToUpdate.isEmpty()) {
            // try {
                update eventsToUpdate;
                
                Map<Id, conference360__Event__c> refreshedEventsMap = new Map<Id, conference360__Event__c>([
                    SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                           conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                           conference360__Organizer_Account__r.Computed_ID__c, Course_Offering__r.SectionNumber, 
                           conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                           conference360__Organizer_Account__r.Acc_Number__c
                    FROM conference360__Event__c 
                    WHERE Id IN :eventsToUpdate
                ]);
                
                /*for (Integer i = 0; i < events.size(); i++) {
                    if (refreshedEventsMap.containsKey(events[i].Id)) {
                        // events[i].Computed_Id_Account__c = refreshedEventsMap.get(events[i].Id).Computed_Id_Account__c;
                    }
                }*/
                
            /*} catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error updating Computed_Id_Account__c: ' + ex.getMessage());
            }*/
        }
    }
}