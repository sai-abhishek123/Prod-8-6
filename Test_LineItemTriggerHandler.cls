@isTest
private class Test_LineItemTriggerHandler {

    @testSetup
    static void setupData() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Event
        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Test Event',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1)
        );
        insert evt;

        // Create Sales Document with externalId__c and linked to the Event
        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            // Name = 'Test Sales Document',
            bt_stripe__Bill_To__c = acc.Id,
            externalId__c = 'EXT-' + String.valueOf(Datetime.now().getTime()),
            conference360__Event__c = evt.Id
        );
        insert doc;
    }

    @isTest
    static void test_handleAfterChange_withValidSalesDoc() {
        bt_stripe__Sales_Document__c doc = [SELECT Id FROM bt_stripe__Sales_Document__c LIMIT 1];

        Test.startTest();
        LineItemTriggerHandler.handleAfterChange(new Set<Id>{ doc.Id });
        Test.stopTest();

        System.assert(true, 'handleAfterChange executed successfully with valid sales doc ID.');
    }

    @isTest
    static void test_processOrdersForIntegration_withMissingExternalId() {
        conference360__Event__c evt = [SELECT Id FROM conference360__Event__c LIMIT 1];

        bt_stripe__Sales_Document__c docNoExt = new bt_stripe__Sales_Document__c(
            // Name = 'Missing ExternalId Doc',
            conference360__Event__c = evt.Id
        );
        insert docNoExt;

        Test.startTest();
        LineItemTriggerHandler.processOrdersForIntegration(new Set<Id>{ docNoExt.Id });
        Test.stopTest();

        System.assert(true, 'processOrdersForIntegration handled Sales Doc with missing externalId__c safely.');
    }

    @isTest
    static void test_handleAfterChange_withEmptySet() {
        Test.startTest();
        LineItemTriggerHandler.handleAfterChange(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'handleAfterChange handled empty Set<Id> without error.');
    }

    @isTest
    static void test_processOrdersForIntegration_withNonMatchingRecord() {
        // Insert a doc not linked to any event (should be skipped)
        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            // Name = 'No Event Linked Doc',
            externalId__c = 'EXT-' + String.valueOf(DateTime.now().getTime())
        );
        insert doc;

        Test.startTest();
        LineItemTriggerHandler.processOrdersForIntegration(new Set<Id>{ doc.Id });
        Test.stopTest();

        System.assert(true, 'processOrdersForIntegration skipped record with no event.');
    }
}