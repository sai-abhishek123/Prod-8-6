public class CSISIntegrationManager {
    @TestVisible
    private static Boolean isProcessingLineItems = false;
    private static Set<String> processedExternalIds = new Set<String>();
    private static Boolean skipParentTrigger = false;
    private static String registrationStatus;
    private static Boolean skipAttendeeTrigger = false;

    public static void setSkipAttendeeTrigger(Boolean skip) {
        skipAttendeeTrigger = skip;
    }

    public static Boolean shouldSkipAttendeeTrigger() {
        return skipAttendeeTrigger;
    }
    
    public static void setRegistrationStatus(String status) {
        registrationStatus = status;
    }
    
    public static String getRegistrationStatus() {
        return registrationStatus;
    }
    
    public static void setSkipParentTrigger(Boolean skip) {
        skipParentTrigger = skip;
    }

    public static void resetState() {
        isProcessingLineItems = false;
        skipParentTrigger = false;
        skipAttendeeTrigger = false;
        processedExternalIds.clear();
    }

    public static Boolean shouldSkipParentTrigger() {
        return skipParentTrigger;
    }

    public static Boolean isRecordProcessed(String externalId) {
        if (String.isBlank(externalId)) return false;
        if (isProcessingLineItems) return true;
        return processedExternalIds.contains(externalId);
    }
    
    public static void markRecordProcessed(String externalId) {
        if (String.isBlank(externalId)) return;
        processedExternalIds.add(externalId);
    }
    
    public static void setLineItemProcessing(Boolean isProcessing) {
        isProcessingLineItems = isProcessing;
        System.debug('LineItem processing flag set to: ' + isProcessing);
    }
    
    public static Boolean isLineItemProcessing() {
        return isProcessingLineItems;
    }
    
    public static Boolean processOrder(String externalId, Boolean fromLineItem) {
        if (String.isBlank(externalId) || isRecordProcessed(externalId)) {
            return false;
        }
        
        markRecordProcessed(externalId);
        
        if (!fromLineItem) {
            return false;
        }
        
        if (CSISOrderQueueable.isIdInProgress(externalId)) {
            return false;
        }
        
        System.enqueueJob(new CSISOrderQueueable(externalId));
        return true;
    }
}