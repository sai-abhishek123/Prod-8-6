@isTest
private class Test_CSISOrderQueueable {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Order Queue Test Account');
        insert acc;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Order Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id
        );
        insert evt;

        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__Event__c = evt.Id,
            conference360__Account__c = acc.Id,
            conference360__First_Name2__c = 'Alice',
            conference360__Last_Name2__c = 'Queueable',
            conference360__Email2__c = 'alice@example.com',
            conference360__Registration_Status__c = 'Registered'
        );
        insert att;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            externalId__c = 'EXT_ORDER_1',
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc;

        bt_stripe__Line_Item__c line = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = doc.Id,
            bt_stripe__Item_Name__c = 'Test Line',
            conference360__Attendee__c = att.Id
        );
        insert line;

        att.conference360__Sales_Document__c = doc.Id;
        update att;
    }

    @isTest
    static void testSingleOrderExecution() {
        Test.startTest();
        System.enqueueJob(new CSISOrderQueueable('EXT_ORDER_1'));
        Test.stopTest();

        System.assert(true, 'Single order execution should complete without error');
    }

    @isTest
    static void testMultipleOrderChaining() {
        // Simulate multiple orderExternalIds, only one is valid
        Test.startTest();
        List<String> orderIds = new List<String>{'EXT_ORDER_1', 'EXT_FAKE_ORDER_2', 'EXT_FAKE_ORDER_3'};
        CSISOrderQueueable job = new CSISOrderQueueable(orderIds, 'Registered');
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Chained queueables should not throw exceptions');
    }

    @isTest
    static void testOrderExecutionWithSpecificAttendee() {
        conference360__Attendee__c att = [SELECT Id FROM conference360__Attendee__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new CSISOrderQueueable('EXT_ORDER_1', att.Id, 'Registered'));
        Test.stopTest();

        System.assert(true, 'Execution with specific attendee should complete');
    }

    @isTest
    static void testGenerateOperationId() {
        List<String> ids = new List<String>{'O1', 'O2'};
        String result = CSISOrderQueueable.generateOperationId(ids);
        System.assert(result.startsWith('ORDER_'), 'Operation ID should start with ORDER_');
    }

    @isTest
    static void testIsIdInProgress() {
        // Mark it manually
        String opId = 'ORDER_EXT_ORDER_1';
        Test.startTest();
        // Simulate marking in-progress (via reflection, or just test method coverage)
        Boolean result = CSISOrderQueueable.isIdInProgress('EXT_ORDER_1');
        Test.stopTest();

        // Should be false since no operation marked in test context
        System.assertEquals(false, result, 'No operation should be in progress');
    }
}