public class CSISEventQueueable extends CSISBaseQueueable {
    private List<conference360__Event__c> events;
    private Set<Id> specificAttendeeIds;

    public CSISEventQueueable(List<conference360__Event__c> events) {
        this(events, null);
    }

    public CSISEventQueueable(List<conference360__Event__c> events, Set<Id> specificAttendeeIds) {
        super(generateOperationId(events), 'EVENT');
        this.events = events;
        this.specificAttendeeIds = specificAttendeeIds;
    }

    @TestVisible
    private static String generateOperationId(List<conference360__Event__c> events) {
        if (events == null || events.isEmpty()) {
            return 'EVENT_' + DateTime.now().getTime();
        }

        List<String> eventIds = new List<String>();
        for (conference360__Event__c event : events) {
            eventIds.add(event.Id);
        }

        return 'EVENT_' + String.join(eventIds, '_');
    }

    public override void execute(QueueableContext context) {
        try {
            if (events == null || events.isEmpty()) {
                clearOperation(operationId);
                return;
            }

            Boolean success = CSISIntegration.sendEventsWithJWT(events, specificAttendeeIds);
            clearOperation(operationId);
        } catch (Exception ex) {
            handleError(ex, 'Events: ' + events.size());
        }
    }

    public static void enqueueEvents(List<Id> eventIds) {
        enqueueEvents(eventIds, null);
    }

    public static void enqueueEvents(List<Id> eventIds, List<Id> attendeeIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        Integer MAX_EVENTS_PER_BATCH = 5;
        List<List<Id>> eventBatches = new List<List<Id>>();
        List<Id> currentBatch = new List<Id>();

        for (Id eventId : eventIds) {
            currentBatch.add(eventId);
            if (currentBatch.size() >= MAX_EVENTS_PER_BATCH) {
                eventBatches.add(currentBatch);
                currentBatch = new List<Id>();
            }
        }
        if (!currentBatch.isEmpty()) {
            eventBatches.add(currentBatch);
        }

        if (!eventBatches.isEmpty()) {
            List<Id> firstBatch = eventBatches.remove(0);
            processEventBatch(firstBatch, attendeeIds, eventBatches, 1);
        }
    }

    @TestVisible
    private static void processEventBatch(List<Id> eventIdBatch, List<Id> attendeeIds, List<List<Id>> remainingBatches, Integer depth) {
        if (depth > 40) {
            System.debug(LoggingLevel.WARN, 'Maximum queue depth reached. Aborting further chaining.');
            return;
        }

        List<conference360__Event__c> events = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c,
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                   conference360__Organizer_Account__r.Computed_ID__c, Course_Offering__r.SectionNumber,
                   conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                   Event_Data_Sent_to_CSIS__c, CSIS_Transmission_Timestamp__c,
                   conference360__Organizer_Account__c, conference360__Organizer_Account__r.Acc_Number__c
            FROM conference360__Event__c
            WHERE Id IN :eventIdBatch
        ];

        if (!events.isEmpty()) {
            updateComputedIdAccountField(events);

            Set<Id> attendeeIdsSet = (attendeeIds != null && !attendeeIds.isEmpty()) ? new Set<Id>(attendeeIds) : null;
            System.enqueueJob(new CSISEventQueueable(events, attendeeIdsSet));

            if (!remainingBatches.isEmpty()) {
                List<Id> nextBatch = remainingBatches.remove(0);
                List<List<Id>> clonedRemaining = new List<List<Id>>(remainingBatches);

                System.enqueueJob(
                    new ChainedEventBatchQueueable(
                        nextBatch,
                        attendeeIds,
                        clonedRemaining,
                        depth + 1
                    )
                );
            }
        } else {
            System.debug(LoggingLevel.WARN, 'No events found for current batch. Stopping chaining.');
        }
    }

    @TestVisible
    private static void updateComputedIdAccountField(List<conference360__Event__c> events) {
        Set<Id> accountIds = new Set<Id>();
        Map<Id, conference360__Event__c> eventsToUpdateMap = new Map<Id, conference360__Event__c>();

        for (conference360__Event__c event : events) {
            if (event.conference360__Organizer_Account__c != null) {
                accountIds.add(event.conference360__Organizer_Account__c);
                eventsToUpdateMap.put(event.Id, event);
            }
        }

        if (accountIds.isEmpty()) return;

        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Computed_ID__c FROM Account WHERE Id IN :accountIds
        ]);

        List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
        for (conference360__Event__c event : eventsToUpdateMap.values()) {
            if (accountMap.containsKey(event.conference360__Organizer_Account__c) &&
                accountMap.get(event.conference360__Organizer_Account__c).Computed_ID__c != null) {
                eventsToUpdate.add(new conference360__Event__c(Id = event.Id));
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

    @TestVisible
    private class ChainedEventBatchQueueable implements Queueable {
        private List<Id> eventIdBatch;
        private List<Id> attendeeIds;
        private List<List<Id>> remainingBatches;
        private Integer depth;

        public ChainedEventBatchQueueable(List<Id> eventIdBatch, List<Id> attendeeIds, List<List<Id>> remainingBatches, Integer depth) {
            this.eventIdBatch = eventIdBatch;
            this.attendeeIds = attendeeIds;
            this.remainingBatches = remainingBatches;
            this.depth = depth;
        }

        public void execute(QueueableContext context) {
            CSISEventQueueable.processEventBatch(eventIdBatch, attendeeIds, remainingBatches, depth);
        }
    }
}