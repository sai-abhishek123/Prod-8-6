public class CSISIntegration {
     
    public static Boolean sendEventsWithJWT(List<conference360__Event__c> events, Set<Id> specificAttendeeIds) {
        if (events == null || events.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'CSIS Integration: Invalid input - events empty');
            return false;
        }

        if (Limits.getDMLStatements() > 0) {
            System.debug('DML detected before callout attempt - switching to queueable');
            List<Id> eventIds = new List<Id>();
            List<Id> attendeeIds = new List<Id>();
            
            for (conference360__Event__c evt : events) {
                eventIds.add(evt.Id);
            }
            
            if (specificAttendeeIds != null) {
                attendeeIds.addAll(new List<Id>(specificAttendeeIds));
            }
            
            System.enqueueJob(new CSISEventQueueable(events, specificAttendeeIds));
            return true; 
        }

        if (CSISIntegrationManager.isLineItemProcessing()) {
            System.debug('Skipping event integration as line items are being processed');
            return true;
        }
        
        CSISIntegrationModels.setRegistrationStatus(null);
        
        Set<Id> eventIds = new Set<Id>();
        for (conference360__Event__c evt : events) {
            eventIds.add(evt.Id);
        }
        
        List<conference360__Event__c> fullEvents = [
            SELECT Id, Name, externalId__c, Department__r.ATP_Id__c, Fiscal_Year__c, Department__r.Computed_ID__c,
                   conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, Event_ID__c,
                   Custom_Event_Page_URL__c, conference360__Organizer_Account__c,
                   conference360__Organizer_Account__r.Computed_ID__c,
                   conference360__Organizer_Account__r.Name
            FROM conference360__Event__c 
            WHERE Id IN :eventIds
        ];
        
        String attendeeQuery = 'SELECT Id, Computed_ID__c, conference360__Event__c, Transfer_From_Attendee__c, ' +
                 'conference360__First_Name2__c, conference360__Last_Name2__c, ' +
                 'conference360__Title__c, conference360__Street__c, conference360__City__c, ' +
                 'conference360__State__c, conference360__Postal_Code__c, conference360__Country__c, ' +
                 'conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c, ' +
                 'conference360__Contact__r.externalId__c, conference360__Contact__r.Fax, ' +
                 'conference360__Account__r.Name, conference360__Account__r.Computed_ID__c, ' +
                 'conference360__Event__r.Event_ID__c, conference360__Event__r.externalId__c, ' +
                 'conference360__Event__r.L3__c, conference360__Event_Item__r.conference360__Product__r.ProductCode, ' +
                 'conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c ' +
                 'FROM conference360__Attendee__c ' +
                 'WHERE conference360__Event__c IN :eventIds';

        if (specificAttendeeIds != null && !specificAttendeeIds.isEmpty()) {
            attendeeQuery += ' AND Id IN :specificAttendeeIds';
        }
        
        Map<Id, List<conference360__Attendee__c>> eventToAttendeesMap = new Map<Id, List<conference360__Attendee__c>>();
        for (Id eventId : eventIds) {
            eventToAttendeesMap.put(eventId, new List<conference360__Attendee__c>());
        }
        
        for (conference360__Attendee__c attendee : Database.query(attendeeQuery)) {
            if (eventToAttendeesMap.containsKey(attendee.conference360__Event__c)) {
                eventToAttendeesMap.get(attendee.conference360__Event__c).add(attendee);
            }
        }
        
        Boolean overallSuccess = true;
        List<conference360__Event__c> eventsToUpdate = new List<conference360__Event__c>();
        Datetime now = Datetime.now();
        
        for (conference360__Event__c event : fullEvents) {
            CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
            
            CSISIntegrationModels.EventDataModel eventModel = new CSISIntegrationModels.EventDataModel(event);
            payload.data.eventData = eventModel;
            
            List<conference360__Attendee__c> attendees = eventToAttendeesMap.containsKey(event.Id) 
                ? eventToAttendeesMap.get(event.Id) 
                : new List<conference360__Attendee__c>();
            
            for (conference360__Attendee__c attendee : attendees) {
                CSISIntegrationModels.CsisRegistrant registrantModel = new CSISIntegrationModels.CsisRegistrant(attendee);
                payload.data.registrants.add(registrantModel);
            }
            
            String jsonBody = JSON.serialize(payload);
            System.debug('CSIS Attendee JSON Payload: ' + jsonBody);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:CSIS_Endpoint');
            req.setMethod('POST');
            req.setBody(jsonBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('CSIS callout response for event ' + event.Id + ': ' + res.getBody());
                
                boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
                
                if (success) {
                    eventsToUpdate.add(new conference360__Event__c(
                        Id = event.Id,
                        Event_Data_Sent_to_CSIS__c = true,
                        CSIS_Transmission_Timestamp__c = now
                    ));
                } else {
                    System.debug(LoggingLevel.ERROR, 'Failed to send event to CSIS: ' + res.getStatusCode() + ': ' + res.getBody());
                    overallSuccess = false;
                }
            } catch(Exception ex) {
                System.debug('CSIS callout exception for event ' + event.Id + ': ' + ex.getMessage());
                overallSuccess = false;
            }
        }
        
        if (!eventsToUpdate.isEmpty()) {
            update eventsToUpdate;
        }
        
        return overallSuccess;
    }
        
    public static Boolean sendEventsWithJWT(List<conference360__Event__c> events) {
        return sendEventsWithJWT(events, null);
    }
    
    public static Boolean sendOrderToCsis(String orderExternalId, Id specificAttendeeId) {
        System.debug('Order External ID: ' + orderExternalId + ', Specific Attendee ID: ' + specificAttendeeId);
        if (String.isBlank(orderExternalId)) {
            return false;
        }

        if (Limits.getDMLStatements() > 0 ) { 
            System.debug('DML detected before callout attempt - switching to queueable');
            System.enqueueJob(new CSISOrderQueueable(orderExternalId, specificAttendeeId));
            return true;
        }

        CSISIntegrationModels.setRegistrationStatus(null);
        try {
            List<bt_stripe__Sales_Document__c> orderDocs = [
                SELECT Id, externalId__c, bt_stripe__Bill_To__c, Name,
                       bt_stripe__Bill_To__r.externalId__c, bt_stripe__Payment_Status__c, 
                       conference360__Event__c, conference360__Event__r.externalId__c, conference360__Event__r.Event_ID__c,
                       conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c,
                       bt_stripe__Total_Amount__c, bt_stripe__Balance_Paid_Amount__c, createdDate, 
                       bt_stripe__Balance_Due_Amount__c, LastModifiedDate, bt_stripe__Tax_Amount__c, 
                       conference360__Event__r.L3__c, bt_stripe__Bill_To__r.Computed_ID__c, bt_Stripe__Status__c,
                       (SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sort_Order__c, conference360__Attendee__c,
                               conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                               bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                               bt_stripe__Tax_Amount__c, bt_stripe__Item_Name__c, Line_Item_Status__c,
                               bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, bt_stripe__Product__r.Product_Code_Base__c, bt_stripe__Sales_Document__r.Name, 
                               bt_stripe__Sales_Document__r.externalId__c, CreatedDate, LastModifiedDate, conference360__Event_Item__r.conference360__Product__c, 
                               conference360__Event_Item__r.conference360__Product__r.ProductCode, conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c
                        FROM bt_stripe__Sales_Document_Items2__r)
                FROM bt_stripe__Sales_Document__c 
                WHERE externalId__c = :orderExternalId
                LIMIT 1
            ];
            
            if (orderDocs.isEmpty()) {
                return false;
            }
            
            bt_stripe__Sales_Document__c orderDoc = orderDocs[0];
            List<bt_stripe__Line_Item__c> lineItems = new List<bt_stripe__Line_Item__c>();
            
            if (specificAttendeeId != null) {
                if (orderDoc.bt_stripe__Sales_Document_Items2__r != null && !orderDoc.bt_stripe__Sales_Document_Items2__r.isEmpty()) {
                    for (bt_stripe__Line_Item__c item : orderDoc.bt_stripe__Sales_Document_Items2__r) {
                        if (item.conference360__Attendee__c == specificAttendeeId) {
                            lineItems.add(item);
                        }
                    }
                    System.debug('Found ' + lineItems.size() + ' line items for specific attendee from relationship');
                }
                
                if (lineItems.isEmpty()) {
                    lineItems = [
                        SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.Name, 
                               bt_stripe__Sort_Order__c, conference360__Attendee__c, 
                               conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                               bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                               bt_stripe__Tax_Amount__c, CreatedDate, LastModifiedDate, bt_stripe__Item_Name__c, 
                               Line_Item_Status__c, bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, 
                               bt_stripe__Product__r.Product_Code_Base__c, conference360__Event_Item__c, conference360__Event_Item__r.conference360__Product__c, 
                               conference360__Event_Item__r.conference360__Product__r.ProductCode, conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c
                        FROM bt_stripe__Line_Item__c 
                        WHERE bt_stripe__Sales_Document__c = :orderDoc.Id
                        AND conference360__Attendee__c = :specificAttendeeId
                    ];
                    System.debug('Found ' + lineItems.size() + ' line items for specific attendee from direct query');
                }
            } else {
                if (orderDoc.bt_stripe__Sales_Document_Items2__r != null && !orderDoc.bt_stripe__Sales_Document_Items2__r.isEmpty()) {
                    lineItems = orderDoc.bt_stripe__Sales_Document_Items2__r;
                    System.debug('Found ' + lineItems.size() + ' line items from relationship');
                } else {
                    lineItems = [
                        SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.Name, 
                               bt_stripe__Sort_Order__c, conference360__Attendee__c, 
                               conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                               bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                               bt_stripe__Tax_Amount__c, CreatedDate, LastModifiedDate, bt_stripe__Item_Name__c, 
                               Line_Item_Status__c, bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, 
                               bt_stripe__Product__r.Product_Code_Base__c, conference360__Event_Item__r.conference360__Product__c, 
                               conference360__Event_Item__r.conference360__Product__r.ProductCode, conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c
                        FROM bt_stripe__Line_Item__c 
                        WHERE bt_stripe__Sales_Document__c = :orderDoc.Id
                ];
                System.debug('Found ' + lineItems.size() + ' line items from direct query');
                }
            }
            
            SubstitutionChainResult chainResult = buildCompleteSubstitutionChain(orderDoc, lineItems, specificAttendeeId);
            
            return sendOrderAndRegistrantsToCSIS(orderDoc, lineItems, chainResult.allAttendees, chainResult.primaryAttendee);
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'CSIS Order Integration error: ' + ex.getMessage());
            return false;
        }
    }

    public static Boolean sendOrderToCsis(String orderExternalId) {
        return sendOrderToCsis(orderExternalId, null);
    }
    
    @TestVisible
    private static SubstitutionChainResult buildCompleteSubstitutionChain(bt_stripe__Sales_Document__c orderDoc, 
                                                                        List<bt_stripe__Line_Item__c> lineItems, 
                                                                        Id specificAttendeeId) {
        SubstitutionChainResult result = new SubstitutionChainResult();
        
        // Get ALL attendee IDs from line items
        Set<Id> allAttendeeIds = new Set<Id>();
        Set<Id> currentActiveAttendeeIds = new Set<Id>();
        
        for (bt_stripe__Line_Item__c item : lineItems) {
            if (item.conference360__Attendee__c != null) {
                currentActiveAttendeeIds.add(item.conference360__Attendee__c);
                allAttendeeIds.add(item.conference360__Attendee__c);
            }
        }
        
        // Get all attendees from the sales document
        List<conference360__Attendee__c> salesDocAttendees = [
            SELECT Id, conference360__Registration_Status__c
            FROM conference360__Attendee__c 
            WHERE conference360__Sales_Document__c = :orderDoc.Id
        ];
        
        // Add attendees EXCEPT those with 'Cancelled - Substitute' status
        for (conference360__Attendee__c att : salesDocAttendees) {
            if (att.conference360__Registration_Status__c != 'Cancelled - Substitute') {
                allAttendeeIds.add(att.Id);
            }
        }
        
        // Now get full details for all non-substituted attendees
        if (!allAttendeeIds.isEmpty()) {
            result.allAttendees = [
                SELECT Id, Computed_ID__c, conference360__Event__c, conference360__Sales_Document__c,
                    Transfer_From_Attendee__c, conference360__Registration_Status__c,
                    conference360__First_Name2__c, conference360__Last_Name2__c, 
                    conference360__Title__c, conference360__Street__c, conference360__City__c,
                    conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
                    conference360__Email2__c, conference360__Phone2__c,
                    conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
                    conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
                    conference360__Event__r.externalId__c, conference360__Event__r.L3__c, 
                    conference360__Event__r.Event_ID__c,
                    conference360__Event_Item__r.conference360__Product__r.ProductCode,
                    conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c,
                    conference360__Account__c
                FROM conference360__Attendee__c
                WHERE Id IN :allAttendeeIds
                ORDER BY CreatedDate ASC
            ];
            
            // Determine primary attendee
            if (specificAttendeeId != null) {
                for (conference360__Attendee__c att : result.allAttendees) {
                    if (att.Id == specificAttendeeId) {
                        result.primaryAttendee = att;
                        CSISIntegrationModels.setRegistrationStatus(att.conference360__Registration_Status__c);
                        break;
                    }
                }
            } else {
                // Find the first registered attendee with line items
                for (conference360__Attendee__c att : result.allAttendees) {
                    if (currentActiveAttendeeIds.contains(att.Id) && att.conference360__Registration_Status__c == 'Registered') {
                        result.primaryAttendee = att;
                        break;
                    }
                }
                
                // If no registered attendee found, use the first one
                if (result.primaryAttendee == null && !result.allAttendees.isEmpty()) {
                    result.primaryAttendee = result.allAttendees[0];
                }
            }
            
            result.currentActiveAttendeeIds = currentActiveAttendeeIds;
        }
        
        // Fallback if no attendees found
        if (result.allAttendees.isEmpty() && orderDoc.conference360__Event__c != null && orderDoc.bt_stripe__Bill_To__c != null) {
            result.allAttendees = [
                SELECT Id, Computed_ID__c, conference360__Event__c, conference360__Sales_Document__c,
                    Transfer_From_Attendee__c, conference360__Registration_Status__c,
                    conference360__First_Name2__c, conference360__Last_Name2__c, 
                    conference360__Title__c, conference360__Street__c, conference360__City__c,
                    conference360__State__c, conference360__Postal_Code__c, conference360__Country__c,
                    conference360__Email2__c, conference360__Phone2__c,
                    conference360__Contact__r.externalId__c, conference360__Contact__r.Fax,
                    conference360__Account__r.Name, conference360__Account__r.Computed_ID__c,
                    conference360__Event__r.externalId__c, conference360__Event__r.L3__c, 
                    conference360__Event__r.Event_ID__c,
                    conference360__Event_Item__r.conference360__Product__r.ProductCode,
                    conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c,
                    conference360__Account__c
                FROM conference360__Attendee__c
                WHERE conference360__Event__c = :orderDoc.conference360__Event__c 
                AND conference360__Contact__r.AccountId = :orderDoc.bt_stripe__Bill_To__c
                AND conference360__Registration_Status__c != 'Cancelled - Substitute'
                LIMIT 50
            ];
            
            if (!result.allAttendees.isEmpty()) {
                result.primaryAttendee = result.allAttendees[0];
            }
        }
        
        return result;
    }


    
    @TestVisible
    private static Boolean sendOrderAndRegistrantsToCSIS(bt_stripe__Sales_Document__c orderDoc, 
                                                        List<bt_stripe__Line_Item__c> lineItems, 
                                                        List<conference360__Attendee__c> attendees, 
                                                        conference360__Attendee__c attendeeWithStatus) {
        CSISIntegrationModels.setRegistrationStatus(null);
        List<CSISIntegrationModels.CsisRegistrant> registrantModels = new List<CSISIntegrationModels.CsisRegistrant>();
        
        String registrationStatus = null;
        
        System.debug('SUBSTITUTION PROCESSING: Order=' + orderDoc.Name + ' | LineItems=' + lineItems.size() + 
                  ' | AllAttendees=' + attendees.size() + ' | PrimaryAttendee=' + 
                  (attendeeWithStatus != null ? attendeeWithStatus.conference360__First_Name2__c + ' ' + attendeeWithStatus.conference360__Last_Name2__c : 'None'));
        
        if (attendeeWithStatus != null) {
            registrationStatus = attendeeWithStatus.conference360__Registration_Status__c;
            CSISIntegrationModels.setRegistrationStatus(registrationStatus);
        }
        
        Set<Id> currentActiveAttendeeIds = new Set<Id>();
        for (bt_stripe__Line_Item__c item : lineItems) {
            if (item.conference360__Attendee__c != null) {
                currentActiveAttendeeIds.add(item.conference360__Attendee__c);
            }
        }
        
        for (conference360__Attendee__c attendee : attendees) {
            CSISIntegrationModels.CsisRegistrant registrantModel = new CSISIntegrationModels.CsisRegistrant(attendee);
            
            String regStatus = attendee.conference360__Registration_Status__c;

            if (regStatus == 'Cancelled - Substitute') {
                registrantModel.RegistrationStatus = 'X';
                System.debug('CANCELLED SUBSTITUTE: ' + attendee.conference360__First_Name2__c + ' ' + 
                            attendee.conference360__Last_Name2__c + ' (will be replaced)');
                            
            } else if (regStatus == 'Cancelled') {
                registrantModel.RegistrationStatus = 'X';
                System.debug('CANCELLED: ' + attendee.conference360__First_Name2__c + ' ' + 
                            attendee.conference360__Last_Name2__c + ' (regular cancellation)');
                            
            } else if (regStatus == 'Registered' && currentActiveAttendeeIds.contains(attendee.Id)) {
                registrantModel.RegistrationStatus = 'A';
                System.debug('ACTIVE: ' + attendee.conference360__First_Name2__c + ' ' + 
                            attendee.conference360__Last_Name2__c + ' (registered with line items)');
                            
            } else if (regStatus == 'Registered') {
                registrantModel.RegistrationStatus = 'A';
                System.debug('ACTIVE: ' + attendee.conference360__First_Name2__c + ' ' + 
                            attendee.conference360__Last_Name2__c + ' (registered)');
                            
            } else {
                registrantModel.RegistrationStatus = 'X';
                System.debug('UNKNOWN STATUS (' + regStatus + '): ' + attendee.conference360__First_Name2__c + ' ' + 
                            attendee.conference360__Last_Name2__c + ' - defaulting to X');
            }
            
            registrantModels.add(registrantModel);
        }
        
        CSISIntegrationModels.CsisOrderData orderModel = new CSISIntegrationModels.CsisOrderData(orderDoc);
        
        String originalBillingAccount = orderModel.OrderAccount;
        System.debug('SUBSTITUTION: Keeping original billing account: ' + originalBillingAccount + 
                    ' (from invoice Bill To). NOT changing to new attendee account.');
        
        if (registrationStatus == 'Cancelled - Substitute') {
            orderModel.OrderStatus = 'A';
            System.debug('Setting order status to A (Substitution - replacement attendee active)');
            
        } else if (registrationStatus == 'Cancelled') {
            orderModel.OrderStatus = 'X';
            System.debug('Setting order status to X (Regular cancellation)');
            
        } else if (registrationStatus == 'Registered') {
            orderModel.OrderStatus = 'A';
            System.debug('Setting order status to A (Active registration)');
            
        } else {
            orderModel.OrderStatus = 'A';
            System.debug('Setting order status to A (Default for mixed/unknown statuses)');
        }
        
        if (isGroupOrderWithMixedStatuses(orderDoc.Id, attendeeWithStatus, registrationStatus)) {
            orderModel.OrderStatus = 'A';
            System.debug('Group order detected with mixed statuses - overriding order status to A');
        }
        
        System.debug('Final order status: ' + orderModel.OrderStatus);
        
        List<bt_stripe__Line_Item__c> filteredLineItems = lineItems;
        System.debug('CSIS COMPLETE STATE: Using all ' + filteredLineItems.size() + ' line items for complete order');

        Map<Id, conference360__Attendee__c> cancelledToReplacementMap = new Map<Id, conference360__Attendee__c>();

        for (conference360__Attendee__c att : attendees) {
            if (att.conference360__Registration_Status__c == 'Cancelled - Substitute') {
                for (conference360__Attendee__c replacement : attendees) {
                    if (replacement.Id != att.Id && 
                        replacement.conference360__Registration_Status__c == 'Registered' &&
                        currentActiveAttendeeIds.contains(replacement.Id)) {
                        cancelledToReplacementMap.put(att.Id, replacement);
                        System.debug('SUBSTITUTION MAPPING: ' + att.conference360__First_Name2__c + 
                                    ' (Cancelled - Substitute) -> ' + replacement.conference360__First_Name2__c + ' (Replacement)');
                        break;
                    }
                }
            }
        }

        System.debug('SUBSTITUTION PROCESSING: Found ' + cancelledToReplacementMap.size() + ' substitution mappings');
        
        orderModel.OrderItems = new List<CSISIntegrationModels.OrderItem>();
        for (bt_stripe__Line_Item__c lineItem : filteredLineItems) {
            CSISIntegrationModels.OrderItem itemModel = new CSISIntegrationModels.OrderItem(lineItem);
            
            if (!cancelledToReplacementMap.isEmpty() && 
                cancelledToReplacementMap.containsKey(lineItem.conference360__Attendee__c)) {
                
                conference360__Attendee__c replacementAttendee = cancelledToReplacementMap.get(lineItem.conference360__Attendee__c);
                
                itemModel.RegistrationAccount = replacementAttendee.conference360__Account__r.Computed_ID__c;
                itemModel.ItemDescription = lineItem.bt_stripe__Item_Name__c;
                itemModel.ItemStatus = 'O';
                
                System.debug('SUBSTITUTION REASSIGNMENT: Line item reassigned from ' + 
                            'Cancelled-Substitute attendee to ' + replacementAttendee.conference360__First_Name2__c + ' (ACTIVE)');
                
            } else { 
                Id lineItemAttendeeId = lineItem.conference360__Attendee__c;
                for (conference360__Attendee__c att : attendees) {
                    if (att.Id == lineItemAttendeeId) {
                        if (att.conference360__Registration_Status__c == 'Cancelled') {
                            itemModel.ItemStatus = 'X';
                            System.debug('REGULAR CANCELLATION: Line item cancelled for ' + att.conference360__First_Name2__c);
                            
                        } else if (att.conference360__Registration_Status__c == 'Cancelled - Substitute') {
                            itemModel.ItemStatus = 'X';
                            System.debug('SUBSTITUTE CANCELLATION: Line item cancelled for ' + att.conference360__First_Name2__c + 
                                        ' (should have been reassigned)');
                            
                        } else if (att.conference360__Registration_Status__c == 'Registered') {
                            itemModel.ItemStatus = 'O';
                            System.debug('ACTIVE: Line item active for ' + att.conference360__First_Name2__c);
                            
                        } else {
                            itemModel.ItemStatus = 'X';
                            System.debug('UNKNOWN STATUS: Line item cancelled for ' + att.conference360__First_Name2__c + 
                                        ' (status: ' + att.conference360__Registration_Status__c + ')');
                        }
                        break;
                    }
                }
            }
            
            orderModel.OrderItems.add(itemModel);
        }
        
        CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
        payload.data.orderData = orderModel;
        payload.data.registrants = registrantModels.isEmpty() ? null : registrantModels;
        String jsonBody = JSON.serialize(payload);
        System.debug('CSIS Order JSON Payload: ' + jsonBody);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:CSIS_Endpoint');
        req.setMethod('POST');
        req.setBody(jsonBody);
        req.setTimeout(120000);
        
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('CSIS Order callout response: ' + res.getBody());
            
            boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
            
            if (success) {
                if (!System.isFuture() && !System.isQueueable()) {
                    System.enqueueJob(new CSISUpdateOrderStatusRecordQueueable(orderDoc.Id));
                }
                
                if (registrationStatus != null && registrationStatus.contains('Cancel') && attendeeWithStatus != null ){
                    updateLineItemStatusForAttendee(orderDoc.Id, attendeeWithStatus.Id, 'Canceled');
                }
                
                return true;
            } else {
                System.debug(LoggingLevel.ERROR, 'Failed to send order to CSIS: ' + res.getStatusCode() + ': ' + res.getBody());
                return false;
            }
        } catch(Exception ex) {
            System.debug('CSIS Order callout exception: ' + ex.getMessage());
            return false;
        }
    }

    @TestVisible
    private static Boolean isGroupOrderWithMixedStatuses(Id orderDocId, conference360__Attendee__c specificAttendee, String currentRegStatus) {
        if (specificAttendee == null || currentRegStatus == null || !currentRegStatus.contains('Cancel')) {
            return false;
        }
        
        List<conference360__Attendee__c> allOrderAttendees = [
            SELECT Id, conference360__Registration_Status__c
            FROM conference360__Attendee__c 
            WHERE conference360__Sales_Document__c = :orderDocId
        ];
        
        if (allOrderAttendees.isEmpty()) {
            allOrderAttendees = [
                SELECT Id, conference360__Registration_Status__c
                FROM conference360__Attendee__c 
                WHERE Id IN (
                    SELECT conference360__Attendee__c 
                    FROM bt_stripe__Line_Item__c 
                    WHERE bt_stripe__Sales_Document__c = :orderDocId
                    AND conference360__Attendee__c != null
                )
            ];
        }
        
        if (allOrderAttendees.size() <= 1) {
            return false;
        }
        
        for (conference360__Attendee__c attendee : allOrderAttendees) {
            if (attendee.Id == specificAttendee.Id) {
                continue;
            }
            
            if (attendee.conference360__Registration_Status__c == 'Registered' || 
                (attendee.conference360__Registration_Status__c != null && 
                 !attendee.conference360__Registration_Status__c.contains('Cancel'))) {
                System.debug('Found active attendee in group order: ' + attendee.Id + ' with status: ' + attendee.conference360__Registration_Status__c);
                return true;
            }
        }
        
        return false;
    }

    @TestVisible
    private static void updateLineItemStatusForAttendee(Id orderDocId, Id attendeeId, String status) {
        try {
            List<bt_stripe__Line_Item__c> itemsToUpdate = [
                SELECT Id, Line_Item_Status__c
                FROM bt_stripe__Line_Item__c
                WHERE bt_stripe__Sales_Document__c = :orderDocId
                AND conference360__Attendee__c = :attendeeId
            ];
            
            if (!itemsToUpdate.isEmpty()) {
                for (bt_stripe__Line_Item__c item : itemsToUpdate) {
                    item.Line_Item_Status__c = status;
                }
                
                update itemsToUpdate;
                System.debug('Updated ' + itemsToUpdate.size() + ' line items to status: ' + status);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error updating line item status: ' + ex.getMessage());
        }
    }
    
    @TestVisible
    private class SubstitutionChainResult {
        public List<conference360__Attendee__c> allAttendees { get; set; }
        public conference360__Attendee__c primaryAttendee { get; set; }
        public Set<Id> currentActiveAttendeeIds { get; set; }
        
        public SubstitutionChainResult() {
            this.allAttendees = new List<conference360__Attendee__c>();
            this.primaryAttendee = null;
            this.currentActiveAttendeeIds = new Set<Id>();
        }
    }
}