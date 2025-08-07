@isTest
private class Test_CSISIntegration {

    class CSISMockResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true}');
            return res;
        }
    }

    private static conference360__Attendee__c createTestAttendee(Id eventId, Id accountId, String status) {
        return new conference360__Attendee__c(
            conference360__First_Name2__c = 'Jane',
            conference360__Last_Name2__c = 'Doe',
            conference360__Email2__c = 'jane.doe@example.com',
            conference360__Registration_Status__c = status,
            conference360__Event__c = eventId,
            conference360__Account__c = accountId
        );
    }

    @isTest
    static void testSendEventsWithJWT_HttpCalloutPath() {
        Test.setMock(HttpCalloutMock.class, new CSISMockResponseGenerator());

        Account account = new Account(Name = 'Org Account');
        insert account;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Sample Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Status__c = 'Active',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Organizer_Account__c = account.Id
        );
        insert evt;

        conference360__Attendee__c attendee = createTestAttendee(evt.Id, account.Id, 'Registered');
        insert attendee;

        Test.startTest();
        Boolean result = CSISIntegration.sendEventsWithJWT(new List<conference360__Event__c>{evt}, new Set<Id>{attendee.Id});
        Test.stopTest();

        System.assert(result, 'Expected sendEventsWithJWT to succeed');
    }

    @isTest
    static void testSendOrderToCsis_WithAttendee() {
        Test.setMock(HttpCalloutMock.class, new CSISMockResponseGenerator());

        Account billTo = new Account(Name = 'Billing Account');
        insert billTo;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Event with Order',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Status__c = 'Active',
            Approved_to_Send_to_CSIS__c = true
        );
        insert evt;

        conference360__Attendee__c attendee = createTestAttendee(evt.Id, billTo.Id, 'Registered');
        insert attendee;

        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = billTo.Id,
            conference360__Event__c = evt.Id
        );
        insert order;

        // Get actual externalId__c populated by system (if available)
        order = [SELECT Id, externalId__c FROM bt_stripe__Sales_Document__c WHERE Id = :order.Id LIMIT 1];

        bt_stripe__Line_Item__c item = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = order.Id,
            bt_stripe__Item_Name__c = 'Fee',
            conference360__Attendee__c = attendee.Id
        );
        insert item;

        Test.startTest();
        Boolean result = CSISIntegration.sendOrderToCsis(order.externalId__c, attendee.Id);
        Test.stopTest();

        System.assert(result, 'Expected sendOrderToCsis to succeed');
    }

    @isTest
    static void testSendOrderToCsis_InvalidId() {
        Test.startTest();
        Boolean result = CSISIntegration.sendOrderToCsis(null);
        Test.stopTest();

        System.assertEquals(false, result, 'Expected false when orderExternalId is null');
    }
    @isTest
    static void testSendOrderToCsis_SubstitutionMapping() {
        Test.setMock(HttpCalloutMock.class, new CSISMockResponseGenerator());

        Account acct = new Account(Name = 'Test Account');
        insert acct;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Substitution Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(2),
            conference360__Status__c = 'Active',
            Approved_to_Send_to_CSIS__c = true
        );
        insert evt;

        // Substitute attendee (will be cancelled)
        conference360__Attendee__c cancelledSub = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Old',
            conference360__Last_Name2__c = 'Registrant',
            conference360__Registration_Status__c = 'Cancelled - Substitute',
            conference360__Event__c = evt.Id,
            conference360__Account__c = acct.Id
        );

        // Replacement attendee (will be mapped)
        conference360__Attendee__c replacement = new conference360__Attendee__c(
            conference360__First_Name2__c = 'New',
            conference360__Last_Name2__c = 'Registrant',
            conference360__Registration_Status__c = 'Registered',
            conference360__Event__c = evt.Id,
            conference360__Account__c = acct.Id
        );

        insert new List<conference360__Attendee__c>{cancelledSub, replacement};

        // Create order
        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = acct.Id,
            conference360__Event__c = evt.Id
        );
        insert order;

        // Refresh externalId__c
        order = [SELECT Id, externalId__c FROM bt_stripe__Sales_Document__c WHERE Id = :order.Id LIMIT 1];

        // Create line item assigned to replacement attendee (not the cancelled one)
        bt_stripe__Line_Item__c item = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = order.Id,
            bt_stripe__Item_Name__c = 'Registration Fee',
            conference360__Attendee__c = replacement.Id
        );
        insert item;

        Test.startTest();
        Boolean result = CSISIntegration.sendOrderToCsis(order.externalId__c, cancelledSub.Id);
        Test.stopTest();

        System.assert(result, 'Expected substitution mapping logic to execute and return true');
    }

    @isTest
    static void testUpdateLineItemStatusForAttendee() {
        // Setup test data
        Account acct = new Account(Name = 'Test Billing');
        insert acct;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Status Update Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Status__c = 'Active',
            Approved_to_Send_to_CSIS__c = true
        );
        insert evt;

        conference360__Attendee__c attendee = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Test',
            conference360__Last_Name2__c = 'Attendee',
            conference360__Email2__c = 'test@example.com',
            conference360__Registration_Status__c = 'Registered',
            conference360__Event__c = evt.Id,
            conference360__Account__c = acct.Id
        );
        insert attendee;

        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = acct.Id,
            conference360__Event__c = evt.Id
        );
        insert order;

        bt_stripe__Line_Item__c item = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = order.Id,
            bt_stripe__Item_Name__c = 'Test Fee',
            conference360__Attendee__c = attendee.Id
        );
        insert item;

        // Call the method under test
        Test.startTest();
        CSISIntegration.updateLineItemStatusForAttendee(order.Id, attendee.Id, 'Canceled');
        Test.stopTest();

        // Verify the update happened
        bt_stripe__Line_Item__c updatedItem = [
            SELECT Id, Line_Item_Status__c 
            FROM bt_stripe__Line_Item__c 
            WHERE Id = :item.Id
        ];
        System.assertEquals('Canceled', updatedItem.Line_Item_Status__c, 'Expected line item status to be updated');
    }
    @isTest
    static void testIsGroupOrderWithMixedStatuses() {
        // Setup
        Account acct = new Account(Name = 'Test Org');
        insert acct;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Group Order Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Status__c = 'Active',
            Approved_to_Send_to_CSIS__c = true
        );
        insert evt;

        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = acct.Id,
            conference360__Event__c = evt.Id
        );
        insert order;

        // Attendee 1: Cancelled
        conference360__Attendee__c cancelledAttendee = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Cancel',
            conference360__Last_Name2__c = 'Me',
            conference360__Registration_Status__c = 'Cancelled',
            conference360__Sales_Document__c = order.Id,
            conference360__Event__c = evt.Id,
            conference360__Account__c = acct.Id
        );

        // Attendee 2: Registered (should trigger mixed status = true)
        conference360__Attendee__c activeAttendee = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Active',
            conference360__Last_Name2__c = 'Person',
            conference360__Registration_Status__c = 'Registered',
            conference360__Sales_Document__c = order.Id,
            conference360__Event__c = evt.Id,
            conference360__Account__c = acct.Id
        );

        insert new List<conference360__Attendee__c>{cancelledAttendee, activeAttendee};

        Test.startTest();
        Boolean result = CSISIntegration.isGroupOrderWithMixedStatuses(order.Id, cancelledAttendee, 'Cancelled');
        Test.stopTest();

        System.assertEquals(true, result, 'Expected true: group order has mixed statuses');
    }
}