/**
 * DD_QuoteService
 * @description Business logic for Quote operations including totals recalculation,
 *              detail retrieval, and quote-to-group conversion.
 */
public with sharing class DD_QuoteService {

    /**
     * @description Recalculates and updates total premium fields on a Quote.
     *              Called after any line item change.
     */
    public static void recalculateTotals(Id quoteId) {
        List<DD_QuoteLineItem__c> lineItems = [
            SELECT Monthly_Subtotal__c, Employer_Monthly_Cost__c,
                   Employee_Monthly_Cost__c, Is_Selected__c
            FROM DD_QuoteLineItem__c
            WHERE Quote__c = :quoteId
              AND Is_Selected__c = true
            WITH SECURITY_ENFORCED
        ];

        Decimal totalMonthly = 0;
        Decimal employerMonthly = 0;
        Decimal employeeMonthly = 0;

        for (DD_QuoteLineItem__c li : lineItems) {
            totalMonthly += li.Monthly_Subtotal__c != null ? li.Monthly_Subtotal__c : 0;
            employerMonthly += li.Employer_Monthly_Cost__c != null ? li.Employer_Monthly_Cost__c : 0;
            employeeMonthly += li.Employee_Monthly_Cost__c != null ? li.Employee_Monthly_Cost__c : 0;
        }

        update new DD_Quote__c(
            Id = quoteId,
            Total_Monthly_Premium__c = totalMonthly,
            Employer_Monthly_Total__c = employerMonthly,
            Employee_Monthly_Total__c = employeeMonthly
        );
    }

    /**
     * @description Returns full quote detail including employer, line items, and plan info.
     */
    public static DD_CPQController.QuoteDetailWrapper getQuoteDetail(Id quoteId) {
        DD_Quote__c quote = [
            SELECT Id, Name, Status__c, Quote_Type__c, Effective_Date__c,
                   Quote_Expiration_Date__c, ZIP_Code__c, Rate_Territory__c,
                   Total_Monthly_Premium__c, Total_Annual_Premium__c,
                   Employer_Monthly_Total__c, Employee_Monthly_Total__c,
                   Employee_Count__c, Notes__c, Plans_Selected__c,
                   Employer__r.Name, Employer__r.Billing_ZIP__c,
                   Employer__r.Total_Employees__c, Employer__r.SIC_Code__c,
                   Broker__r.Name, Broker__r.Email
            FROM DD_Quote__c
            WHERE Id = :quoteId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        List<DD_QuoteLineItem__c> lineItems = [
            SELECT Id, Plan__c, Plan_Name__c, Plan_Type__c,
                   Rate_EO__c, Rate_ES__c, Rate_EC__c, Rate_EF__c,
                   Count_EO__c, Count_ES__c, Count_EC__c, Count_EF__c,
                   Monthly_Subtotal__c, Employer_Contribution_Pct__c,
                   Employer_Monthly_Cost__c, Employee_Monthly_Cost__c,
                   Is_Selected__c,
                   Plan__r.Network__c, Plan__r.Product_Line__c,
                   Plan__r.Deductible_Individual__c, Plan__r.Annual_Maximum__c,
                   Plan__r.Coinsurance_Preventive__c, Plan__r.Coinsurance_Basic__c,
                   Plan__r.Coinsurance_Major__c
            FROM DD_QuoteLineItem__c
            WHERE Quote__c = :quoteId
            WITH SECURITY_ENFORCED
            ORDER BY Plan_Type__c, Plan_Name__c
        ];

        DD_CPQController.QuoteDetailWrapper wrapper = new DD_CPQController.QuoteDetailWrapper();
        wrapper.quote = quote;
        wrapper.lineItems = lineItems;
        wrapper.totalMonthlyPremium = quote.Total_Monthly_Premium__c;
        wrapper.totalAnnualPremium = quote.Total_Annual_Premium__c;
        wrapper.employerMonthlyTotal = quote.Employer_Monthly_Total__c;
        wrapper.employeeMonthlyTotal = quote.Employee_Monthly_Total__c;
        return wrapper;
    }

    /**
     * @description Converts an accepted quote to a DD_Group__c record.
     */
    public static Id convertQuoteToGroup(Id quoteId) {
        DD_Quote__c quote = [
            SELECT Id, Employer__c, Effective_Date__c, Employee_Count__c,
                   Total_Monthly_Premium__c
            FROM DD_Quote__c
            WHERE Id = :quoteId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        DD_Group__c grp = new DD_Group__c(
            Employer__c = quote.Employer__c,
            Source_Quote__c = quoteId,
            Effective_Date__c = quote.Effective_Date__c,
            Renewal_Date__c = quote.Effective_Date__c.addYears(1),
            Status__c = 'Pending'
        );
        insert grp;

        // Update quote status
        update new DD_Quote__c(Id = quoteId, Status__c = 'Converted');

        return grp.Id;
    }
}
