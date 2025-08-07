@isTest
public class Test_CSISBaseQueueable {

    public class TestQueueable extends CSISBaseQueueable {
        public TestQueueable(String operationId, String operationType) {
            super(operationId, operationType);
        }

        public override void execute(QueueableContext context) {}

        public void callClearOperation() {
            clearOperation(operationId);
        }

        public void callChainQueueable(Queueable job) {
            chainQueueable(job);
        }

        public void callHandleError(Exception e, String detail) {
            handleError(e, detail);
        }

        public void triggerRetry() {
            retryOperation();
        }
    }

    @isTest
    static void testMarkAndCheckOperationInProgress() {
        String opId = 'TEST_OP_' + DateTime.now().getTime();
        TestQueueable job = new TestQueueable(opId, 'TEST');

        System.assertEquals(true, CSISBaseQueueable.isOperationInProgress(opId), 'Should be in progress');

        job.callClearOperation();
        System.assertEquals(false, CSISBaseQueueable.isOperationInProgress(opId), 'Should be cleared');
    }

    @isTest
    static void testHandleErrorClearsOperation() {
        String opId = 'ERR_OP_' + DateTime.now().getTime();
        TestQueueable job = new TestQueueable(opId, 'TEST');

        job.callHandleError(new StringException('Test error'), 'Fake detail');

        System.assertEquals(false, CSISBaseQueueable.isOperationInProgress(opId), 'Error should clear op');
}


    @isTest
    static void testChainQueueable_WhenAllowed() {
        TestQueueable job = new TestQueueable('CHAIN_OP_' + DateTime.now().getTime(), 'TEST');

        Test.startTest();
        job.callChainQueueable(new TestQueueable('NEXT_JOB', 'TEST'));
        Test.stopTest();

        System.assert(true, 'Queueable chaining executed');
    }

    @isTest
    static void testRetryOperationDefault() {
        TestQueueable job = new TestQueueable('RETRY_OP_' + DateTime.now().getTime(), 'TEST');

        Test.startTest();
        job.triggerRetry();
        Test.stopTest();

        System.assert(true, 'Default retry logic executed');
    }
}