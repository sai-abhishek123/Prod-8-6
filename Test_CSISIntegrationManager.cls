@isTest
public class Test_CSISIntegrationManager {

    @isTest static void test_flagSettersAndGetters() {
        // Initial values
        System.assertEquals(false, CSISIntegrationManager.isLineItemProcessing());
        System.assertEquals(false, CSISIntegrationManager.shouldSkipParentTrigger());
        System.assertEquals(false, CSISIntegrationManager.shouldSkipAttendeeTrigger());
        System.assertEquals(null, CSISIntegrationManager.getRegistrationStatus());

        // Set values
        CSISIntegrationManager.setLineItemProcessing(true);
        CSISIntegrationManager.setSkipParentTrigger(true);
        CSISIntegrationManager.setSkipAttendeeTrigger(true);
        CSISIntegrationManager.setRegistrationStatus('Registered');

        // Assert values
        System.assertEquals(true, CSISIntegrationManager.isLineItemProcessing());
        System.assertEquals(true, CSISIntegrationManager.shouldSkipParentTrigger());
        System.assertEquals(true, CSISIntegrationManager.shouldSkipAttendeeTrigger());
        System.assertEquals('Registered', CSISIntegrationManager.getRegistrationStatus());
    }

    @isTest static void test_resetState() {
        // Set some state first
        CSISIntegrationManager.setLineItemProcessing(true);
        CSISIntegrationManager.setSkipParentTrigger(true);
        CSISIntegrationManager.setSkipAttendeeTrigger(true);
        CSISIntegrationManager.markRecordProcessed('EXT-123');

        // Reset
        CSISIntegrationManager.resetState();

        // Check that everything reset
        System.assertEquals(false, CSISIntegrationManager.isLineItemProcessing());
        System.assertEquals(false, CSISIntegrationManager.shouldSkipParentTrigger());
        System.assertEquals(false, CSISIntegrationManager.shouldSkipAttendeeTrigger());
        System.assertEquals(false, CSISIntegrationManager.isRecordProcessed('EXT-123'));
    }

    @isTest static void test_recordProcessingFlags() {
        String extId = 'ORD-001';

        // Should not be processed initially
        System.assertEquals(false, CSISIntegrationManager.isRecordProcessed(extId));

        // Mark as processed
        CSISIntegrationManager.markRecordProcessed(extId);
        System.assertEquals(true, CSISIntegrationManager.isRecordProcessed(extId));

        // Set line item flag to true - forces isRecordProcessed to return true regardless
        CSISIntegrationManager.setLineItemProcessing(true);
        System.assertEquals(true, CSISIntegrationManager.isRecordProcessed('any-id'));
    }

    @isTest static void test_processOrder_withInvalidInput() {
        // Null input
        Boolean result = CSISIntegrationManager.processOrder(null, true);
        System.assertEquals(false, result);

        // Blank input
        result = CSISIntegrationManager.processOrder('', true);
        System.assertEquals(false, result);

        // Already processed
        String extId = 'ORD-002';
        CSISIntegrationManager.markRecordProcessed(extId);
        result = CSISIntegrationManager.processOrder(extId, true);
        System.assertEquals(false, result);

        // Not from line item
        result = CSISIntegrationManager.processOrder('ORD-003', false);
        System.assertEquals(false, result);
    }

    @isTest static void test_processOrder_enqueueSuccess() {
        // Simulate false from isIdInProgress using a stub wrapper (you could use a mock framework in real orgs)
        Test.startTest();

        // Use a new externalId
        String extId = 'ORD-004';
        Boolean result = CSISIntegrationManager.processOrder(extId, true);

        Test.stopTest();

        // Should be true (enqueued successfully)
        System.assertEquals(true, result);
    }
}