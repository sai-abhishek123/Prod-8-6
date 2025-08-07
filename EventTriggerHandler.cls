public class EventTriggerHandler {
    private static Set<Id> processedEventIds = new Set<Id>();
    
    public static void handleAfterInsert(List<conference360__Event__c> newEvents) {
        List<conference360__Event__c> approvedEvents = new List<conference360__Event__c>();
        
        for (conference360__Event__c event : newEvents) {
            if (event.Approved_to_Send_to_CSIS__c == true) {
                approvedEvents.add(event);
            }
        }
        
        List<conference360__Event__c> filteredEvents = filterAlreadyProcessedEvents(approvedEvents);
        
        if (!filteredEvents.isEmpty()) {
            if (!Test.isRunningTest()) {
                CSISEventQueueable.enqueueEvents(getEventIds(filteredEvents));
            } else {
                CSISIntegration.sendEventsWithJWT(filteredEvents);
            }
        }
    }
    
    public static void handleAfterUpdate(List<conference360__Event__c> newEvents, 
                                       Map<Id, conference360__Event__c> oldMap) {
        List<conference360__Event__c> eventsToSync = new List<conference360__Event__c>();
        
        for (conference360__Event__c newEvent : newEvents) {
            if (processedEventIds.contains(newEvent.Id)) {
                continue;
            }
            
            conference360__Event__c oldEvent = oldMap.get(newEvent.Id);
            
            if (oldEvent.Approved_to_Send_to_CSIS__c == false && newEvent.Approved_to_Send_to_CSIS__c == true) {
                eventsToSync.add(newEvent);
            }
        }
        
        if (!eventsToSync.isEmpty()) {
            if (!Test.isRunningTest()) {
                CSISEventQueueable.enqueueEvents(getEventIds(eventsToSync));
            } else {
                CSISIntegration.sendEventsWithJWT(eventsToSync);
            }
        }
    }
    @TestVisible
    private static List<conference360__Event__c> filterAlreadyProcessedEvents(List<conference360__Event__c> events) {
        List<conference360__Event__c> filteredEvents = new List<conference360__Event__c>();
        
        for (conference360__Event__c event : events) {
            if (!processedEventIds.contains(event.Id)) {
                filteredEvents.add(event);
                processedEventIds.add(event.Id);
            }
        }
        
        return filteredEvents;
    }
    @TestVisible
    private static List<Id> getEventIds(List<conference360__Event__c> events) {
        List<Id> eventIds = new List<Id>();
        for (conference360__Event__c event : events) {
            eventIds.add(event.Id);
        }
        return eventIds;
    }
}