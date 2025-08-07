public abstract class CSISBaseQueueable implements Queueable, Database.AllowsCallouts {
    private static Map<String, DateTime> operationsInProgress = new Map<String, DateTime>();
    protected String operationId;
    protected String operationType;
    protected Integer retryCount = 0;
    protected Integer maxRetries = 3;
    
    public CSISBaseQueueable(String operationId, String operationType) {
        this.operationId = operationId;
        this.operationType = operationType;
        markOperationInProgress(operationId);
    }
    
    public static Boolean isOperationInProgress(String operationId) {
        DateTime cutoff = DateTime.now().addMinutes(-30);
        List<String> staleIds = new List<String>();
        
        for (String id : operationsInProgress.keySet()) {
            if (operationsInProgress.get(id) < cutoff) {
                staleIds.add(id);
            }
        }
        
        for (String id : staleIds) {
            operationsInProgress.remove(id);
        }
        
        return operationsInProgress.containsKey(operationId);
    }
    
    protected void markOperationInProgress(String operationId) {
        operationsInProgress.put(operationId, DateTime.now());
    }
    
    protected void clearOperation(String operationId) {
        operationsInProgress.remove(operationId);
    }
    
    public abstract void execute(QueueableContext context);
    
    protected void handleError(Exception ex, String detail) {
        System.debug(LoggingLevel.ERROR, 'CSIS Integration Error (' + operationType + '): ' + ex.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + ex.getStackTraceString());
        System.debug(LoggingLevel.ERROR, 'Operation details: ' + detail);
        
        clearOperation(operationId);
    }
    
    protected virtual void retryOperation() {
    }
    
    protected void chainQueueable(Queueable nextJob) {
        try {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(nextJob);
            } else {
                System.debug(LoggingLevel.WARN, 'Cannot chain queueable: governor limit reached');
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error chaining queueable: ' + ex.getMessage());
        }
    }
}