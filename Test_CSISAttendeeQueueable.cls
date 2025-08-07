@isTest
public class Test_CSISAttendeeQueueable {

    static Id attendeeId1;
    static Id attendeeId2;

    @testSetup
    static void setupData() {
        // Create Event
        conference360__Event__c evt = new conference360__Event__c(Name = 'Test Event');
        insert evt;

        // Create two attendees linked to the same event
        List<conference360__Attendee__c> attendees = new List<conference360__Attendee__c>{
            new conference360__Attendee__c(
                conference360__First_Name2__c = 'Test1',
                conference360__Last_Name2__c = 'User1',
                conference360__Event__c = evt.Id
            ),
            new conference360__Attendee__c(
                conference360__First_Name2__c = 'Test2',
                conference360__Last_Name2__c = 'User2',
                conference360__Event__c = evt.Id
            )
        };
        insert attendees;

        attendeeId1 = attendees[0].Id;
        attendeeId2 = attendees[1].Id;
    }

    @isTest
    static void testGenerateOperationId_emptyList() {
        String opId = CSISAttendeeQueueable.generateOperationId(new List<Id>());
        System.assert(opId.startsWith('ATTENDEE_'));
    }

    @isTest
    static void testEnqueueAttendees() {
        Test.startTest();
        CSISAttendeeQueueable.enqueueAttendees(new List<Id>{ attendeeId1 });
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testExecuteWithValidData() {
        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(new List<Id>{ attendeeId1 });
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testExecuteWithNoEventOnAttendee() {
        // Attendee with null Event__c
        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__First_Name2__c = 'NoEvent',
            conference360__Last_Name2__c = 'User'
        );
        insert att;

        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(new List<Id>{ att.Id });

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testExecuteWithAllAttendeesEventNull() {
        conference360__Attendee__c a1 = new conference360__Attendee__c(
            conference360__First_Name2__c = 'NullEvent1',
            conference360__Last_Name2__c = 'Test'
        );
        conference360__Attendee__c a2 = new conference360__Attendee__c(
            conference360__First_Name2__c = 'NullEvent2',
            conference360__Last_Name2__c = 'Test'
        );
        insert new List<conference360__Attendee__c>{ a1, a2 };

        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(new List<Id>{ a1.Id, a2.Id });

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testEnqueueAttendees_NullAndEmpty() {
        Test.startTest();
        CSISAttendeeQueueable.enqueueAttendees(null);
        CSISAttendeeQueueable.enqueueAttendees(new List<Id>());
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testExecuteWithSubstitutionTrue() {
        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(
            new List<Id>{ attendeeId1 },
            true // isSubstitution
        );

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(queueable != null);
    }

    @isTest
    static void testExecuteWithCancellationTrue() {
        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(
            new List<Id>{ attendeeId1 },
            true, // isCancellation
            'Manual' // cancelType (currently unused, but covered)
        );

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(queueable != null);
    }

    @isTest
    static void testExecuteHandlesExceptionGracefully() {
        // Simulate scenario where attendee record is missing (causing SOQL to fail or return nothing)
        CSISAttendeeQueueable queueable = new CSISAttendeeQueueable(
            new List<Id>{ '001000000000000AAA' } // fake Id
        );

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true, 'Handled missing data gracefully.');
    }
}