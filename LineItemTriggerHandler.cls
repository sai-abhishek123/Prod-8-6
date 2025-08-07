public class LineItemTriggerHandler {
    private static Boolean isExecuting = false;
    
    public static void handleAfterChange(Set<Id> salesDocIds) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            CSISIntegrationManager.setSkipParentTrigger(true);
            CSISIntegrationManager.setLineItemProcessing(true);
            
            if (!salesDocIds.isEmpty()) {
                processOrdersForIntegration(salesDocIds);
            }
        } finally {
            isExecuting = false;
        }
    }
    
    public static void processOrdersForIntegration(Set<Id> salesDocIds) {
        List<bt_stripe__Sales_Document__c> orders = [
            SELECT Id, externalId__c
            FROM bt_stripe__Sales_Document__c
            WHERE Id IN :salesDocIds
            AND conference360__Event__c != null
            AND externalId__c != null
        ];
        
        List<bt_stripe__Sales_Document__c> docsToUpdate = new List<bt_stripe__Sales_Document__c>();
        List<String> orderExternalIds = new List<String>();
        
        for (bt_stripe__Sales_Document__c order : orders) {
            docsToUpdate.add(new bt_stripe__Sales_Document__c(
                Id = order.Id
            ));
            
            if (String.isNotBlank(order.externalId__c)) {
                orderExternalIds.add(order.externalId__c);
            }
        }
        
        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
            
            if (!orderExternalIds.isEmpty() && !Test.isRunningTest()) {
                Map<String, Object> params = new Map<String, Object>{
                'orderExternalIds' => orderExternalIds
            };
            CSISScheduledQueueable.scheduleQueueableJob('CSISOrderQueueable', params, 3);
            } else if (Test.isRunningTest()) {
                CSISIntegrationManager.setLineItemProcessing(false);
            }
        } else {
            CSISIntegrationManager.setLineItemProcessing(false);
        }
    }
}