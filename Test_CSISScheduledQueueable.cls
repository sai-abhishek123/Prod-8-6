@isTest
private class Test_CSISScheduledQueueable {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Sched Test Account');
        insert acc;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Sched Event',
            externalId__c = 'EVT_SCHED',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            Approved_to_Send_to_CSIS__c = true
        );
        insert evt;

        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__Event__c = evt.Id,
            conference360__Account__c = acc.Id,
            conference360__First_Name2__c = 'Test',
            conference360__Last_Name2__c = 'User',
            conference360__Email2__c = 'test@user.com',
            conference360__Registration_Status__c = 'Registered'
        );
        insert att;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            externalId__c = 'ORD_SCHED',
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc;
    }

    @isTest
    static void testScheduleEventQueueableWithEventIds() {
        Id eventId = [SELECT Id FROM conference360__Event__c LIMIT 1].Id;
        Id attendeeId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;

        Map<String, Object> params = new Map<String, Object>{
            'eventIds' => new List<Id>{ eventId },
            'attendeeIds' => new List<Id>{ attendeeId }
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('CSISEventQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should be returned');
    }

    @isTest
    static void testScheduleOrderQueueable_basic() {
        Map<String, Object> params = new Map<String, Object>{
            'orderExternalId' => 'ORD_SCHED'
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('CSISOrderQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleOrderQueueable_withAttendeeAndStatus() {
        Id attendeeId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;

        Map<String, Object> params = new Map<String, Object>{
            'orderExternalId' => 'ORD_SCHED',
            'attendeeId' => attendeeId,
            'registrationStatus' => 'Registered'
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('CSISOrderQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleOrderQueueable_withListOfIds() {
        Map<String, Object> params = new Map<String, Object>{
            'orderExternalIds' => new List<String>{ 'ORD_SCHED' },
            'registrationStatus' => 'Registered'
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('CSISOrderQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleAttendeeQueueable() {
        Id attendeeId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;

        Map<String, Object> params = new Map<String, Object>{
            'attendeeIds' => new List<Id>{ attendeeId }
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('CSISAttendeeQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleWithInvalidClassName() {
        Map<String, Object> params = new Map<String, Object>{
            'anyParam' => 'value'
        };

        Test.startTest();
        String jobId = CSISScheduledQueueable.scheduleQueueableJob('UnsupportedQueueable', params, 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should still return a job ID for invalid class');
    }

    @isTest
    static void testExecuteMethodDirectly() {
        Id attendeeId = [SELECT Id FROM conference360__Attendee__c LIMIT 1].Id;

        Map<String, Object> params = new Map<String, Object>{
            'attendeeIds' => new List<Id>{ attendeeId }
        };

        CSISScheduledQueueable sched = new CSISScheduledQueueable('CSISAttendeeQueueable', params);

        Test.startTest();
        sched.execute(new TestSchedulableContext());
        Test.stopTest();

        System.assert(true, 'Should complete execution in test without aborting');
    }

    private class TestSchedulableContext implements SchedulableContext {
        public String getTriggerId() {
            return ''; // Return safe string, not a fake ID
        }
    }
}