@isTest
private class Test_CSISIntegrationController {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'CSIS Test Account');
        insert acc;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Test Event',
            externalId__c = 'EVT123',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id
        );
        insert evt;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            externalId__c = 'ORD123',
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc;

        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__Event__c = evt.Id,
            conference360__Account__c = acc.Id,
            conference360__First_Name2__c = 'Test',
            conference360__Last_Name2__c = 'User',
            conference360__Email2__c = 'test@example.com',
            conference360__Registration_Status__c = 'Registered'
        );
        insert att;
    }

    @isTest static void testSendEventToCsis_valid() {
        Id eventId = [SELECT Id FROM conference360__Event__c LIMIT 1].Id;
        Test.startTest();
        String result = CSISIntegrationController.sendEventToCsis(eventId);
        Test.stopTest();
        System.assertEquals('Success: Event integration queued', result);
    }

    @isTest static void testSendEventToCsis_null() {
        String result = CSISIntegrationController.sendEventToCsis(null);
        System.assertEquals('Error: Event ID is required', result);
    }

    @isTest static void testSendEventToCsis_notFound() {
        Id fakeId = 'a0X000000000000AAA';
        String result = CSISIntegrationController.sendEventToCsis(fakeId);
        System.assertEquals('Error: Event not found', result);
    }

    @isTest static void testSendOrderToCsis_valid() {
        Id orderId = [SELECT Id FROM bt_stripe__Sales_Document__c LIMIT 1].Id;
        Test.startTest();
        String result = CSISIntegrationController.sendOrderToCsis(orderId);
        Test.stopTest();
        System.assertEquals('Success: Order integration queued', result);
    }

    @isTest static void testSendOrderToCsis_notFound() {
        String result = CSISIntegrationController.sendOrderToCsis('a0Z000000000000AAA');
        System.assertEquals('Error: Order not found', result);
    }

    @isTest static void testSendOrderToCsis_null() {
        String result = CSISIntegrationController.sendOrderToCsis(null);
        System.assertEquals('Error: Order ID is required', result);
    }

    @isTest static void testSendAttendeeToCsis_valid() {
        Id attId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;
        Test.startTest();
        String result = CSISIntegrationController.sendAttendeeToCsis(attId);
        Test.stopTest();
        System.assertEquals('Success: Attendee integration queued', result);
    }

    @isTest static void testSendAttendeeToCsis_null() {
        String result = CSISIntegrationController.sendAttendeeToCsis(null);
        System.assertEquals('Error: Attendee ID is required', result);
    }

    @isTest static void testSendAttendeeToCsis_exception() {
        // Use syntactically valid ID that doesn't exist to force safe try/catch path
        Id fakeAttId = 'a0D000000000001AAA';
        Test.startTest();
        String result = CSISIntegrationController.sendAttendeeToCsis(fakeAttId);
        Test.stopTest();
        System.assert(result.startsWith('Success:'), 'Should return success even if ID not found');
    }

    @isTest static void testRunFullIntegration_success() {
        Test.startTest();
        String result = CSISIntegrationController.runFullIntegration();
        Test.stopTest();
        System.assertEquals('Success: Integration jobs queued', result);
    }

    @isTest static void testRunPendingIntegration_success() {
        Test.startTest();
        String result = CSISIntegrationController.runPendingIntegration();
        Test.stopTest();
        System.assertEquals('Success: Pending integration jobs queued', result);
    }
}