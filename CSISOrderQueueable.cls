public class CSISOrderQueueable extends CSISBaseQueueable {
    private List<String> orderExternalIds;
    private String registrationStatus;
    private Id specificAttendeeId;
    
    @TestVisible
    private static String generateOperationId(List<String> orderExternalIds) {
        if (orderExternalIds == null || orderExternalIds.isEmpty()) {
            return 'ORDER_' + DateTime.now().getTime();
        }
        
        return 'ORDER_' + String.join(orderExternalIds, '_');
    }
    
    public CSISOrderQueueable(String orderExternalId) {
        this(new List<String>{orderExternalId}, null);
    }
     
    public CSISOrderQueueable(List<String> orderExternalIds) {
        this(orderExternalIds, null);
    }
    
    public CSISOrderQueueable(String orderExternalId, String registrationStatus) {
        this(new List<String>{orderExternalId}, registrationStatus);
    }
    
    public CSISOrderQueueable(String orderExternalId, Id attendeeId, String registrationStatus) {
        this(new List<String>{orderExternalId}, registrationStatus);
        this.specificAttendeeId = attendeeId;
        System.debug('Created CSISOrderQueueable with external ID: ' + orderExternalId + 
                     ', attendee ID: ' + attendeeId + ', and status: ' + registrationStatus);
    }
    
    public CSISOrderQueueable(List<String> orderExternalIds, String registrationStatus) {
        super(generateOperationId(orderExternalIds), 'ORDER');
        this.orderExternalIds = orderExternalIds;
        this.registrationStatus = registrationStatus;
    }
    
    public static Boolean isIdInProgress(String externalId) {
        return isOperationInProgress('ORDER_' + externalId);
    }
    
    public override void execute(QueueableContext context) {
        if (orderExternalIds == null || orderExternalIds.isEmpty()) {
            clearOperation(operationId);
            return;
        }
        
        if (String.isNotBlank(registrationStatus)) {
            CSISIntegrationModels.setRegistrationStatus(registrationStatus);
        }
        
        String currentOrderId = orderExternalIds[0];
        List<String> remainingIds = new List<String>();
        
        if (orderExternalIds.size() > 1) {
            for (Integer i = 1; i < orderExternalIds.size(); i++) {
                remainingIds.add(orderExternalIds[i]);
            }
        }
        
        try {
            System.debug('Processing order with external ID: ' + currentOrderId + ' and specific attendee ID: ' + specificAttendeeId);
                         
            Boolean success = CSISIntegration.sendOrderToCsis(currentOrderId, specificAttendeeId);
            if (!success) {
                System.debug(LoggingLevel.ERROR, 'Failed to process order: ' + currentOrderId);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error processing order: ' + currentOrderId + ' - ' + ex.getMessage());
        }
        
        if (!remainingIds.isEmpty()) {
            System.debug('Chaining queueable for ' + remainingIds.size() + ' remaining orders');
            CSISOrderQueueable nextBatch = new CSISOrderQueueable(remainingIds, registrationStatus);
            nextBatch.specificAttendeeId = this.specificAttendeeId;
            chainQueueable(nextBatch);
        }
        
        clearOperation(operationId);
        CSISIntegrationManager.setLineItemProcessing(false);
        CSISIntegrationManager.setSkipParentTrigger(false);
    }
    
}