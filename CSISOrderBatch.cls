public class CSISOrderBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private Boolean nonIntegratedOnly = false;
    
    public CSISOrderBatch() {
        this(false);
    }
    
    public CSISOrderBatch(Boolean nonIntegratedOnly) {
        this.nonIntegratedOnly = nonIntegratedOnly;
    }
    
    public static Id runBatch() {
        return Database.executeBatch(new CSISOrderBatch(), 100);
    }
    
    public static Id runBatchForNonIntegrated() {
        return Database.executeBatch(new CSISOrderBatch(true), 100);
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, externalId__c ' +
                      'FROM bt_stripe__Sales_Document__c ' +
                      'WHERE conference360__Event__c != null AND externalId__c != null';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<String> externalIds = new List<String>();
        
        for (SObject so : scope) {
            bt_stripe__Sales_Document__c doc = (bt_stripe__Sales_Document__c)so;
            if (String.isNotBlank(doc.externalId__c)) {
                externalIds.add(doc.externalId__c);
            }
        }
        
        if (!externalIds.isEmpty()) {
            if (!System.isFuture() && !System.isQueueable()) {
                System.enqueueJob(new CSISOrderQueueable(externalIds));
            } else {
                for (String externalId : externalIds) {
                    CSISIntegration.sendOrderToCsis(externalId);
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext BC) {
    }
}