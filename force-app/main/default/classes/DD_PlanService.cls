/**
 * DD_PlanService
 * @description Plan catalog queries — retrieves active plans filtered by segment,
 *              product line, and effective date.
 */
public with sharing class DD_PlanService {

    /**
     * @description Returns active Small Business plans filtered by product line and effective date.
     */
    public static List<DD_Plan__c> getActivePlans(String productLine, Date effectiveDate) {
        List<DD_Plan__c> plans = [
            SELECT Id, Name, Plan_Code__c, Plan_Type__c, Product_Line__c,
                   Network__c, Deductible_Individual__c, Deductible_Family__c,
                   Annual_Maximum__c, Ortho_Lifetime_Max__c, Ortho_Covered__c,
                   Waiting_Period__c, Coinsurance_Preventive__c, Coinsurance_Basic__c,
                   Coinsurance_Major__c, Coinsurance_Ortho__c,
                   Highlights__c, Sort_Order__c, Segment_Eligibility__c,
                   Effective_Start__c, Effective_End__c
            FROM DD_Plan__c
            WHERE Is_Active__c = true
              AND (Effective_End__c = null OR Effective_End__c >= :effectiveDate)
              AND (Effective_Start__c = null OR Effective_Start__c <= :effectiveDate)
              AND Segment_Eligibility__c INCLUDES ('Small Business')
            WITH SECURITY_ENFORCED
            ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC
        ];
        // Filter by product line in Apex (bind variable on left-hand side not allowed in SOQL)
        if (productLine != 'All') {
            List<DD_Plan__c> filtered = new List<DD_Plan__c>();
            for (DD_Plan__c p : plans) {
                if (p.Product_Line__c == productLine) filtered.add(p);
            }
            return filtered;
        }
        return plans;
    }

    /**
     * @description Returns a single plan with all benefit details.
     */
    public static DD_Plan__c getPlanWithBenefits(Id planId) {
        List<DD_Plan__c> plans = [
            SELECT Id, Name, Plan_Code__c, Plan_Type__c, Product_Line__c,
                   Network__c, Deductible_Individual__c, Deductible_Family__c,
                   Annual_Maximum__c, Ortho_Lifetime_Max__c, Ortho_Covered__c,
                   Waiting_Period__c, Coinsurance_Preventive__c, Coinsurance_Basic__c,
                   Coinsurance_Major__c, Coinsurance_Ortho__c,
                   Highlights__c, Sort_Order__c, Segment_Eligibility__c,
                   (SELECT Id, Name, Benefit_Category__c,
                           In_Network_Coinsurance__c, Out_Network_Coinsurance__c,
                           Frequency__c, Notes__c, Sort_Order__c
                    FROM Plan_Benefits__r
                    ORDER BY Benefit_Category__c, Sort_Order__c ASC NULLS LAST)
            FROM DD_Plan__c
            WHERE Id = :planId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (plans.isEmpty()) {
            throw new DD_CPQException('Plan not found: ' + planId);
        }
        return plans[0];
    }

    /**
     * @description Returns plan IDs for a given product line — used for bulk rate lookups.
     */
    public static Set<Id> getActivePlanIds(String productLine, Date effectiveDate) {
        List<DD_Plan__c> plans = getActivePlans(productLine, effectiveDate);
        Set<Id> ids = new Set<Id>();
        for (DD_Plan__c p : plans) {
            ids.add(p.Id);
        }
        return ids;
    }
}
