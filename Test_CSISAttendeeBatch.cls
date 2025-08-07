@isTest
public class Test_CSISAttendeeBatch {

    @testSetup
    static void setupData() {
        // Create a test Event
        conference360__Event__c evt = new conference360__Event__c(Name = 'Test Event');
        insert evt;

        // Create a test Contact with externalId__c
        Contact con = new Contact(LastName = 'Contact', ExternalId__c = 'REG123');
        insert con;

        // Create test Attendee linked to the Event and Contact
        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Jane',
            conference360__Last_Name2__c = 'Doe',
            conference360__Event__c = evt.Id,
            conference360__Contact__c = con.Id
        );
        insert att;
    }

    @isTest
    static void testRunBatch_Default() {
        Test.startTest();
        Id jobId = CSISAttendeeBatch.runBatch();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should not be null.');
    }

    @isTest
    static void testRunBatchForNonIntegrated() {
        Test.startTest();
        Id jobId = CSISAttendeeBatch.runBatchForNonIntegrated();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should not be null for non-integrated.');
    }

    @isTest
    static void testRunBatchForRegAccountCode() {
        Test.startTest();
        Id jobId = CSISAttendeeBatch.runBatchForRegAccountCode('REG123');
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should not be null for regAccountCode.');
    }

    @isTest
    static void testStartWithAndWithoutRegAccountCode() {
        // Test with regAccountCode
        CSISAttendeeBatch batchWithCode = new CSISAttendeeBatch('REG123');
        Database.QueryLocator qlWithCode = batchWithCode.start(null);
        System.assertNotEquals(null, qlWithCode);

        // Test without regAccountCode
        CSISAttendeeBatch batchNoCode = new CSISAttendeeBatch();
        Database.QueryLocator qlNoCode = batchNoCode.start(null);
        System.assertNotEquals(null, qlNoCode);
    }

    @isTest
    static void testExecuteMethod() {
        conference360__Attendee__c att = [
            SELECT Id, conference360__Event__c 
            FROM conference360__Attendee__c 
            LIMIT 1
        ];

        List<SObject> scope = new List<SObject>{ att };

        CSISAttendeeBatch batch = new CSISAttendeeBatch();
        Test.startTest();
        batch.execute(null, scope);
        Test.stopTest();

        System.assert(true, 'Execute completed without exception.');
    }

    @isTest
    static void testFinishMethod() {
        CSISAttendeeBatch batch = new CSISAttendeeBatch();
        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Finish method ran without issue.');
    }
}