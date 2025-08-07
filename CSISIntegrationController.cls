public class CSISIntegrationController {
    
    @AuraEnabled
    public static String sendEventToCsis(Id eventId) {
        try {
            if (eventId == null) {
                return 'Error: Event ID is required';
            }
            
            List<conference360__Event__c> events = [
                SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, 
                       conference360__Event_Start_Date__c, conference360__Event_End_Date__c, 
                       Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, Event_ID__c,
                       Custom_Event_Page_URL__c, conference360__Organizer_Account__r.Computed_ID__c
                FROM conference360__Event__c 
                WHERE Id = :eventId
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                return 'Error: Event not found';
            }
            
            System.enqueueJob(new CSISEventQueueable(events));
            return 'Success: Event integration queued';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String sendOrderToCsis(Id orderId) {
        try {
            if (orderId == null) {
                return 'Error: Order ID is required';
            }
            
            List<bt_stripe__Sales_Document__c> orders = [
                SELECT Id, externalId__c 
                FROM bt_stripe__Sales_Document__c 
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            if (orders.isEmpty()) {
                return 'Error: Order not found';
            }
            
            if (String.isBlank(orders[0].externalId__c)) {
                return 'Error: Order does not have an external ID';
            }
            
            System.enqueueJob(new CSISOrderQueueable(orders[0].externalId__c));
            return 'Success: Order integration queued';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String sendAttendeeToCsis(Id attendeeId) {
        try {
            if (attendeeId == null) {
                return 'Error: Attendee ID is required';
            }
            
            CSISAttendeeQueueable.enqueueAttendees(new List<Id>{attendeeId});
            return 'Success: Attendee integration queued';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String runFullIntegration() {
        try {
            CSISBatchQueueable.runFullIntegration();
            return 'Success: Integration jobs queued';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String runPendingIntegration() {
        try {
            CSISBatchQueueable.runPendingIntegration();
            return 'Success: Pending integration jobs queued';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
}