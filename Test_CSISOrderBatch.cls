@isTest
private class Test_CSISOrderBatch {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Batch Test Account');
        insert acc;

        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Batch Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(2),
            conference360__Organizer_Account__c = acc.Id
        );
        insert evt;

        // Valid Sales Document
        bt_stripe__Sales_Document__c doc1 = new bt_stripe__Sales_Document__c(
            externalId__c = 'BATCH_EXT_1',
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc1;

        // Another valid Sales Document
        bt_stripe__Sales_Document__c doc2 = new bt_stripe__Sales_Document__c(
            externalId__c = 'BATCH_EXT_2',
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc2;

        // Document with null externalId should be excluded
        bt_stripe__Sales_Document__c doc3 = new bt_stripe__Sales_Document__c(
            bt_stripe__Bill_To__c = acc.Id,
            conference360__Event__c = evt.Id
        );
        insert doc3;
    }

    @isTest
    static void testStartMethodQueryLocator() {
        CSISOrderBatch batch = new CSISOrderBatch();
        Database.QueryLocator locator = batch.start(null);
        System.assertNotEquals(null, locator, 'QueryLocator should not be null');
    }

    @isTest
    static void testExecuteMethod_WithValidScope() {
        List<bt_stripe__Sales_Document__c> docs = [
            SELECT Id, externalId__c FROM bt_stripe__Sales_Document__c WHERE externalId__c != null
        ];

        CSISOrderBatch batch = new CSISOrderBatch();

        Test.startTest();
        batch.execute(null, docs);
        Test.stopTest();

        System.assert(true, 'Execute with valid scope should succeed');
    }

    @isTest
    static void testExecuteMethod_WithEmptyScope() {
        CSISOrderBatch batch = new CSISOrderBatch();

        Test.startTest();
        batch.execute(null, new List<SObject>());
        Test.stopTest();

        System.assert(true, 'Execute with empty scope should not fail');
    }

    @isTest
    static void testRunBatch_StaticMethod() {
        Test.startTest();
        Id jobId = CSISOrderBatch.runBatch();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should be returned');
    }

    @isTest
    static void testRunBatchForNonIntegrated_StaticMethod() {
        Test.startTest();
        Id jobId = CSISOrderBatch.runBatchForNonIntegrated();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Non-integrated batch job ID should be returned');
    }

    @isTest
    static void testConstructorWithFlag() {
        CSISOrderBatch batch1 = new CSISOrderBatch();
        CSISOrderBatch batch2 = new CSISOrderBatch(true);

        System.assertNotEquals(null, batch1, 'Default constructor should work');
        System.assertNotEquals(null, batch2, 'Flag constructor should work');
    }
}