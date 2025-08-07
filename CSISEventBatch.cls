public class CSISEventBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private Boolean nonIntegratedOnly = false;
    private Date startDate;
    private Date endDate;
    
    public CSISEventBatch() {
        this(false);
    }
    
    public CSISEventBatch(Boolean nonIntegratedOnly) {
        this.nonIntegratedOnly = nonIntegratedOnly;
    }
    
    public CSISEventBatch(Date startDate, Date endDate) {
        this.startDate = startDate;
        this.endDate = endDate;
    }
    
    public static Id runBatch() {
        return Database.executeBatch(new CSISEventBatch(), 100);
    }
    
    public static Id runBatchForDateRange(Date startDate, Date endDate) {
        return Database.executeBatch(new CSISEventBatch(startDate, endDate), 100);
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, ' +
                      'conference360__Event_Start_Date__c, conference360__Event_End_Date__c, ' +
                      'Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, ' +
                      'Custom_Event_Page_URL__c, conference360__Organizer_Account__c, ' +
                      'conference360__Organizer_Account__r.Acc_Number__c, ' +
                      'Event_Data_Sent_to_CSIS__c, conference360__Organizer_Account__r.Computed_ID__c ' +
                      'FROM conference360__Event__c ' +
                      'WHERE Approved_to_Send_to_CSIS__c = true';
        
        if (nonIntegratedOnly) {
            query += ' AND (Event_Data_Sent_to_CSIS__c = false OR Event_Data_Sent_to_CSIS__c = null)';
        }
        if (startDate != null && endDate != null) {
            query += ' AND conference360__Event_Start_Date__c >= :startDate AND conference360__Event_Start_Date__c <= :endDate';
        }
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<conference360__Event__c> events = (List<conference360__Event__c>)scope;
        updateComputedIdAccountField(events);
        
        if (!System.isFuture() && !System.isQueueable()) {
            System.enqueueJob(new CSISEventQueueable(events));
        } else {
            CSISIntegration.sendEventsWithJWT(events);
        }
    }
    
    public void finish(Database.BatchableContext BC) {
    }
    
    @TestVisible
    private static void updateComputedIdAccountField(List<conference360__Event__c> events) {
    if (events == null || events.isEmpty()) {
        return;
    }
    
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
            
            String computedIdValue = accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c;
            
            conference360__Event__c updatedEvent = new conference360__Event__c(
                Id = event.Id
            );
            eventsToUpdate.add(updatedEvent);
        }
    }
    
    if (!eventsToUpdate.isEmpty()) {
        try {
            update eventsToUpdate;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error updating Computed_Id_Account__c: ' + ex.getMessage());
        }
    }
}
}