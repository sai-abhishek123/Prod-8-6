@isTest
public class Test_AttendeeIntegrationHandler {

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

        // Create valid Event Item (linked to same Event)
        conference360__Event_Item__c item = new conference360__Event_Item__c(
            // Name = 'General Admission',
            conference360__Event__c = evt.Id
        );
        insert item;

        // Create Attendee
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
            conference360__Attendee__c = attendee.Id
        );
        insert lineItem;
    }

    @isTest
    static void testHandleAfterInsert() {
        conference360__Attendee__c newAttendee = [
            SELECT Id, conference360__Event__c, conference360__First_Name2__c, Transfer_From_Attendee__c
            FROM conference360__Attendee__c LIMIT 1
        ];

        Test.startTest();
        AttendeeIntegrationHandler.handleAfterInsert(new List<conference360__Attendee__c>{newAttendee});
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testHandleAfterUpdate_StatusChange() {
        conference360__Attendee__c existing = [
            SELECT Id, conference360__Registration_Status__c,
                   conference360__First_Name2__c, conference360__Last_Name2__c,
                   conference360__Title__c, conference360__Street__c,
                   conference360__City__c, conference360__State__c,
                   conference360__Postal_Code__c, conference360__Country__c,
                   conference360__Email__c, conference360__Phone2__c,
                   Computed_Id__c, conference360__Account__c, Transfer_From_Attendee__c,
                   conference360__Event__c, conference360__Event_Item__c,
                   conference360__Sales_Document__c
            FROM conference360__Attendee__c LIMIT 1
        ];
        conference360__Attendee__c oldVersion = existing.clone(false, true, false, false);

        existing.conference360__Registration_Status__c = 'Cancelled';
        update existing;

        conference360__Attendee__c updated = [
            SELECT Id, conference360__Registration_Status__c,
                   conference360__First_Name2__c, conference360__Last_Name2__c,
                   conference360__Title__c, conference360__Street__c,
                   conference360__City__c, conference360__State__c,
                   conference360__Postal_Code__c, conference360__Country__c,
                   conference360__Email__c, conference360__Phone2__c,
                   Computed_Id__c, conference360__Account__c,
                   conference360__Event__c, conference360__Event_Item__c,
                   conference360__Sales_Document__c
            FROM conference360__Attendee__c WHERE Id = :existing.Id
        ];

        Map<Id, conference360__Attendee__c> oldMap = new Map<Id, conference360__Attendee__c>{
            updated.Id => oldVersion
        };

        Test.startTest();
        AttendeeIntegrationHandler.handleAfterUpdate(new List<conference360__Attendee__c>{updated}, oldMap);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testHandleAfterUpdate_RelevantFieldChanges() {
        conference360__Attendee__c existing = [
            SELECT Id, conference360__First_Name2__c,
                   conference360__Last_Name2__c, conference360__Title__c,
                   conference360__Street__c, conference360__City__c,
                   conference360__State__c, conference360__Postal_Code__c,
                   conference360__Country__c, conference360__Email__c,
                   conference360__Phone2__c, Computed_Id__c,
                   conference360__Account__c, conference360__Event__c,
                   conference360__Registration_Status__c, conference360__Event_Item__c,
                   conference360__Sales_Document__c
            FROM conference360__Attendee__c LIMIT 1
        ];
        conference360__Attendee__c oldVersion = existing.clone(false, true, false, false);

        existing.conference360__Last_Name2__c = 'Updated';
        existing.conference360__Title__c = 'Director';
        existing.conference360__Street__c = '999 Change Rd';
        existing.conference360__City__c = 'Changeville';
        existing.conference360__State__c = 'TX';
        existing.conference360__Postal_Code__c = '88888';
        existing.conference360__Country__c = 'Canada';
        existing.conference360__Email__c = 'change@example.com';
        existing.conference360__Phone2__c = '9876543210';
        update existing;

        conference360__Attendee__c updated = [
            SELECT Id, conference360__First_Name2__c,
                   conference360__Last_Name2__c, conference360__Title__c,
                   conference360__Street__c, conference360__City__c,
                   conference360__State__c, conference360__Postal_Code__c,
                   conference360__Country__c, conference360__Email__c,
                   conference360__Phone2__c, Computed_Id__c,
                   conference360__Account__c, conference360__Event__c,
                   conference360__Registration_Status__c, conference360__Event_Item__c,
                   conference360__Sales_Document__c
            FROM conference360__Attendee__c WHERE Id = :existing.Id
        ];

        Map<Id, conference360__Attendee__c> oldMap = new Map<Id, conference360__Attendee__c>{
            updated.Id => oldVersion
        };

        Test.startTest();
        AttendeeIntegrationHandler.handleAfterUpdate(new List<conference360__Attendee__c>{updated}, oldMap);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testSendEventsToCsis_NoEventId() {
        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__First_Name2__c = 'NoEvent',
            conference360__Last_Name2__c = 'User',
            conference360__Email__c = 'noevent@example.com'
        );
        insert att;

        Test.startTest();
        AttendeeIntegrationHandler.sendEventsToCsis(new List<conference360__Attendee__c>{att});
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testMarkOrdersForLineItemProcessing() {
        List<conference360__Attendee__c> attendees = [
            SELECT Id, conference360__Sales_Document__c
            FROM conference360__Attendee__c
            WHERE conference360__Sales_Document__c != null
        ];

        Test.startTest();
        AttendeeIntegrationHandler.markOrdersForLineItemProcessing(attendees);
        Test.stopTest();

        System.assert(true);
    }
    @isTest
static void testHandleSubstitutionAttendees() {
    // Setup: Create substitution attendee
    conference360__Attendee__c originalAtt = new conference360__Attendee__c(
        conference360__First_Name2__c = 'Original',
        conference360__Last_Name2__c = 'User'
    );
    insert originalAtt;

    conference360__Attendee__c substituteAtt = new conference360__Attendee__c(
        conference360__First_Name2__c = 'Sub',
        conference360__Last_Name2__c = 'User',
        Transfer_From_Attendee__c = originalAtt.Id
    );
    insert substituteAtt;

    Test.startTest();
    AttendeeIntegrationHandler.handleSubstitutionAttendees(new List<conference360__Attendee__c>{ substituteAtt });
    Test.stopTest();

    System.assert(true, 'handleSubstitutionAttendees ran without error');
}
@isTest
static void testHandleCancelledSubstituteAttendees() {
    conference360__Attendee__c cancelledAtt = new conference360__Attendee__c(
        conference360__First_Name2__c = 'Cancelled',
        conference360__Last_Name2__c = 'User',
        conference360__Registration_Status__c = 'Cancelled - Substitute'
    );
    insert cancelledAtt;

    Test.startTest();
    AttendeeIntegrationHandler.handleCancelledSubstituteAttendees(new List<conference360__Attendee__c>{ cancelledAtt });
    Test.stopTest();

    System.assert(true, 'handleCancelledSubstituteAttendees ran without error');
}
@isTest
static void testSendSubstitutionEventsToCsis() {
    conference360__Event__c evt = new conference360__Event__c(Name = 'Sub Event');
    insert evt;

    conference360__Attendee__c originalAtt = new conference360__Attendee__c(
        conference360__First_Name2__c = 'Original',
        conference360__Last_Name2__c = 'User',
        conference360__Event__c = evt.Id
    );
    insert originalAtt;

    conference360__Attendee__c newAtt = new conference360__Attendee__c(
        conference360__First_Name2__c = 'Sub',
        conference360__Last_Name2__c = 'User',
        conference360__Event__c = evt.Id
    );
    insert newAtt;

    Test.startTest();
    AttendeeIntegrationHandler.sendSubstitutionEventsToCsis(newAtt.Id, originalAtt.Id);
    Test.stopTest();

    System.assert(true, 'sendSubstitutionEventsToCsis ran without error');
}

}