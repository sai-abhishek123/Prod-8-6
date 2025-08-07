@isTest
public class Test_CSISIntegrationModels {

    @testSetup
    static void setupTestData() {
        // Account (Organizer)
        Account acc = new Account(Name = 'Test Account');//, Computed_ID__c = 'ACC-123');
        insert acc;

        // Contact
        Contact con = new Contact(FirstName = 'John', LastName = 'Doe', Fax = '123456789');
        insert con;

        // Event
        conference360__Event__c evt = new conference360__Event__c(
            Name = 'Test Event',
            conference360__Event_Start_Date__c = Date.today(),
            conference360__Event_End_Date__c = Date.today().addDays(1),
            conference360__Organizer_Account__c = acc.Id,
            conference360__Status__c = 'Active',
            L3__c = true,
            // Custom_Event_Page_URL__c = 'https://example.com/event',
            Fiscal_Year__c = '2025'
        );
        insert evt;

        // Order
        bt_stripe__Sales_Document__c order = new bt_stripe__Sales_Document__c(
            conference360__Event__c = evt.Id,
            bt_stripe__Total_Amount__c = 500,
            bt_stripe__Balance_Due_Amount__c = 200,
            bt_stripe__Balance_Paid_Amount__c = 300,
            bt_Stripe__Status__c = 'Completed',
            bt_stripe__Payment_Status__c = 'Paid'
        );
        insert order;

        // Attendee
        conference360__Attendee__c att = new conference360__Attendee__c(
            conference360__First_Name2__c = 'Alice',
            conference360__Last_Name2__c = 'Smith',
            conference360__Title__c = 'Engineer',
            conference360__Street__c = '123 Main St',
            conference360__City__c = 'San Francisco',
            conference360__State__c = 'CA',
            conference360__Postal_Code__c = '94105',
            conference360__Country__c = 'US',
            conference360__Email2__c = 'alice@example.com',
            conference360__Phone2__c = '123-456-7890',
            conference360__Event__c = evt.Id,
            conference360__Registration_Status__c = 'Registered',
            conference360__Contact__c = con.Id,
            conference360__Account__c = acc.Id
        );
        insert att;

        // Product
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'TP-001');//, Product_Code_Base__c = 'BASE-01', IsActive = true);
        insert prod;

        // Event Item
        conference360__Event_Item__c ei = new conference360__Event_Item__c( conference360__Product__c = prod.Id);
        insert ei;

        // Line Item
        bt_stripe__Line_Item__c lineItem = new bt_stripe__Line_Item__c(
            bt_stripe__Sales_Document__c = order.Id,
            bt_stripe__Item_Name__c = 'Registration',
            conference360__Event_Item__c = ei.Id,
            bt_stripe__Quantity__c = 2,
            bt_stripe__List_Price__c = 250,
            bt_stripe__Tax_Amount__c = 10,
            Line_Item_Status__c = 'Active',
            conference360__Attendee__c = att.Id,
            bt_stripe__Sort_Order__c = 1
        );
        insert lineItem;
    }

    @isTest
    static void test_statusCodeMapping() {
        // Test all paths of getStatusCode
        System.assertEquals('40', CSISIntegrationModels.getStatusCode('Canceled'));
        System.assertEquals('45', CSISIntegrationModels.getStatusCode('Closed'));
        System.assertEquals('50', CSISIntegrationModels.getStatusCode('Completed'));
        System.assertEquals('35', CSISIntegrationModels.getStatusCode('On Hold'));
        System.assertEquals('28', CSISIntegrationModels.getStatusCode('Pending'));
        System.assertEquals('10', CSISIntegrationModels.getStatusCode('Request/Enquiry'));
        System.assertEquals('30', CSISIntegrationModels.getStatusCode('Active'));
        System.assertEquals('30', CSISIntegrationModels.getStatusCode('Unknown'));
        System.assertEquals('30', CSISIntegrationModels.getStatusCode(null));
    }

    @isTest
    static void test_checkCancelled_SubstituteRegStatus() {
        System.assertEquals('A', CSISIntegrationModels.checkCancelled_SubstituteRegStatus('Cancelled - Substitute', 'Active'));
        System.assertEquals('X', CSISIntegrationModels.checkCancelled_SubstituteRegStatus('Cancelled', 'Canceled'));
        System.assertEquals('A', CSISIntegrationModels.checkCancelled_SubstituteRegStatus('Registered', 'Active'));
        System.assertEquals('A', CSISIntegrationModels.checkCancelled_SubstituteRegStatus(null, null));
    }

    @isTest
    static void test_setAndGetRegistrationStatus() {
        CSISIntegrationModels.setRegistrationStatus('Registered');
        System.assertEquals('Registered', CSISIntegrationModels.getRegistrationStatus());
    }

    @isTest
    static void test_CSISPayload_and_CSISData() {
        CSISIntegrationModels.CSISPayload payload = new CSISIntegrationModels.CSISPayload();
        System.assertNotEquals(null, payload.data);
        System.assertEquals(0, payload.data.registrants.size());
    }

    @isTest
    static void test_EventDataModel() {
        conference360__Event__c evt = [
            SELECT Id, Name, conference360__Event_Start_Date__c, conference360__Event_End_Date__c,
                   conference360__Organizer_Account__r.Computed_ID__c, Department__r.ATP_Id__c, Event_ID__c,
                   Course_Offering__r.SectionNumber, conference360__Status__c, L3__c, Custom_Event_Page_URL__c,
                   Fiscal_Year__c
            FROM conference360__Event__c LIMIT 1
        ];
        CSISIntegrationModels.EventDataModel model = new CSISIntegrationModels.EventDataModel(evt);
        System.assertNotEquals(null, model.EventID);
        System.assertEquals('YES', model.L3);
    }

    @isTest
    static void test_CsisOrderData() {
        bt_stripe__Sales_Document__c order = [
            SELECT Id, Name, bt_stripe__Total_Amount__c, bt_stripe__Balance_Due_Amount__c, bt_stripe__Balance_Paid_Amount__c,
       bt_Stripe__Status__c, bt_stripe__Payment_Status__c, bt_stripe__Tax_Amount__c,
       CreatedDate, LastModifiedDate,
       (SELECT Line_Item_Status__c FROM bt_stripe__Sales_Document_Items2__r), bt_stripe__Bill_To__r.Computed_ID__c,
       conference360__Event__r.Event_ID__c, conference360__Event__r.L3__c,
       conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c
FROM bt_stripe__Sales_Document__c
LIMIT 1
        ];
        CSISIntegrationModels.setRegistrationStatus('Registered');
        CSISIntegrationModels.CsisOrderData orderData = new CSISIntegrationModels.CsisOrderData(order);
        System.assertEquals('A', orderData.OrderStatus);
        System.assertEquals('YES', orderData.L3);
    }

    @isTest
    static void test_CsisRegistrant() {
        conference360__Attendee__c att = [
            SELECT Id, conference360__First_Name2__c, conference360__Last_Name2__c, conference360__Title__c,
                   conference360__Street__c, conference360__City__c, conference360__State__c, conference360__Postal_Code__c,
                   conference360__Country__c, conference360__Email2__c, conference360__Phone2__c,
                   conference360__Contact__r.Fax, Computed_ID__c,
                   conference360__Registration_Status__c,
                   conference360__Account__r.Computed_ID__c, conference360__Account__r.Name,
                   conference360__Event__r.Event_ID__c, conference360__Event__r.L3__c
            FROM conference360__Attendee__c LIMIT 1
        ];
        CSISIntegrationModels.CsisRegistrant reg = new CSISIntegrationModels.CsisRegistrant(att);
        System.assertEquals('A', reg.RegistrationStatus);
        System.assertEquals('YES', reg.L3);
    }

    @isTest
    static void test_OrderItem() {
        bt_stripe__Line_Item__c li = [
            SELECT bt_stripe__Sales_Document__r.Name,
                   bt_stripe__Sort_Order__c,
                   conference360__Attendee__r.conference360__Account__r.Computed_ID__c,
                   conference360__Event_Item__r.conference360__Product__r.ProductCode,
                   conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c,
                   bt_stripe__Item_Name__c, Line_Item_Status__c,
                   bt_stripe__Quantity__c, bt_stripe__List_Price__c, bt_stripe__Tax_Amount__c,
                   CreatedDate, LastModifiedDate
            FROM bt_stripe__Line_Item__c LIMIT 1
        ];
        CSISIntegrationModels.OrderItem oi = new CSISIntegrationModels.OrderItem(li);
        System.assertEquals('O', oi.ItemStatus);
        System.assertEquals('TP-001', oi.ResourceCode);
    }
}