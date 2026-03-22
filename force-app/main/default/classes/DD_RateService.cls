/**
 * DD_RateService
 * @description Looks up plan rates from DD_PlanRate__c (one record per tier) and
 *              assembles a RateWrapper containing all four coverage tier rates.
 */
public with sharing class DD_RateService {

    public static DD_CPQController.RateWrapper getRateWrapper(
        Id planId,
        String territory,
        Integer groupSize,
        Date effectiveDate
    ) {
        DD_CPQController.RateWrapper wrapper = new DD_CPQController.RateWrapper();
        wrapper.territory = territory;
        wrapper.rateFound = false;

        List<String> territories = (territory != 'DEFAULT')
            ? new List<String>{ territory, 'DEFAULT' }
            : new List<String>{ 'DEFAULT' };

        List<DD_PlanRate__c> rates = [
            SELECT Rating_Tier__c, Monthly_Rate__c, Rate_Territory__c
            FROM DD_PlanRate__c
            WHERE Plan__c = :planId
              AND Rate_Territory__c IN :territories
              AND (Group_Size_Min__c = null OR Group_Size_Min__c <= :groupSize)
              AND (Group_Size_Max__c = null OR Group_Size_Max__c >= :groupSize)
              AND (Effective_Date__c = null OR Effective_Date__c <= :effectiveDate)
              AND (Expiration_Date__c = null OR Expiration_Date__c >= :effectiveDate)
            WITH SECURITY_ENFORCED
            ORDER BY Rate_Territory__c DESC NULLS LAST, Effective_Date__c DESC NULLS LAST
        ];

        // Territory-specific rates take precedence over DEFAULT
        Map<String, Decimal> tierRates = new Map<String, Decimal>();
        for (DD_PlanRate__c r : rates) {
            if (!tierRates.containsKey(r.Rating_Tier__c) || r.Rate_Territory__c == territory) {
                tierRates.put(r.Rating_Tier__c, r.Monthly_Rate__c);
            }
        }

        if (!tierRates.isEmpty()) {
            wrapper.rateEO = tierRates.get('EO');
            wrapper.rateES = tierRates.get('ES');
            wrapper.rateEC = tierRates.get('EC');
            wrapper.rateEF = tierRates.get('EF');
            wrapper.rateFound = true;
        }

        return wrapper;
    }

    /**
     * @description Bulk rate lookup for multiple plans — used during quote creation.
     */
    public static Map<Id, DD_CPQController.RateWrapper> getRatesForPlans(
        Set<Id> planIds,
        String territory,
        Integer groupSize,
        Date effectiveDate
    ) {
        Map<Id, DD_CPQController.RateWrapper> resultMap = new Map<Id, DD_CPQController.RateWrapper>();

        List<String> territories = (territory != 'DEFAULT')
            ? new List<String>{ territory, 'DEFAULT' }
            : new List<String>{ 'DEFAULT' };

        List<DD_PlanRate__c> rates = [
            SELECT Plan__c, Rating_Tier__c, Monthly_Rate__c, Rate_Territory__c
            FROM DD_PlanRate__c
            WHERE Plan__c IN :planIds
              AND Rate_Territory__c IN :territories
              AND (Group_Size_Min__c = null OR Group_Size_Min__c <= :groupSize)
              AND (Group_Size_Max__c = null OR Group_Size_Max__c >= :groupSize)
              AND (Effective_Date__c = null OR Effective_Date__c <= :effectiveDate)
              AND (Expiration_Date__c = null OR Expiration_Date__c >= :effectiveDate)
            WITH SECURITY_ENFORCED
            ORDER BY Rate_Territory__c DESC NULLS LAST, Effective_Date__c DESC NULLS LAST
        ];

        // Build per-plan tier rate maps; territory-specific wins over DEFAULT
        Map<Id, Map<String, Decimal>> planTierMap = new Map<Id, Map<String, Decimal>>();
        for (DD_PlanRate__c r : rates) {
            if (!planTierMap.containsKey(r.Plan__c)) {
                planTierMap.put(r.Plan__c, new Map<String, Decimal>());
            }
            Map<String, Decimal> tierRates = planTierMap.get(r.Plan__c);
            if (!tierRates.containsKey(r.Rating_Tier__c) || r.Rate_Territory__c == territory) {
                tierRates.put(r.Rating_Tier__c, r.Monthly_Rate__c);
            }
        }

        for (Id planId : planTierMap.keySet()) {
            Map<String, Decimal> tierRates = planTierMap.get(planId);
            DD_CPQController.RateWrapper w = new DD_CPQController.RateWrapper();
            w.rateEO = tierRates.get('EO');
            w.rateES = tierRates.get('ES');
            w.rateEC = tierRates.get('EC');
            w.rateEF = tierRates.get('EF');
            w.territory = territory;
            w.rateFound = true;
            resultMap.put(planId, w);
        }

        return resultMap;
    }
}
