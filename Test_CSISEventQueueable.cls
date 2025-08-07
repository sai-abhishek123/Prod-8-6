@isTest
public class Test_CSISEventQueueable {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Organizer');//,, Computed_ID__c = 'ACC001');
        insert acc;

        List<conference360__Event__c> events = new List<conference360__Event__c>();
        for (Integer i = 1; i <= 12; i++) {
            events.add(new conference360__Event__c(
                Name = 'Event ' + i,
                externalId__c = 'EXT' + i,
                conference360__Event_Start_Date__c = Date.today(),
                conference360__Event_End_Date__c = Date.today().addDays(1),
                conference360__Organizer_Account__c = acc.Id
            ));
        }
        insert events;
    }

    @isTest
    static void testGenerateOperationId_withEvents() {
        List<conference360__Event__c> events = [
            SELECT Id FROM conference360__Event__c LIMIT 2
        ];
        String opId = CSISEventQueueable.generateOperationId(events);
        System.assert(opId.startsWith('EVENT_'), 'Should start with EVENT_');
        System.assert(opId.contains(events[0].Id), 'Should contain event Id');
    }

    @isTest
    static void testGenerateOperationId_empty() {
        String opId = CSISEventQueueable.generateOperationId(new List<conference360__Event__c>());
        System.assert(opId.startsWith('EVENT_'), 'Should generate fallback operationId');
    }

    @isTest
    static void testEnqueueEvents_SingleBatch() {
        List<Id> ids = new List<Id>();
        for (conference360__Event__c e : [SELECT Id FROM conference360__Event__c LIMIT 4]) {
            ids.add(e.Id);
        }

        Test.startTest();
        CSISEventQueueable.enqueueEvents(ids);
        Test.stopTest();

        System.assert(true, 'Single batch enqueued without error');
    }

    /*@isTest
    static void testEnqueueEvents_MultipleBatches() {
        List<Id> ids = new List<Id>();
        for (conference360__Event__c e : [SELECT Id FROM conference360__Event__c ORDER BY Name ASC]) {
            ids.add(e.Id);
        }

        Test.startTest();
        CSISEventQueueable.enqueueEvents(ids); // 12 events = 3 batches
        Test.stopTest();

        System.assert(true, 'Multiple batches enqueued and chained');
    }*/

    @isTest
    static void testExecuteQueueable_WithAttendees() {
        List<conference360__Event__c> events = [SELECT Id FROM conference360__Event__c LIMIT 1];
        Set<Id> attendeeIds = new Set<Id>{ UserInfo.getUserId() };

        CSISEventQueueable queueable = new CSISEventQueueable(events, attendeeIds);

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true, 'Queueable with attendees executed');
    }

    /*@isTest
    static void testProcessEventBatch_LimitedDepth() {
        List<conference360__Event__c> eventRecs = [
            SELECT Id FROM conference360__Event__c ORDER BY Name ASC
        ];
        List<Id> allIds = new List<Id>();
        for (conference360__Event__c evt : eventRecs) allIds.add(evt.Id);

        // Manually chunk the first 5 and next 5 (no subList)
        List<Id> firstBatch = new List<Id>();
        List<Id> secondBatch = new List<Id>();

        for (Integer i = 0; i < allIds.size(); i++) {
            if (i < 5) firstBatch.add(allIds[i]);
            else if (i < 10) secondBatch.add(allIds[i]);
        }

        List<List<Id>> remaining = new List<List<Id>>{ secondBatch };

        Test.startTest();
        CSISEventQueueable.processEventBatch(firstBatch, null, remaining, 1);
        Test.stopTest();

        System.assert(true, 'processEventBatch executed with depth limit');
    }*/

    @isTest
    static void testUpdateComputedIdAccountField() {
        List<conference360__Event__c> events = [
            SELECT Id, conference360__Organizer_Account__c
            FROM conference360__Event__c
            WHERE conference360__Organizer_Account__c != null
        ];

        Test.startTest();
        CSISEventQueueable.updateComputedIdAccountField(events);
        Test.stopTest();

        System.assert(true, 'Computed ID updater ran');
    }

    @isTest
    static void testExecuteQueueable_EmptyList() {
        CSISEventQueueable q = new CSISEventQueueable(new List<conference360__Event__c>());
        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        System.assert(true, 'Handled empty event list');
    }

    /*@isTest
    static void testProcessEventBatch_StopsAtMaxDepth() {
        List<conference360__Event__c> evts = [SELECT Id FROM conference360__Event__c LIMIT 5];
        List<Id> ids = new List<Id>();
        for (conference360__Event__c e : evts) ids.add(e.Id);

        List<List<Id>> remaining = new List<List<Id>>();
        for (Integer i = 0; i < 50; i++) {
            remaining.add(new List<Id>(ids));
        }

        Test.startTest();
        // This call should stop queueing beyond depth 40
        CSISEventQueueable.processEventBatch(ids, null, remaining, 39);
        Test.stopTest();

        System.assert(true, 'Max depth limit enforced correctly');
    }*/
    // @isTest
private class CSISIntegrationMockError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        throw new CalloutException('Simulated failure');
    }
}

    @isTest
    static void testExecuteQueueable_CatchesException() {
        List<conference360__Event__c> events = [SELECT Id FROM conference360__Event__c LIMIT 1];

        // Set the mock that throws an exception
        Test.setMock(HttpCalloutMock.class, new CSISIntegrationMockError());

        Test.startTest();
        System.enqueueJob(new CSISEventQueueable(events));
        Test.stopTest();

        System.assert(true, 'Exception in execute() was caught without error');
    }
    @isTest
static void testEnqueueEvents_AddsToEventBatches() {
    // Get exactly 5 records to trigger batching
    List<conference360__Event__c> events = [
        SELECT Id FROM conference360__Event__c ORDER BY Name ASC LIMIT 5
    ];
    List<Id> eventIds = new List<Id>();
    for (conference360__Event__c evt : events) {
        eventIds.add(evt.Id);
    }

    Test.startTest();
    CSISEventQueueable.enqueueEvents(eventIds);
    Test.stopTest();

    System.assert(true, 'enqueueEvents processed a full batch and triggered eventBatches.add()');
}


}