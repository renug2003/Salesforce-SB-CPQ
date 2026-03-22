/**
 * DD_ProposalPDFController
 * @description Controller for the DD_ProposalPDF Visualforce page used to generate proposal PDFs.
 */
public without sharing class DD_ProposalPDFController {

    public DD_Quote__c quote { get; private set; }
    public List<DD_QuoteLineItem__c> lineItems { get; private set; }
    public String todayFormatted { get; private set; }
    public String expirationFormatted { get; private set; }

    public DD_ProposalPDFController() {
        Id quoteId = ApexPages.currentPage().getParameters().get('quoteId');
        todayFormatted = Date.today().format();
        if (quoteId != null) {
            loadData(quoteId);
        }
    }

    private void loadData(Id quoteId) {
        quote = [
            SELECT Id, Name,
                   Effective_Date__c, Quote_Expiration_Date__c, Status__c,
                   Employee_Count__c, ZIP_Code__c, Rate_Territory__c,
                   Total_Monthly_Premium__c, Total_Annual_Premium__c,
                   Employer_Monthly_Total__c, Employee_Monthly_Total__c,
                   Notes__c,
                   Employer__r.Name, Employer__r.Billing_ZIP__c,
                   Employer__r.Total_Employees__c, Employer__r.SIC_Code__c,
                   Employer__r.DBA_Name__c,
                   Broker_Account__r.Name, Broker_Account__r.Phone
            FROM DD_Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quote.Quote_Expiration_Date__c != null) {
            expirationFormatted = quote.Quote_Expiration_Date__c.format();
        }

        lineItems = [
            SELECT Id, Name,
                   Plan__r.Name, Plan__r.Plan_Type__c, Plan__r.Network__c,
                   Plan__r.Deductible_Individual__c, Plan__r.Deductible_Family__c,
                   Plan__r.Annual_Maximum__c, Plan__r.Ortho_Lifetime_Max__c,
                   Plan__r.Coinsurance_Preventive__c, Plan__r.Coinsurance_Basic__c,
                   Plan__r.Coinsurance_Major__c, Plan__r.Coinsurance_Ortho__c,
                   Plan__r.Waiting_Period__c, Plan__r.Ortho_Covered__c,
                   Rate_EO__c, Rate_ES__c, Rate_EC__c, Rate_EF__c,
                   Count_EO__c, Count_ES__c, Count_EC__c, Count_EF__c,
                   Monthly_Subtotal__c, Employer_Monthly_Cost__c, Employee_Monthly_Cost__c,
                   Employer_Contribution_Pct__c
            FROM DD_QuoteLineItem__c
            WHERE Quote__c = :quoteId
            ORDER BY Plan__r.Name ASC
        ];
    }
}
