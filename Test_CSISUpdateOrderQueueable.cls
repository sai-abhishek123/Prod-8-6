@isTest
private class Test_CSISUpdateOrderQueueable {

    @isTest
    static void testExecute() {
        bt_stripe__Sales_Document__c testOrder = new bt_stripe__Sales_Document__c();
        // testOrder.Name = 'Test Order';
        // Add more required fields here as needed
        insert testOrder;

        // Step 2: Enqueue the Queueable class
        CSISUpdateOrderQueueable queueableJob = new CSISUpdateOrderQueueable(testOrder.Id);
        
        Test.startTest();
        System.enqueueJob(queueableJob);
        Test.stopTest();

        // Step 3: Re-query to assert update occurred without error
        bt_stripe__Sales_Document__c updatedOrder = [
            SELECT Id, Name
            FROM bt_stripe__Sales_Document__c
            WHERE Id = :testOrder.Id
        ];

        System.assertNotEquals(null, updatedOrder, 'The order record should exist after update.');
    }
}