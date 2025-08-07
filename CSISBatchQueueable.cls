public class CSISBatchQueueable extends CSISBaseQueueable {
    private Id batchJobId;
    private String batchType;
    private Integer batchSize;
    private Boolean nonIntegratedOnly;
    private Date startDate;
    private Date endDate;
    private String regAccountCode;
    
    public CSISBatchQueueable(String batchType, Integer batchSize, Boolean nonIntegratedOnly) {
        super('BATCH_' + batchType + '_' + DateTime.now().getTime(), 'BATCH');
        this.batchType = batchType;
        this.batchSize = batchSize > 0 ? batchSize : 100;
        this.nonIntegratedOnly = nonIntegratedOnly;
    }
    
    public CSISBatchQueueable(String batchType, Integer batchSize, Date startDate, Date endDate) {
        super('BATCH_' + batchType + '_DATE_' + DateTime.now().getTime(), 'BATCH');
        this.batchType = batchType;
        this.batchSize = batchSize > 0 ? batchSize : 100;
        this.startDate = startDate;
        this.endDate = endDate;
    }
    
    public CSISBatchQueueable(String batchType, Integer batchSize, String regAccountCode) {
        super('BATCH_' + batchType + '_REG_' + DateTime.now().getTime(), 'BATCH');
        this.batchType = batchType;
        this.batchSize = batchSize > 0 ? batchSize : 100;
        this.regAccountCode = regAccountCode;
    }
    
    public override void execute(QueueableContext context) {
        try {
            switch on batchType {
                when 'EVENT' {
                    if (startDate != null && endDate != null) {
                        batchJobId = Database.executeBatch(new CSISEventBatch(startDate, endDate), batchSize);
                    } else {
                        batchJobId = Database.executeBatch(new CSISEventBatch(nonIntegratedOnly), batchSize);
                    }
                }
                when 'ORDER' {
                    batchJobId = Database.executeBatch(new CSISOrderBatch(nonIntegratedOnly), batchSize);
                }
                when 'ATTENDEE' {
                    if (String.isNotBlank(regAccountCode)) {
                        batchJobId = Database.executeBatch(new CSISAttendeeBatch(regAccountCode), batchSize);
                    } else {
                        batchJobId = Database.executeBatch(new CSISAttendeeBatch(nonIntegratedOnly), batchSize);
                    }
                }
            }
            
            System.debug('Started ' + batchType + ' batch job: ' + batchJobId);
            clearOperation(operationId);
        } catch (Exception ex) {
            // handleError(ex, 'Batch Type: ' + batchType); 
        }
        clearOperation(operationId);
    }
    
    public static void runFullIntegration() {
        System.enqueueJob(new CSISBatchQueueable('EVENT', 100, false));
        System.enqueueJob(new CSISBatchQueueable('ORDER', 100, false));
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, false));
    }
    
    public static void runPendingIntegration() {
        System.enqueueJob(new CSISBatchQueueable('EVENT', 100, true));
        System.enqueueJob(new CSISBatchQueueable('ORDER', 100, true));
        System.enqueueJob(new CSISBatchQueueable('ATTENDEE', 100, true));
    }
}