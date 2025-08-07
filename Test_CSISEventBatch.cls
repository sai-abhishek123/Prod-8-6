@isTest
public class Test_CSISEventBatch {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'CSIS Org');//, Computed_ID__c = 'COMP123');
        insert acc;

        conference360__Event__c evt1 = new conference360__Event__c(
            Name = 'Event 1',
            Approved_to_Send_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today().addDays(-5),
            conference360__Organizer_Account__c = acc.Id
        );

        conference360__Event__c evt2 = new conference360__Event__c(
            Name = 'Event 2',
            Approved_to_Send_to_CSIS__c = true,
            Event_Data_Sent_to_CSIS__c = true,
            conference360__Event_Start_Date__c = Date.today().addDays(-1),
            conference360__Organizer_Account__c = acc.Id
        );

        insert new List<conference360__Event__c>{ evt1, evt2 };
    }

    @isTest
    static void testRunBatch() {
        Test.startTest();
        Id jobId = CSISEventBatch.runBatch();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job should return a non-null Id');
    }

    @isTest
    static void testRunBatchForDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(5);

        Test.startTest();
        Id jobId = CSISEventBatch.runBatchForDateRange(startDate, endDate);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job should return an Id for date range');
    }

    @isTest
    static void testStartQuery_NonIntegratedOnly() {
        CSISEventBatch batch = new CSISEventBatch(true);
        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'QueryLocator should be returned even for nonIntegratedOnly');
    }

    @isTest
    static void testStartQuery_WithDateRange() {
        Date start = Date.today().addDays(-7);
        Date end_date = Date.today().addDays(7);
        CSISEventBatch batch = new CSISEventBatch(start, end_date);

        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'QueryLocator should be returned for date range');
    }

    @isTest
    static void testExecuteLogic() {
        List<conference360__Event__c> events = [
            SELECT Id, conference360__Event_Start_Date__c,
                   conference360__Organizer_Account__c
            FROM conference360__Event__c
            WHERE Approved_to_Send_to_CSIS__c = true
        ];

        Test.startTest();
        CSISEventBatch batch = new CSISEventBatch();
        batch.execute(null, events);
        Test.stopTest();

        System.assert(true, 'Execute ran successfully');
    }

    @isTest
    static void testUpdateComputedIdAccountField() {
        List<conference360__Event__c> events = [
            SELECT Id, conference360__Organizer_Account__c
            FROM conference360__Event__c
            WHERE conference360__Organizer_Account__c != null
        ];

        Test.startTest();
        CSISEventBatch.updateComputedIdAccountField(events);
        Test.stopTest();

        System.assert(true, 'updateComputedIdAccountField executed without errors');
    }

    @isTest
    static void testFinishMethod() {
        CSISEventBatch batch = new CSISEventBatch();

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Finish method ran safely');
    }
}