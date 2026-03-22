/**
 * DD_ContractPDFController
 * @description Controller for the DD_ContractPDF Visualforce page used to generate contract PDFs.
 *              Runs without sharing to allow PDF generation service to read all required related records.
 */
/**
 * DD_ContractPDFController
 * @description Controller for the DD_ContractPDF Visualforce page.
 *              Accepts groupId as the URL parameter so the PDF can be rendered
 *              before the contract record is committed to the database — avoiding
 *              the "List has no rows" issue that occurs when passing a newly-inserted
 *              contractId to PageReference.getContent() in the same transaction.
 */
public without sharing class DD_ContractPDFController {

    public DD_Group__c grp { get; private set; }
    public List<DD_QuoteLineItem__c> lineItems { get; private set; }
    public String todayFormatted { get; private set; }
    public String effectiveDateFormatted { get; private set; }
    public String endDateFormatted { get; private set; }
    public Boolean hasLineItems { get; private set; }
    public Boolean hasBroker { get; private set; }
    public Decimal totalAnnualPremium { get; private set; }

    public DD_ContractPDFController() {
        Id groupId = ApexPages.currentPage().getParameters().get('groupId');
        todayFormatted = Date.today().format();
        lineItems = new List<DD_QuoteLineItem__c>();
        hasLineItems = false;
        hasBroker = false;
        totalAnnualPremium = 0;
        if (groupId != null) {
            loadData(groupId);
        }
    }

    private void loadData(Id groupId) {
        grp = [
            SELECT Id, Name, Group_Name__c, Status__c,
                   Effective_Date__c, Renewal_Date__c,
                   Total_Enrolled__c, SIC_Code__c,
                   Billing_Method__c, Billing_Day__c, Notes__c,
                   Employer__r.Name, Employer__r.DBA_Name__c,
                   Employer__r.Billing_ZIP__c, Employer__r.SIC_Code__c,
                   Employer__r.Total_Employees__c,
                   Source_Quote__c,
                   Source_Quote__r.Name, Source_Quote__r.ZIP_Code__c,
                   Source_Quote__r.Rate_Territory__c, Source_Quote__r.Employee_Count__c,
                   Source_Quote__r.Total_Annual_Premium__c,
                   Source_Quote__r.Broker_Account__r.Name,
                   Source_Quote__r.Broker_Account__r.Phone
            FROM DD_Group__c
            WHERE Id = :groupId
            LIMIT 1
        ];

        if (grp.Effective_Date__c != null) {
            effectiveDateFormatted = grp.Effective_Date__c.format();
        }
        Date endDate = grp.Renewal_Date__c != null
            ? grp.Renewal_Date__c.addDays(-1)
            : (grp.Effective_Date__c != null ? grp.Effective_Date__c.addYears(1).addDays(-1) : null);
        if (endDate != null) {
            endDateFormatted = endDate.format();
        }

        if (grp.Source_Quote__c != null) {
            if (grp.Source_Quote__r.Broker_Account__r != null
                && String.isNotBlank(grp.Source_Quote__r.Broker_Account__r.Name)) {
                hasBroker = true;
            }
            if (grp.Source_Quote__r.Total_Annual_Premium__c != null) {
                totalAnnualPremium = grp.Source_Quote__r.Total_Annual_Premium__c;
            }
            lineItems = [
                SELECT Id, Plan__r.Name, Plan__r.Plan_Type__c, Plan__r.Network__c,
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
                WHERE Quote__c = :grp.Source_Quote__c
                ORDER BY Plan__r.Name ASC
            ];
            hasLineItems = !lineItems.isEmpty();
        }
    }
}
