public class CSISIntegrationModels {
    private static String regstatus;
    
    public static void setRegistrationStatus(String status) {
        regstatus = status;
    }
    
    public static String getRegistrationStatus() {
        return regstatus;
    }
    
    public class CSISPayload {
        public CSISData data { get; set; }
        
        public CSISPayload() {
            this.data = new CSISData();
        }
    }
    
    public class CSISData {
        public EventDataModel eventData { get; set; }
        public CsisOrderData orderData { get; set; }
        public List<CsisRegistrant> registrants { get; set; }
        
        public CSISData() {
            this.registrants = new List<CsisRegistrant>();
        }
    }
    
    public class EventDataModel {
        public String EventID { get; set; }
        public String EventDesc { get; set; }
        public String EventClass { get; set; }
        public String EventCategory { get; set; }
        public String EventStartDate { get; set; }
        public String EventEndDate { get; set; }
        public String EventSearch { get; set; }
        public String EventCustomerNumber { get; set; }
        public String EventStatus { get; set; }
        public String L3 { get; set; }
        public String WebAddress { get; set; }
        
        public EventDataModel() {}
        
        public EventDataModel(conference360__Event__c event) {
            this.EventID = event.Event_ID__c;
            this.EventDesc = event.Name;
            this.EventClass = event.Department__r != null ? event.Department__r.ATP_Id__c : '';
            this.EventCategory = event.Fiscal_Year__c;
            this.EventStartDate = event.conference360__Event_Start_Date__c != null ? 
                            Datetime.newInstance(event.conference360__Event_Start_Date__c, Time.newInstance(0, 0, 0, 0)).format('M/d/yyyy h:mm:ss a') : null;
            this.EventEndDate = event.conference360__Event_End_Date__c != null ? 
                            Datetime.newInstance(event.conference360__Event_End_Date__c, Time.newInstance(0, 0, 0, 0)).format('M/d/yyyy h:mm:ss a') : null;
            this.EventSearch = event.Course_Offering__r != null ? event.Course_Offering__r.SectionNumber : '';
            this.EventCustomerNumber = event.conference360__Organizer_Account__r != null ? event.conference360__Organizer_Account__r.Computed_ID__c : '';
            this.EventStatus = getStatusCode(event.conference360__Status__c);
            this.L3 = event.L3__c ? 'YES' : 'NO';
            this.WebAddress = event.Custom_Event_Page_URL__c;
        }
    }
    
    public class CsisOrderData {
        public String OrderID { get; set; }
        public String OrderAccount { get; set; }
        public String OrderStatus { get; set; }
        public String OrderType { get; set; }
        public String EventID { get; set; }
        public Decimal OrderTotal { get; set; }
        public Decimal OrderPayments { get; set; }
        public String OrderDate { get; set; }
        public Decimal NetDue { get; set; }
        public String Entered { get; set; }
        public String Updated { get; set; }
        public Decimal OrderTax { get; set; }
        public String L3 { get; set; }
        public List<OrderItem> OrderItems { get; set; }
        public String InvoiceStatus { get; set; }
        public String PaymentStatus { get; set; }
        
        public CsisOrderData() {
            this.OrderItems = new List<OrderItem>();
        }
        
        public CsisOrderData(bt_stripe__Sales_Document__c doc) {
            this();
            String[] numbers = doc.Name.split('-');
            this.OrderID = numbers[1];
            
            String regStatus = CSISIntegrationModels.getRegistrationStatus();
            if (String.isNotBlank(regStatus)) {

                String itemStatus;// = 'Active'; // Default value
                if (doc.bt_stripe__Sales_Document_Items2__r != null && !doc.bt_stripe__Sales_Document_Items2__r.isEmpty()) {
                    itemStatus = doc.bt_stripe__Sales_Document_Items2__r[0].Line_Item_Status__c;
}
                // this.OrderStatus = (regStatus == 'Registered') ? 'A' : 'X';
                // this.OrderStatus = checkCancelled_SubstituteRegStatus(regStatus);
                this.OrderStatus = checkCancelled_SubstituteRegStatus(regStatus, itemStatus);
            }

            if (doc.bt_stripe__Bill_To__r != null && String.isNotBlank(doc.bt_stripe__Bill_To__r.Computed_ID__c)) {
                this.OrderAccount = doc.bt_stripe__Bill_To__r.Computed_ID__c;
            } else if (doc.conference360__Event__r != null && 
                       doc.conference360__Event__r.conference360__Organizer_Account__r != null &&
                       String.isNotBlank(doc.conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c)) {
                this.OrderAccount = doc.conference360__Event__r.conference360__Organizer_Account__r.Computed_ID__c;
            } else {
                this.OrderAccount = '';
            }
            
            this.OrderType = 'ER';
            this.EventID = doc.conference360__Event__r.Event_ID__c;
            this.OrderTotal = doc.bt_stripe__Total_Amount__c != null ? doc.bt_stripe__Total_Amount__c : 0;
            this.OrderPayments = doc.bt_stripe__Balance_Paid_Amount__c != null ? doc.bt_stripe__Balance_Paid_Amount__c : 0;
            this.OrderDate = doc.createdDate != null ? doc.createdDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
            this.NetDue = doc.bt_stripe__Balance_Due_Amount__c != null ? doc.bt_stripe__Balance_Due_Amount__c : 0;
            this.Entered = doc.createdDate != null ? doc.createdDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
            this.Updated = doc.LastModifiedDate != null ? doc.LastModifiedDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
            this.OrderTax = doc.bt_stripe__Tax_Amount__c != null ? doc.bt_stripe__Tax_Amount__c : 0;
            this.L3 = doc.conference360__Event__r != null && doc.conference360__Event__r.L3__c ? 'YES' : 'NO';
            this.InvoiceStatus = doc.bt_Stripe__Status__c;
            this.PaymentStatus = doc.bt_stripe__Payment_Status__c;
        }
    }
    
    public class OrderItem {
        public String OrderID { get; set; }
        public Integer OrderLine { get; set; }
        public String RegistrationAccount { get; set; }
        public String RegType { get; set; }
        public String ResourceCode { get; set; }
        public String ResourceType { get; set; }
        public String ItemDescription { get; set; }
        public String ItemStatus { get; set; }
        public Decimal Quantity { get; set; }
        public Decimal UnitCharge { get; set; }
        public Decimal ItemTax { get; set; }
        public String Entered { get; set; }
        public String Updated { get; set; }
        
        public OrderItem() {}
        
        public OrderItem(bt_stripe__Line_Item__c item) {
            if (item.bt_stripe__Sales_Document__r != null && item.bt_stripe__Sales_Document__r.Name != null && item.bt_stripe__Sales_Document__r.Name.contains('-')) {
                String[] nameParts = item.bt_stripe__Sales_Document__r.Name.split('-');
                if (nameParts.size() > 1) {
                    this.OrderID = nameParts[1];
                } else {
                    this.OrderID = item.bt_stripe__Sales_Document__r.Name;
                }
            } else if (item.bt_stripe__Sales_Document__r != null) {
                this.OrderID = item.bt_stripe__Sales_Document__r.Name;
            } else {
                this.OrderID = '';
            }
            
            if (item.bt_stripe__Sort_Order__c != null) {
                this.OrderLine = Integer.valueOf(item.bt_stripe__Sort_Order__c);
            } else {
                this.OrderLine = 1;
            }
            
            if (item.conference360__Attendee__r != null && 
                item.conference360__Attendee__r.conference360__Account__r != null) {
                this.RegistrationAccount = item.conference360__Attendee__r.conference360__Account__r.Computed_ID__c;
            } else {
                this.RegistrationAccount = '';
            }
            this.ResourceCode = item.conference360__Event_Item__r.conference360__Product__r.ProductCode;
            this.ResourceType = item.conference360__Event_Item__r.conference360__Product__r.Product_Code_Base__c;
            
            this.ItemDescription = item.bt_stripe__Item_Name__c;
            this.ItemStatus = (item.Line_Item_Status__c == 'Active') ? 'O' : 'X';
            System.debug('ItemStatus: ' + this.ItemStatus);
            this.Quantity = item.bt_stripe__Quantity__c != null ? item.bt_stripe__Quantity__c : 1;
            this.UnitCharge = item.bt_stripe__List_Price__c != null ? item.bt_stripe__List_Price__c : 0;
            this.ItemTax = item.bt_stripe__Tax_Amount__c != null ? item.bt_stripe__Tax_Amount__c : 0;
            this.Entered = item.createdDate != null ? item.createdDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
            this.Updated = item.LastModifiedDate != null ? item.LastModifiedDate.format('yyyy-MM-dd\'T\'HH:mm:ss') : null;
        }
    }
    
    public class CsisRegistrant {
        public String RegAccountCode { get; set; }
        public String ExternalCode { get; set; }
        public String FirstName { get; set; }
        public String LastName { get; set; }
        public String Title { get; set; }
        public String CompanyName { get; set; }
        public String AddressLine1 { get; set; }
        public String City { get; set; }
        public String StateCode { get; set; }
        public String PostalCode { get; set; }
        public String CountryCode { get; set; }
        public String EmailAddress { get; set; }
        public String MainPhone { get; set; }
        public String MainFax { get; set; }
        public String RegSeq { get; set; }
        public String EventId { get; set; }
        public String Credentials { get; set; }
        public String L3 { get; set; }
        public String RegistrationStatus { get; set; }
        
        public CsisRegistrant() {}
        
        public CsisRegistrant(conference360__Attendee__c attendee) {
            // CSISIntegrationModels.setRegistrationStatus(attendee.conference360__Registration_Status__c);
            // this.RegistrationStatus = (attendee.conference360__Registration_Status__c == 'Registered') ? 'A' : 'X';
            if (attendee.conference360__Account__r != null) {
                this.RegAccountCode = attendee.conference360__Account__r.Computed_ID__c;
                this.ExternalCode = attendee.conference360__Account__r.Computed_ID__c;
                this.CompanyName = attendee.conference360__Account__r.Name;
            } else {
                this.RegAccountCode = '';
                this.ExternalCode = '';
                this.CompanyName = '';
            }
            
            this.FirstName = attendee.conference360__First_Name2__c;
            this.LastName = attendee.conference360__Last_Name2__c;
            this.Title = attendee.conference360__Title__c;
            
            this.AddressLine1 = attendee.conference360__Street__c;
            this.City = attendee.conference360__City__c;
            this.StateCode = attendee.conference360__State__c;
            this.PostalCode = attendee.conference360__Postal_Code__c;
            this.CountryCode = attendee.conference360__Country__c;
            this.EmailAddress = attendee.conference360__Email2__c;
            this.MainPhone = attendee.conference360__Phone2__c;
            this.RegistrationStatus = (attendee.conference360__Registration_Status__c == 'Registered') ? 'A' : 'X';
            
            if (attendee.conference360__Contact__r != null) {
                this.MainFax = attendee.conference360__Contact__r.Fax;
            }
            
            this.RegSeq = attendee.Computed_ID__c;
            
            this.EventId = attendee.conference360__Event__r.Event_ID__c;
            
            this.L3 = attendee.conference360__Event__r != null && attendee.conference360__Event__r.L3__c ? 'YES' : 'NO';
        }
    }
    @TestVisible
    private static String getStatusCode(String status) {
        if (status == null) return '30';
        if (status == 'Canceled') return '40';
        else if (status == 'Closed') return '45';
        else if (status == 'Completed') return '50';
        else if (status == 'On Hold') return '35';
        else if (status == 'Pending') return '28';
        else if (status == 'Request/Enquiry') return '10';
        else if (status == 'Active') return '30';
        else return '30';
    }

    @TestVisible
    private static String checkCancelled_SubstituteRegStatus(String regstatus, String itemstatus) {
        if (regstatus == 'Cancelled - Substitute' && itemstatus == 'Active') return 'A';
        else if (regstatus == 'Cancelled' && itemstatus == 'Canceled') return 'X';
        else if (regstatus == 'Registered') return 'A';
        return 'A'; // Default to active
    }

}