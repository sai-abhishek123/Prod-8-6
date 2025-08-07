@isTest
private class Test_LineItemTrigger {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Billing Account');
        insert acc;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = acc.Id,
            externalId__c = String.valueOf(DateTime.now().getTime())
        );
        insert doc;

        conference360__Attendee__c attendee = new conference360__Attendee__c(
            conference360__Event__c = null,
            conference360__Email__c = 'test@example.com',
            conference360__Registration_Status__c = 'Registered'
        );
        insert attendee;
    }

    @isTest
    static void testAfterInsert_Trigger() { 
        bt_stripe__Sales_Document__c doc = [SELECT Id FROM bt_stripe__Sales_Document__c LIMIT 1];
        conference360__Attendee__c attendee = [SELECT Id FROM conference360__Attendee__c LIMIT 1];

        bt_stripe__Line_Item__c li = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = doc.Id,
            conference360__Attendee__c = attendee.Id,
            bt_stripe__Quantity__c = 1,
            bt_stripe__List_Price__c = 100.0
        );

        Test.startTest();
        insert li;
        Test.stopTest();

        bt_stripe__Line_Item__c inserted = [SELECT Id, bt_stripe__Quantity__c FROM bt_stripe__Line_Item__c WHERE Id = :li.Id];
        System.assertEquals(1, inserted.bt_stripe__Quantity__c);
    }

    @isTest
    static void testAfterUpdate_Trigger() {
        // Create test data within this method
        bt_stripe__Sales_Document__c doc = [SELECT Id FROM bt_stripe__Sales_Document__c LIMIT 1];
        conference360__Attendee__c attendee = [SELECT Id FROM conference360__Attendee__c LIMIT 1];

        bt_stripe__Line_Item__c li = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = doc.Id,
            conference360__Attendee__c = attendee.Id,
            bt_stripe__Quantity__c = 1,
            bt_stripe__List_Price__c = 100.0
        );
        insert li;

        // Now update the record
        li.bt_stripe__Quantity__c = 2;

        Test.startTest();
        update li;
        Test.stopTest();

        bt_stripe__Line_Item__c updated = [SELECT Id, bt_stripe__Quantity__c FROM bt_stripe__Line_Item__c WHERE Id = :li.Id];
        System.assertEquals(2, updated.bt_stripe__Quantity__c, 'Quantity should be updated');
    }
}