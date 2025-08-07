public class CSISScheduledQueueable implements Schedulable {
    private String className;
    private Map<String, Object> params;
    
    public CSISScheduledQueueable(String className, Map<String, Object> params) {
        this.className = className;
        this.params = params;
    }
    
    public void execute(SchedulableContext sc) {
        instantiateAndEnqueueJob();
        
        if (!Test.isRunningTest()) {
            System.abortJob(sc.getTriggerId());
        }
    }
    
    private void instantiateAndEnqueueJob() {
        try {
            if (className == 'CSISEventQueueable') {
                instantiateEventQueueable();
            } else if (className == 'CSISOrderQueueable') {
                instantiateOrderQueueable();
            } else if (className == 'CSISAttendeeQueueable') {
                instantiateAttendeeQueueable();
            } else {
                System.debug(LoggingLevel.ERROR, 'Unsupported queueable class name: ' + className);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error enqueuing ' + className + ': ' + ex.getMessage());
        }
    }
    
    private void instantiateEventQueueable() {
        if (params.containsKey('events')) {
            List<conference360__Event__c> events = (List<conference360__Event__c>)params.get('events');
            System.enqueueJob(new CSISEventQueueable(events));
        } else if (params.containsKey('eventIds')) {
            List<Id> eventIds = (List<Id>)params.get('eventIds');
            Set<Id> attendeeIds = params.containsKey('attendeeIds') ? 
                new Set<Id>((List<Id>)params.get('attendeeIds')) : null;
                
            if (attendeeIds != null) {
                CSISEventQueueable.enqueueEvents(eventIds, new List<Id>(attendeeIds));
            } else {
                CSISEventQueueable.enqueueEvents(eventIds);
            }
        }
    }
    
    private void instantiateOrderQueueable() {
        String triggerType = params.containsKey('triggerType') ? (String)params.get('triggerType') : null;
        Boolean isSubstitution = params.containsKey('isSubstitution') ? (Boolean)params.get('isSubstitution') : false;
        
        System.debug('CSISScheduledQueueable: Processing order queueable - TriggerType: ' + triggerType + 
                    ', IsSubstitution: ' + isSubstitution);
        
        if (params.containsKey('orderExternalId')) {
            String orderExternalId = (String)params.get('orderExternalId');
            Id attendeeId = params.containsKey('attendeeId') ? (Id)params.get('attendeeId') : null;
            String regStatus = params.containsKey('registrationStatus') ? 
                (String)params.get('registrationStatus') : null;
            
            if (triggerType == 'FLOW_NEW_SUBSTITUTE') {
                
                System.debug('CSISScheduledQueueable: Handling FLOW_NEW_SUBSTITUTE for order: ' + orderExternalId);
                System.enqueueJob(new CSISOrderQueueable(orderExternalId)); 
                
            } else if (triggerType == 'FLOW_CANCEL_SUBSTITUTE') {
                System.debug('CSISScheduledQueueable: Handling FLOW_CANCEL_SUBSTITUTE for attendee: ' + attendeeId);
                if (attendeeId != null && regStatus != null) {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId, attendeeId, regStatus));
                } else {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId, attendeeId));
                }
                
            } else {
                if (attendeeId != null && regStatus != null) {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId, attendeeId, regStatus));
                } else if (regStatus != null) {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId, regStatus));
                } else if (attendeeId != null) {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId, attendeeId));
                } else {
                    System.enqueueJob(new CSISOrderQueueable(orderExternalId));
                }
            }
            
        } else if (params.containsKey('orderExternalIds')) {
            List<String> externalIds = (List<String>)params.get('orderExternalIds');
            String regStatus = params.containsKey('registrationStatus') ? 
                (String)params.get('registrationStatus') : null;
            
            if (isSubstitution) {
                
                for (String extId : externalIds) {
                    System.enqueueJob(new CSISOrderQueueable(extId));
                }
            } else {
                System.enqueueJob(new CSISOrderQueueable(externalIds, regStatus));
            }
        }
    }
    
    private void instantiateAttendeeQueueable() {
        if (params.containsKey('attendeeIds')) {
            List<Id> attendeeIds = (List<Id>)params.get('attendeeIds');
            Boolean isSubstitution = params.containsKey('isSubstitution') ? (Boolean)params.get('isSubstitution') : false;
            Boolean isCancellation = params.containsKey('isCancellation') ? (Boolean)params.get('isCancellation') : false;
            
            if (!attendeeIds.isEmpty()) {
                if (isSubstitution) {
                    System.debug('CSISScheduledQueueable: Processing substitution attendees: ' + attendeeIds.size());
                } else if (isCancellation) {
                    System.debug('CSISScheduledQueueable: Processing cancellation attendees: ' + attendeeIds.size());
                }
                
                System.enqueueJob(new CSISAttendeeQueueable(attendeeIds));
            }
        }
    }
    
    public static String scheduleQueueableJob(String className, Map<String, Object> params, Integer delayMinutes) {
        DateTime scheduledTime = DateTime.now().addMinutes(delayMinutes);
        String jobName = className + '_' + System.now().getTime();
        
        if (params.containsKey('triggerType')) {
            jobName += '_' + params.get('triggerType');
        }
        
        String cronExp = '' + scheduledTime.second() + ' ' + 
                        scheduledTime.minute() + ' ' + 
                        scheduledTime.hour() + ' ' + 
                        scheduledTime.day() + ' ' + 
                        scheduledTime.month() + ' ? ' + 
                        scheduledTime.year();
        
        CSISScheduledQueueable schedulable = new CSISScheduledQueueable(className, params);
        
        System.debug('CSISScheduledQueueable: Scheduling job ' + jobName + ' with params: ' + params);
        
        return System.schedule(jobName, cronExp, schedulable);
    }
}