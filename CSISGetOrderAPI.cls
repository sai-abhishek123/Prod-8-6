@RestResource(urlMapping='/api/csis/getorder/regaccountcode/*')
global with sharing class CSISGetOrderAPI {
    
    global class CSISResponse {
        public Boolean success { get; set; }
        public String message { get; set; }
        public Object data { get; set; }
        public DateTime timestamp { get; set; }
        
        public CSISResponse() {
            this.timestamp = DateTime.now();
        }
    }
    
    @HttpGet
    global static void getOrderData() {
        Map<String, Object> response = new Map<String, Object>();
        response.put('timestamp', DateTime.now());
        
        try {
            RestRequest req = RestContext.request;
            
            String requestURI = req.requestURI;
            String regAccountCode = '';
            
            if (requestURI.contains('/regaccountcode/')) {
                String[] pathParts = requestURI.split('/regaccountcode/');
                if (pathParts.size() > 1) {
                    regAccountCode = pathParts[1];
                    if (regAccountCode.contains('?')) {
                        regAccountCode = regAccountCode.split('\\?')[0];
                    }
                    if (regAccountCode.endsWith('/')) {
                        regAccountCode = regAccountCode.substring(0, regAccountCode.length() - 1);
                    }
                }
            }
            
            if (String.isBlank(regAccountCode)) {
                response.put('success', false);
                response.put('message', 'regAccountCode is required in the URL path');
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }
            
            String whereClause = 'WHERE Id = :regAccountCode OR Computed_Attendee_ID__c = :regAccountCode';
            
            String query = 'SELECT Id, Computed_Attendee_ID__c, conference360__Event__c, conference360__Sales_Document__c, ' +
                          'conference360__First_Name2__c, conference360__Last_Name2__c, ' +
                          'conference360__Title__c, conference360__Street__c, conference360__City__c, ' +
                          'conference360__State__c, conference360__Postal_Code__c, conference360__Country__c, ' +
                          'conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c, ' +
                          'conference360__Contact__r.externalId__c, conference360__Contact__r.Fax, ' +
                          'conference360__Account__r.Name, conference360__Account__r.Computed_ID__c, ' +
                          'conference360__Event__r.externalId__c, conference360__Event__r.L3__c, ' +
                          'conference360__Event__r.Event_ID__c ' +
                          'FROM conference360__Attendee__c ' + whereClause + ' ' +
                          'ORDER BY LastModifiedDate DESC LIMIT 1';
            
            List<conference360__Attendee__c> attendees = Database.query(query);
            
            if (attendees.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No attendee found with regAccountCode: ' + regAccountCode);
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }
            
            conference360__Attendee__c attendee = attendees[0];
            
            bt_stripe__Sales_Document__c salesDoc = null;
            if (attendee.conference360__Sales_Document__c != null) {
                List<bt_stripe__Sales_Document__c> salesDocs = [
                    SELECT Id, externalId__c, bt_stripe__Bill_To__c, Name,
                           bt_stripe__Bill_To__r.externalId__c, bt_stripe__Payment_Status__c, 
                           conference360__Event__c, conference360__Event__r.externalId__c, conference360__Event__r.Event_ID__c,
                           conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c,
                           bt_stripe__Total_Amount__c, bt_stripe__Balance_Paid_Amount__c, createdDate, 
                           bt_stripe__Balance_Due_Amount__c, LastModifiedDate, bt_stripe__Tax_Amount__c, 
                           conference360__Event__r.L3__c, bt_stripe__Bill_To__r.Computed_ID__c, bt_Stripe__Status__c
                    FROM bt_stripe__Sales_Document__c 
                    WHERE Id = :attendee.conference360__Sales_Document__c
                    LIMIT 1
                ];
                
                if (!salesDocs.isEmpty()) {
                    salesDoc = salesDocs[0];
                }
            }
            
            List<bt_stripe__Line_Item__c> lineItems = [
                SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.Name, 
                       bt_stripe__Sort_Order__c, conference360__Attendee__c,
                       conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                       conference360__Attendee__r.Computed_Attendee_ID__c,
                       conference360__Event_Item__r.conference360__Product__r.ProductCode,
                       conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c,
                       conference360__Attendee__r.conference360__Event_Item__r.conference360__Product__r.ProductCode,
                       bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                       bt_stripe__Tax_Amount__c, bt_stripe__Item_Name__c, Line_Item_Status__c,
                       bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, 
                       bt_stripe__Product__r.Product_Code_Base__c, CreatedDate, LastModifiedDate
                FROM bt_stripe__Line_Item__c 
                WHERE conference360__Attendee__c = :attendee.Id
            ];
            
            CSISIntegrationModels.CSISPayload payload = buildCSISPayload(attendee, salesDoc, lineItems);
            
            response.put('success', true);
            response.put('message', 'Order data retrieved successfully');
            response.put('data', payload.data);
            
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error retrieving order data: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'CSIS Get Order API Error: ' + e.getMessage());
        }
        
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
    }
    
    @HttpPost
    global static void postOrderData() {
        Map<String, Object> response = new Map<String, Object>();
        response.put('timestamp', DateTime.now());
        
        try {
            RestRequest req = RestContext.request;
            String requestBody = req.requestBody.toString();
            
            Map<String, Object> requestData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            String regAccountCode = (String) requestData.get('regAccountCode');
            String attendeeId = (String) requestData.get('attendeeId');
            
            if (String.isBlank(regAccountCode) && String.isBlank(attendeeId)) {
                response.put('success', false);
                response.put('message', 'regAccountCode or attendeeId is required in request body');
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }
            
            String whereClause = '';
            if (String.isNotBlank(regAccountCode)) {
                whereClause = 'WHERE Id = :regAccountCode OR Computed_Attendee_ID__c = :regAccountCode';
            } else if (String.isNotBlank(attendeeId)) {
                whereClause = 'WHERE Id = :attendeeId OR Computed_Attendee_ID__c = :attendeeId';
            }
            
            String query = 'SELECT Id, Computed_Attendee_ID__c, conference360__Event__c, conference360__Sales_Document__c, ' +
                          'conference360__First_Name2__c, conference360__Last_Name2__c, ' +
                          'conference360__Title__c, conference360__Street__c, conference360__City__c, ' +
                          'conference360__State__c, conference360__Postal_Code__c, conference360__Country__c, ' +
                          'conference360__Email2__c, conference360__Phone2__c, conference360__Registration_Status__c, ' +
                          'conference360__Contact__r.externalId__c, conference360__Contact__r.Fax, ' +
                          'conference360__Account__r.Name, conference360__Account__r.Computed_ID__c, ' +
                          'conference360__Event__r.externalId__c, conference360__Event__r.L3__c, ' +
                          'conference360__Event__r.Event_ID__c ' +
                          'FROM conference360__Attendee__c ' + whereClause + ' ' +
                          'ORDER BY LastModifiedDate DESC LIMIT 1';
            
            List<conference360__Attendee__c> attendees = Database.query(query);
            
            if (attendees.isEmpty()) {
                String searchTerm = String.isNotBlank(regAccountCode) ? regAccountCode : attendeeId;
                String searchType = String.isNotBlank(regAccountCode) ? 'regAccountCode' : 'attendeeId';
                response.put('success', false);
                response.put('message', 'No attendee found with ' + searchType + ': ' + searchTerm);
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }
            
            conference360__Attendee__c attendee = attendees[0];
            
            bt_stripe__Sales_Document__c salesDoc = null;
            if (attendee.conference360__Sales_Document__c != null) {
                List<bt_stripe__Sales_Document__c> salesDocs = [
                    SELECT Id, externalId__c, bt_stripe__Bill_To__c, Name,
                           bt_stripe__Bill_To__r.externalId__c, bt_stripe__Payment_Status__c, 
                           conference360__Event__c, conference360__Event__r.externalId__c, conference360__Event__r.Event_ID__c,
                           conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c,
                           bt_stripe__Total_Amount__c, bt_stripe__Balance_Paid_Amount__c, createdDate, 
                           bt_stripe__Balance_Due_Amount__c, LastModifiedDate, bt_stripe__Tax_Amount__c, 
                           conference360__Event__r.L3__c, bt_stripe__Bill_To__r.Computed_ID__c, bt_Stripe__Status__c
                    FROM bt_stripe__Sales_Document__c 
                    WHERE Id = :attendee.conference360__Sales_Document__c
                    LIMIT 1
                ];
                
                if (!salesDocs.isEmpty()) {
                    salesDoc = salesDocs[0];
                }
            }
            
            List<bt_stripe__Line_Item__c> lineItems = [
                SELECT Id, bt_stripe__Sales_Document__c, bt_stripe__Sales_Document__r.Name, 
                       bt_stripe__Sort_Order__c, conference360__Attendee__c,
                       conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                       conference360__Attendee__r.Computed_Attendee_ID__c,
                       conference360__Event_Item__r.conference360__Product__r.ProductCode,
                       conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c,
                       conference360__Attendee__r.conference360__Event_Item__r.conference360__Product__r.ProductCode,
                       bt_stripe__Description__c, bt_stripe__Quantity__c, bt_stripe__List_Price__c, 
                       bt_stripe__Tax_Amount__c, bt_stripe__Item_Name__c, Line_Item_Status__c,
                       bt_stripe__Product__c, bt_stripe__Product__r.ProductCode, 
                       bt_stripe__Product__r.Product_Code_Base__c, CreatedDate, LastModifiedDate
                FROM bt_stripe__Line_Item__c 
                WHERE conference360__Attendee__c = :attendee.Id
            ];
            
            CSISIntegrationModels.CSISPayload payload = buildCSISPayload(attendee, salesDoc, lineItems);
            
            response.put('success', true);
            response.put('message', 'Order data retrieved successfully');
            response.put('data', payload.data);
            
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error retrieving order data: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'CSIS Get Order API Error: ' + e.getMessage());
        }
        
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
    }
    
    private static CSISIntegrationModels.CSISPayload buildCSISPayload(
        conference360__Attendee__c attendee, 
        bt_stripe__Sales_Document__c salesDoc, 
        List<bt_stripe__Line_Item__c> lineItems
    ) {
        CSISIntegrationModels.setRegistrationStatus(attendee.conference360__Registration_Status__c);
        
        CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
        
        CSISIntegrationModels.CsisRegistrant registrant = new CSISIntegrationModels.CsisRegistrant();
        registrant.RegistrationStatus = (attendee.conference360__Registration_Status__c == 'Registered') ? 'A' : 'X';
        registrant.RegAccountCode = attendee.conference360__Account__r?.Computed_ID__c;
        registrant.ExternalCode = attendee.conference360__Account__r?.Computed_ID__c;
        registrant.CompanyName = attendee.conference360__Account__r.Name;
        registrant.FirstName = attendee.conference360__First_Name2__c;
        registrant.LastName = attendee.conference360__Last_Name2__c;
        registrant.Title = attendee.conference360__Title__c;
        registrant.AddressLine1 = attendee.conference360__Street__c;
        registrant.City = attendee.conference360__City__c;
        registrant.StateCode = attendee.conference360__State__c;
        registrant.PostalCode = attendee.conference360__Postal_Code__c;
        registrant.CountryCode = attendee.conference360__Country__c;
        registrant.EmailAddress = attendee.conference360__Email2__c;
        registrant.MainPhone = attendee.conference360__Phone2__c;
        registrant.MainFax = attendee.conference360__Contact__r?.Fax;
        registrant.RegSeq = attendee.Computed_Attendee_ID__c;
        registrant.EventId = attendee.conference360__Event__r?.Event_ID__c;
        registrant.L3 = (attendee.conference360__Event__r?.L3__c == true) ? 'YES' : 'NO';
        
        payload.data.registrants.add(registrant);
        
        if (salesDoc != null) {
            CSISIntegrationModels.CsisOrderData orderModel = new CSISIntegrationModels.CsisOrderData(salesDoc);
            
            String registrationStatus = attendee.conference360__Registration_Status__c;
            if (registrationStatus != null && registrationStatus.contains('Cancel')) {
                orderModel.OrderStatus = 'X';
            } else if (registrationStatus == 'Registered') {
                orderModel.OrderStatus = 'A';
            }
            
            orderModel.OrderItems = new List<CSISIntegrationModels.OrderItem>();
            for (bt_stripe__Line_Item__c lineItem : lineItems) {
                CSISIntegrationModels.OrderItem itemModel = new CSISIntegrationModels.OrderItem();
                
                if (lineItem.bt_stripe__Sales_Document__r != null && lineItem.bt_stripe__Sales_Document__r.Name != null && lineItem.bt_stripe__Sales_Document__r.Name.contains('-')) {
                    String[] nameParts = lineItem.bt_stripe__Sales_Document__r.Name.split('-');
                    if (nameParts.size() > 1) {
                        itemModel.OrderID = nameParts[1];
                    } else {
                        itemModel.OrderID = lineItem.bt_stripe__Sales_Document__r.Name;
                    }
                } else if (lineItem.bt_stripe__Sales_Document__r != null) {
                    itemModel.OrderID = lineItem.bt_stripe__Sales_Document__r.Name;
                } else {
                    itemModel.OrderID = '';
                }
                
                if (lineItem.bt_stripe__Sort_Order__c != null) {
                    itemModel.OrderLine = Integer.valueOf(lineItem.bt_stripe__Sort_Order__c);
                } else {
                    itemModel.OrderLine = 1;
                }
                
                itemModel.RegistrationAccount = lineItem.conference360__Attendee__r?.Computed_Attendee_ID__c;
                itemModel.ResourceCode = lineItem.conference360__Event_Item__r?.conference360__Product__r?.ProductCode;
                itemModel.ResourceType = lineItem.conference360__Event_Item__r?.conference360__Product__r?.Product_Code_Base__c;
                itemModel.RegType = lineItem.conference360__Attendee__r?.conference360__Event_Item__r?.conference360__Product__r?.ProductCode;
                itemModel.ItemDescription = lineItem.bt_stripe__Item_Name__c;
                itemModel.ItemStatus = lineItem.Line_Item_Status__c;
                itemModel.Quantity = lineItem.bt_stripe__Quantity__c != null ? lineItem.bt_stripe__Quantity__c : 1;
                itemModel.UnitCharge = lineItem.bt_stripe__List_Price__c != null ? lineItem.bt_stripe__List_Price__c : 0;
                itemModel.ItemTax = lineItem.bt_stripe__Tax_Amount__c != null ? lineItem.bt_stripe__Tax_Amount__c : 0;
                itemModel.Entered = lineItem.CreatedDate != null ? lineItem.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
                itemModel.Updated = lineItem.LastModifiedDate != null ? lineItem.LastModifiedDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
                
                if (registrationStatus != null && registrationStatus.contains('Cancel')) {
                    itemModel.ItemStatus = 'Canceled';
                }
                
                orderModel.OrderItems.add(itemModel);
            }
            
            payload.data.orderData = orderModel;
        }
        
        return payload;
    } 
}