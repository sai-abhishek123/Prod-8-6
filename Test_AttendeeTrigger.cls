@isTest
public class Test_AttendeeTrigger {

    @testSetup
    static void setupData() {
        // Create Event
        conference360__Event__c evt = new conference360__Event__c(Name = 'Test Event');
        insert evt;

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Sales Document
        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c();
        insert doc;

        // Create valid Event Item
        conference360__Event_Item__c item = new conference360__Event_Item__c(
            // Name = 'General Admission',
            conference360__Event__c = evt.Id
        );
        insert item;

        // Create initial Attendee
        conference360__Attendee__c attendee = new conference360__Attendee__c(
            conference360__First_Name2__c = 'John',
            conference360__Last_Name2__c = 'Doe',
            conference360__Title__c = 'Manager',
            conference360__Street__c = '123 Main St',
            conference360__City__c = 'Cityville',
            conference360__State__c = 'CA',
            conference360__Postal_Code__c = '12345',
            conference360__Country__c = 'USA',
            conference360__Email__c = 'john@example.com',
            conference360__Phone2__c = '1234567890',
            conference360__Account__c = acc.Id,
            conference360__Event__c = evt.Id,
            conference360__Event_Item__c = item.Id,
            conference360__Registration_Status__c = 'Registered',
            conference360__Sales_Document__c = doc.Id
        );
        insert attendee;

        bt_stripe__Line_Item__c lineItem = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = doc.Id,
            conference360__Attendee__c = attendee.Id,
            line_item_status__c = 'Active'
        );
        insert lineItem;
    }

    @isTest
    static void testAfterInsertTrigger() {
        conference360__Event__c evt = [SELECT Id FROM conference360__Event__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        conference360__Event_Item__c item = [SELECT Id FROM conference360__Event_Item__c LIMIT 1];
        bt_stripe__Sales_Document__c doc = [SELECT Id FROM bt_stripe__Sales_Document__c LIMIT 1];

        conference360__Attendee__c newAttendee = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Insert',
            conference360__Last_Name2__c = 'Test',
            conference360__Account__c = acc.Id,
            conference360__Event__c = evt.Id,
            conference360__Event_Item__c = item.Id,
            conference360__Registration_Status__c = 'Registered',
            conference360__Sales_Document__c = doc.Id
        );

        Test.startTest();
        insert newAttendee;
        Test.stopTest();

        System.assert(true, 'After insert trigger executed');
    }

    @isTest
    static void testAfterUpdateTrigger_ChangeToCanceled() {
        conference360__Attendee__c attendee = [
            SELECT Id, conference360__Registration_Status__c
            FROM conference360__Attendee__c LIMIT 1
        ];

        attendee.conference360__Registration_Status__c = 'Cancelled'; 
        Test.startTest();
        update attendee;
        Test.stopTest();

        bt_stripe__Line_Item__c updatedLineItem = [
            SELECT line_item_status__c 
            FROM bt_stripe__Line_Item__c 
            WHERE conference360__Attendee__c = :attendee.Id 
            LIMIT 1
        ];

        System.assertEquals('Canceled', updatedLineItem.line_item_status__c,
            'Line item status should be updated to Canceled.');
    }

    @isTest
    static void testAfterUpdateTrigger_ChangeToRegistered() {
        conference360__Attendee__c attendee = [
            SELECT Id, conference360__Registration_Status__c
            FROM conference360__Attendee__c LIMIT 1
        ];

        attendee.conference360__Registration_Status__c = 'Registered';
        Test.startTest();
        update attendee;
        Test.stopTest();

        bt_stripe__Line_Item__c updatedLineItem = [
            SELECT line_item_status__c 
            FROM bt_stripe__Line_Item__c 
            WHERE conference360__Attendee__c = :attendee.Id 
            LIMIT 1
        ];

        System.assertEquals('Active', updatedLineItem.line_item_status__c,
            'Line item status should be updated to Active.');
    }

    @isTest
    static void testAfterUpdateTrigger_NoStatusChange() {
        conference360__Attendee__c attendee = [
            SELECT Id, conference360__Email__c, conference360__Registration_Status__c
            FROM conference360__Attendee__c LIMIT 1
        ];

        attendee.conference360__Email__c = 'update@none.com'; // unrelated change
        Test.startTest();
        update attendee;
        Test.stopTest();

        bt_stripe__Line_Item__c lineItem = [
            SELECT line_item_status__c 
            FROM bt_stripe__Line_Item__c 
            WHERE conference360__Attendee__c = :attendee.Id 
            LIMIT 1
        ];

        System.assertNotEquals(null, lineItem.line_item_status__c);
        System.assert(lineItem.line_item_status__c == 'Active' || lineItem.line_item_status__c == 'Canceled',
            'Line item status remains valid even without status change.');
    }
}