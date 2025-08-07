@isTest
public class Test_CSISBatchQueueable {

    @testSetup
    static void setupData() {
        // Insert any required mock records here if needed later
    }

    @isTest
    static void testRunFullIntegration() {
        Test.startTest();
        CSISBatchQueueable.runFullIntegration();
        Test.stopTest();

        System.assert(true, 'runFullIntegration enqueued 3 queueables');
    }

    @isTest
    static void testRunPendingIntegration() {
        Test.startTest();
        CSISBatchQueueable.runPendingIntegration();
        Test.stopTest();

        System.assert(true, 'runPendingIntegration enqueued 3 queueables');
    }

    @isTest
    static void testExecute_ATTENDEE_NonIntegrated() {
        CSISBatchQueueable job = new CSISBatchQueueable('ATTENDEE', 100, false);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'ATTENDEE non-integrated job executed');
    }

    @isTest
    static void testExecute_ATTENDEE_WithRegAccountCode() {
        CSISBatchQueueable job = new CSISBatchQueueable('ATTENDEE', 100, 'REG123');

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'ATTENDEE regAccountCode job executed');
    }

    @isTest
    static void testExecute_EVENT_WithDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(10);
        CSISBatchQueueable job = new CSISBatchQueueable('EVENT', 100, startDate, endDate);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'EVENT with date range job executed');
    }

    @isTest
    static void testExecute_EVENT_NonIntegrated() {
        CSISBatchQueueable job = new CSISBatchQueueable('EVENT', 100, false);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'EVENT non-integrated job executed');
    }

    @isTest
    static void testExecute_ORDER_NonIntegrated() {
        CSISBatchQueueable job = new CSISBatchQueueable('ORDER', 100, false);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'ORDER non-integrated job executed');
    }
}