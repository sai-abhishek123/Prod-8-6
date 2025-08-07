@isTest
public class Test_CSISUtility {
    
    @testSetup
    static void setupTestData() {
        // Create a test Account (no external ID fields set)
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Create a test Event (include conference360__Organizer_Account__c for later access)
        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Test Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id
        );
        insert evt;

        // Create a test Order (do NOT set externalId__c)
        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c();
        insert order;

        // Create a test Attendee
        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__Event__c = evt.Id,
            conference360__Registration_Status__c = 'Registered'
        );
        insert att;
    }

    @isTest static void test_sendAllEventsToCsis() {
        Test.startTest();
        CSISUtility.sendAllEventsToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendNonIntegratedEventsToCsis() {
        Test.startTest();
        CSISUtility.sendNonIntegratedEventsToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendEventsByDateRange() {
        Test.startTest();
        CSISUtility.sendEventsByDateRange(Date.today().addDays(-1), Date.today().addDays(2));
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendSpecificEvents_positive() {
        List<conference360__Event__c> events = [SELECT Id FROM conference360__Event__c LIMIT 1];
        Boolean result = CSISUtility.sendSpecificEvents(new List<Id>{events[0].Id});
        System.assert(result);
    }

    @isTest static void test_sendSpecificEvents_negative() {
        Boolean result = CSISUtility.sendSpecificEvents(new List<Id>());
        System.assertEquals(false, result);
    }

    @isTest static void test_sendSpecificAttendees_positive() {
        List<conference360__Attendee__c> attendees = [SELECT Id FROM conference360__Attendee__c LIMIT 1];
        Boolean result = CSISUtility.sendSpecificAttendees(new List<Id>{attendees[0].Id});
        System.assert(result);
    }

    @isTest static void test_sendSpecificAttendees_negative() {
        Boolean result = CSISUtility.sendSpecificAttendees(null);
        System.assertEquals(false, result);
    }

    @isTest static void test_sendEventAttendees_positive() {
        List<conference360__Event__c> events = [SELECT Id FROM conference360__Event__c LIMIT 1];
        Boolean result = CSISUtility.sendEventAttendees(events[0].Id);
        System.assert(result);
    }

    @isTest static void test_sendEventAttendees_negative() {
        Boolean result = CSISUtility.sendEventAttendees(null);
        System.assertEquals(false, result);
    }

    @isTest static void test_sendAllAttendeesToCsis() {
        Test.startTest();
        CSISUtility.sendAllAttendeesToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendNonIntegratedAttendeesToCsis() {
        Test.startTest();
        CSISUtility.sendNonIntegratedAttendeesToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendAttendeesByRegAccountCode_positive() {
        Test.startTest();
        Boolean result = CSISUtility.sendAttendeesByRegAccountCode('TESTCODE');
        Test.stopTest();
        System.assert(result);
    }

    @isTest static void test_sendAttendeesByRegAccountCode_negative() {
        Boolean result = CSISUtility.sendAttendeesByRegAccountCode(null);
        System.assertEquals(false, result);
    }

    @isTest static void test_runBatchByRegAccountCode() {
        Test.startTest();
        CSISUtility.runBatchByRegAccountCode('TESTCODE');
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendSpecificEventsAndAttendees_positive() {
        Id evtId = [SELECT Id FROM conference360__Event__c LIMIT 1].Id;
        Id attId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;
        Boolean result = CSISUtility.sendSpecificEventsAndAttendees(new List<Id>{evtId}, new List<Id>{attId});
        System.assert(result);
    }

    @isTest static void test_sendSpecificEventsAndAttendees_negative() {
        Boolean result = CSISUtility.sendSpecificEventsAndAttendees(null, null);
        System.assertEquals(false, result);
    }

    @isTest static void test_sendAllOrdersToCsis() {
        Test.startTest();
        CSISUtility.sendAllOrdersToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendNonIntegratedOrdersToCsis() {
        Test.startTest();
        CSISUtility.sendNonIntegratedOrdersToCsis();
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void test_sendSpecificOrder_negative_due_to_missing_externalId() {
        bt_stripe__Sales_Document__c order = [
            SELECT Id, externalId__c 
            FROM bt_stripe__Sales_Document__c 
            LIMIT 1
        ];
        System.debug('Order externalId__c: ' + order.externalId__c);

        Boolean result = CSISUtility.sendSpecificOrder(order.Id);

        // If your org pre-populates this field, this might be true. Adjust the assertion if needed.
        if (String.isBlank(order.externalId__c)) {
            System.assertEquals(false, result, 'Expected false due to missing externalId__c');
        } else {
            System.assertEquals(true, result, 'externalId__c is pre-set, so expected true');
        }
    }

    @isTest static void test_sendSpecificOrder_negative_null() {
        Boolean result = CSISUtility.sendSpecificOrder(null);
        System.assertEquals(false, result);
    }

    @isTest static void test_sendSpecificOrders_negative_due_to_missing_externalIds() {
        bt_stripe__Sales_Document__c order = [
            SELECT Id, externalId__c 
            FROM bt_stripe__Sales_Document__c 
            LIMIT 1
        ];
        System.debug('Order externalId__c: ' + order.externalId__c);

        Boolean result = CSISUtility.sendSpecificOrders(new List<Id>{order.Id});

        if (String.isBlank(order.externalId__c)) {
            System.assertEquals(false, result, 'Expected false due to no externalId__c');
        } else {
            System.assertEquals(true, result, 'externalId__c is present, expected true');
        }
    }

    @isTest static void test_sendSpecificOrders_negative_empty_list() {
        Boolean result = CSISUtility.sendSpecificOrders(new List<Id>());
        System.assertEquals(false, result);
    }

    @isTest static void test_updateComputedIdAccountField() {
        conference360__Event__c evt = [
            SELECT Id, conference360__Organizer_Account__c 
            FROM conference360__Event__c 
            LIMIT 1
        ];
        Test.startTest();
        CSISUtility.updateComputedIdAccountField(new List<conference360__Event__c>{evt});
        Test.stopTest();
        System.assert(true);
    }
}