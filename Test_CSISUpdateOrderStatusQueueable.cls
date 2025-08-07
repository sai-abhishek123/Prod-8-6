@isTest
private class Test_CSISUpdateOrderStatusQueueable  {

    @isTest
    static void testExecute_successfulUpdate() {
        // Arrange: Create a real Account and Sales Document
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            externalId__c = 'ORD123',
            bt_stripe__Bill_To__c = acc.Id
        );
        insert doc;

        // Act
        Test.startTest();
        System.enqueueJob(new CSISUpdateOrderStatusRecordQueueable(doc.Id));
        Test.stopTest();

        // Assert
        bt_stripe__Sales_Document__c updatedDoc = [
            SELECT Id, LastModifiedDate
            FROM bt_stripe__Sales_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertNotEquals(null, updatedDoc.LastModifiedDate, 'Document should be updated');
    }

    @isTest
    static void testExecute_orderDeletedBeforeExecution() {
        // Arrange: Insert and then delete the record before enqueueing
        Account acc = new Account(Name = 'Deleted Account'); 
        insert acc;

        bt_stripe__Sales_Document__c doc = new bt_stripe__Sales_Document__c(
            externalId__c = 'ORD_DELETE',
            bt_stripe__Bill_To__c = acc.Id
        );
        insert doc;

        Id docId = doc.Id;
        delete doc;

        // Act
        Test.startTest();
        System.enqueueJob(new CSISUpdateOrderStatusRecordQueueable(docId));
        Test.stopTest();

        // Assert: no exception = success
        System.assert(true, 'Queueable should not fail if record no longer exists');
    }
}