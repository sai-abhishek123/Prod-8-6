@isTest
private class Test_EventTrigger {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Trigger Test Org');
        insert acc;
    }

    @isTest
    static void testTrigger_AfterInsert_ApprovedEvent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Trigger Approved Event',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(2),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'TRIG-EVT-001'
        );

        Test.startTest();
        insert evt;
        Test.stopTest();

        conference360__Event__c inserted = [SELECT Id, Approved_to_Send_to_CSIS__c FROM conference360__Event__c WHERE Id = :evt.Id];
        System.assertEquals(true, inserted.Approved_to_Send_to_CSIS__c, 'Inserted event should be approved');
    }

    @isTest
    static void testTrigger_AfterInsert_UnapprovedEvent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Trigger Unapproved Event',
            Approved_to_Send_to_CSIS__c = false,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(2),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'TRIG-EVT-002'
        );

        Test.startTest();
        insert evt;
        Test.stopTest();

        conference360__Event__c inserted = [SELECT Id, Approved_to_Send_to_CSIS__c FROM conference360__Event__c WHERE Id = :evt.Id];
        System.assertEquals(false, inserted.Approved_to_Send_to_CSIS__c, 'Inserted event should be unapproved');
    }

    @isTest
    static void testTrigger_AfterUpdate_ApprovedChangedFromFalseToTrue() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Initially Unapproved',
            Approved_to_Send_to_CSIS__c = false,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'TRIG-EVT-003'
        );
        insert evt;

        evt.Approved_to_Send_to_CSIS__c = true;

        Test.startTest();
        update evt;
        Test.stopTest();

        conference360__Event__c updated = [SELECT Id, Approved_to_Send_to_CSIS__c FROM conference360__Event__c WHERE Id = :evt.Id];
        System.assertEquals(true, updated.Approved_to_Send_to_CSIS__c, 'Approval flag should be updated to true');
    }

    @isTest
    static void testTrigger_AfterUpdate_NoApprovalChange() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Always Approved Event',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            externalId__c = 'TRIG-EVT-004'
        );
        insert evt;

        evt.Name = 'Updated Event Name';

        Test.startTest();
        update evt;
        Test.stopTest();

        conference360__Event__c updated = [SELECT Id, Name FROM conference360__Event__c WHERE Id = :evt.Id];
        System.assertEquals('Updated Event Name', updated.Name, 'Event name should have been updated');
    }
}