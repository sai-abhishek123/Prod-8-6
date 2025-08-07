public class OrderTriggerHandler {
    public static Set<Id> processedOrderIds = new Set<Id>();
    
    public static void handleAfterUpdate(List<bt_stripe__Sales_Document__c> newOrders, Map<Id, bt_stripe__Sales_Document__c> oldMap) {
        if (CSISIntegrationManager.shouldSkipParentTrigger() || CSISIntegrationManager.isLineItemProcessing()) {
            CSISIntegrationManager.setSkipParentTrigger(false);
            return;
        }

        if (CSISIntegrationManager.isLineItemProcessing()) return;
        
        List<bt_stripe__Sales_Document__c> ordersToSync = new List<bt_stripe__Sales_Document__c>();
        
        for (bt_stripe__Sales_Document__c newOrder : newOrders) {
            if (processedOrderIds.contains(newOrder.Id)) {
                continue;
            }
            
            bt_stripe__Sales_Document__c oldOrder = oldMap.get(newOrder.Id);
            
            if (hasRelevantChanges(newOrder, oldOrder)) {
                ordersToSync.add(newOrder);
                processedOrderIds.add(newOrder.Id);
                SalesDocumentTriggerHandler.processedDocIds.add(newOrder.Id);
            }
        }
        
        if (!ordersToSync.isEmpty() && !CSISIntegrationManager.isLineItemProcessing()) {
            sendOrdersToCsis(ordersToSync);
        }
    }
    
    private static Boolean hasRelevantChanges(bt_stripe__Sales_Document__c newOrder, 
                                             bt_stripe__Sales_Document__c oldOrder) {
        return newOrder.bt_stripe__Total_Amount__c != oldOrder.bt_stripe__Total_Amount__c ||
               newOrder.bt_stripe__Balance_Paid_Amount__c != oldOrder.bt_stripe__Balance_Paid_Amount__c ||
               newOrder.bt_stripe__Payment_Status__c != oldOrder.bt_stripe__Payment_Status__c ||
               newOrder.bt_stripe__Bill_To__c != oldOrder.bt_stripe__Bill_To__c ||
               newOrder.conference360__Event__c != oldOrder.conference360__Event__c ||
               false;
    }
    
    private static void sendOrdersToCsis(List<bt_stripe__Sales_Document__c> orders) {
        List<Id> orderIdsWithLineItems = new List<Id>();
        
        Set<Id> orderIds = new Set<Id>();
        for (bt_stripe__Sales_Document__c order : orders) {
            orderIds.add(order.Id);
        }
        
        Map<Id, Integer> orderLineItemCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT bt_stripe__Sales_Document__c, COUNT(Id) itemCount
            FROM bt_stripe__Line_Item__c
            WHERE bt_stripe__Sales_Document__c IN :orderIds
            GROUP BY bt_stripe__Sales_Document__c
        ]) {
            Id orderId = (Id)ar.get('bt_stripe__Sales_Document__c');
            Integer count = (Integer)ar.get('itemCount');
            if (count > 0) {
                orderIdsWithLineItems.add(orderId);
            }
        }
        
        List<String> orderExternalIds = new List<String>();
        
        for (bt_stripe__Sales_Document__c order : [
            SELECT Id, externalId__c, conference360__Event__c
            FROM bt_stripe__Sales_Document__c
            WHERE Id IN :orderIdsWithLineItems
            AND externalId__c != null
            AND conference360__Event__c != null
        ]) {
            orderExternalIds.add(order.externalId__c);
        }
        
        if (!orderExternalIds.isEmpty() && !CSISIntegrationManager.isLineItemProcessing()) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new CSISOrderQueueable(orderExternalIds));
            } else {
                for (String orderExternalId : orderExternalIds) {
                    CSISIntegrationManager.processOrder(orderExternalId, false);
                }
            }
        }
    } 
}