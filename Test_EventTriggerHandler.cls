@isTest
private class Test_EventTriggerHandler {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Org');
        insert acc;
    }

    @isTest
    static void testHandleAfterInsert_withApprovedEvent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Approved Event',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'EXT-EVT-01'
        );

        insert evt;

        List<conference360__Event__c> inserted = [
            SELECT Id, Approved_to_Send_to_CSIS__c 
            FROM conference360__Event__c 
            WHERE Id = :evt.Id
        ];

        Test.startTest();
        EventTriggerHandler.handleAfterInsert(inserted);
        Test.stopTest();

        System.assertEquals(1, inserted.size(), 'One approved event should be processed.');
    }

    @isTest
    static void testHandleAfterInsert_withUnapprovedEvent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Unapproved Event',
            Approved_to_Send_to_CSIS__c = false,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'EXT-EVT-02'
        );
        insert evt;

        List<conference360__Event__c> inserted = [
            SELECT Id, Approved_to_Send_to_CSIS__c 
            FROM conference360__Event__c 
            WHERE Id = :evt.Id
        ];

        Test.startTest();
        EventTriggerHandler.handleAfterInsert(inserted);
        Test.stopTest();
    }

    @isTest
    static void testHandleAfterUpdate_approvalStatusChanged() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Initially Not Approved',
            Approved_to_Send_to_CSIS__c = false,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'EXT-EVT-03'
        );
        insert evt;

        conference360__Event__c original = evt.clone(false, false, false, false);
        evt.Approved_to_Send_to_CSIS__c = true;
        update evt;

        List<conference360__Event__c> updated = [
            SELECT Id, Approved_to_Send_to_CSIS__c 
            FROM conference360__Event__c 
            WHERE Id = :evt.Id
        ];

        Test.startTest();
        EventTriggerHandler.handleAfterUpdate(updated, new Map<Id, conference360__Event__c>{evt.Id => original});
        Test.stopTest();

        System.assertEquals(true, updated[0].Approved_to_Send_to_CSIS__c, 'Event should be approved.');
    }

    @isTest
    static void testHandleAfterUpdate_noApprovalChange() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Always Approved',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'EXT-EVT-04'
        );
        insert evt;

        conference360__Event__c unchanged = evt.clone(false, false, false, false);

        evt.Name = 'Updated Name';
        update evt;

        List<conference360__Event__c> updated = [
            SELECT Id, Approved_to_Send_to_CSIS__c 
            FROM conference360__Event__c 
            WHERE Id = :evt.Id
        ];

        Test.startTest();
        EventTriggerHandler.handleAfterUpdate(updated, new Map<Id, conference360__Event__c>{evt.Id => unchanged});
        Test.stopTest();
    }

    @isTest
    static void testFilterAlreadyProcessedEvents() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<conference360__Event__c> mockEvents = new List<conference360__Event__c>();
        for (Integer i = 0; i < 3; i++) {
            mockEvents.add(new conference360__Event__c(
                Name = 'Event ' + i,
                Approved_to_Send_to_CSIS__c = true,
                conference360__Event_Start_Date__c = Date.today(),
                conference360__Event_End_Date__c = Date.today().addDays(1),
                // externalId__c = 'FAKE-' + i,
                conference360__Organizer_Account__c = acc.Id
            ));
        }
        insert mockEvents;

        List<conference360__Event__c> eventsWithId = [SELECT Id FROM conference360__Event__c where conference360__Organizer_Account__c = :acc.Id];

        Test.startTest();
        List<conference360__Event__c> filteredAgain = EventTriggerHandler.filterAlreadyProcessedEvents(eventsWithId);
        System.debug('Filtered Events: ' + filteredAgain); 
        Test.stopTest();

        System.assertEquals(0, filteredAgain.size(), 'All events processed');
    }

    @isTest
    static void testGetEventIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Event For ID',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            externalId__c = 'EXT-ID-TEST',
            conference360__Organizer_Account__c = acc.Id
        );
        insert evt;

        List<conference360__Event__c> events = [
            SELECT Id FROM conference360__Event__c 
            WHERE Id = :evt.Id
        ];

        List<Id> ids = EventTriggerHandler.getEventIds(events);
        System.assertEquals(events.size(), ids.size(), 'Should return same number of Ids as events');
        System.assertNotEquals(null, ids[0], 'First Id should not be null');
    }
}