/**
 * DD_RateServiceTest
 * @description Tests for DD_RateService — rate table lookups.
 */
@isTest
private class DD_RateServiceTest {

    @TestSetup
    static void setupTestData() {
        DD_Plan__c plan = new DD_Plan__c(
            Name = 'Rate Test PPO',
            Plan_Code__c = 'RATE-TEST-01',
            Plan_Type__c = 'PPO',
            Product_Line__c = 'Dental',
            Network__c = 'Delta PPO',
            Deductible_Individual__c = 50,
            Annual_Maximum__c = 1500,
            Coinsurance_Preventive__c = 100,
            Coinsurance_Basic__c = 80,
            Coinsurance_Major__c = 50,
            Segment_Eligibility__c = 'Small Business',
            Is_Active__c = true,
            Effective_Start__c = Date.today().addYears(-1)
        );
        insert plan;

        // Territory-specific rates (SF_BAY) — one record per tier
        List<DD_PlanRate__c> sfRates = new List<DD_PlanRate__c>{
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'SF_BAY',
                Rating_Tier__c = 'EO', Monthly_Rate__c = 55.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'SF_BAY',
                Rating_Tier__c = 'ES', Monthly_Rate__c = 110.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'SF_BAY',
                Rating_Tier__c = 'EC', Monthly_Rate__c = 95.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'SF_BAY',
                Rating_Tier__c = 'EF', Monthly_Rate__c = 145.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99)
        };
        insert sfRates;

        // DEFAULT territory rates — fallback
        List<DD_PlanRate__c> defaultRates = new List<DD_PlanRate__c>{
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'DEFAULT',
                Rating_Tier__c = 'EO', Monthly_Rate__c = 45.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'DEFAULT',
                Rating_Tier__c = 'ES', Monthly_Rate__c = 90.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'DEFAULT',
                Rating_Tier__c = 'EC', Monthly_Rate__c = 80.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99),
            new DD_PlanRate__c(Plan__c = plan.Id, Rate_Territory__c = 'DEFAULT',
                Rating_Tier__c = 'EF', Monthly_Rate__c = 125.00,
                Effective_Date__c = Date.today().addYears(-1),
                Group_Size_Min__c = 2, Group_Size_Max__c = 99)
        };
        insert defaultRates;
    }

    @isTest
    static void testGetRateWrapper_TerritorySpecific() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'RATE-TEST-01'];
        Test.startTest();
        DD_CPQController.RateWrapper rate = DD_RateService.getRateWrapper(
            plan.Id, 'SF_BAY', 15, Date.today()
        );
        Test.stopTest();
        System.assertEquals(true, rate.rateFound, 'Rate should be found');
        System.assertEquals(55.00, rate.rateEO, 'EO rate should match SF_BAY territory');
        System.assertEquals(110.00, rate.rateES, 'ES rate should match SF_BAY territory');
    }

    @isTest
    static void testGetRateWrapper_FallsBackToDefault() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'RATE-TEST-01'];
        Test.startTest();
        DD_CPQController.RateWrapper rate = DD_RateService.getRateWrapper(
            plan.Id, 'UNKNOWN_TERRITORY', 15, Date.today()
        );
        Test.stopTest();
        System.assertEquals(true, rate.rateFound, 'Should fall back to DEFAULT rate');
        System.assertEquals(45.00, rate.rateEO, 'Should use DEFAULT EO rate');
    }

    @isTest
    static void testGetRateWrapper_NoRateFound() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'RATE-TEST-01'];
        Test.startTest();
        DD_CPQController.RateWrapper rate = DD_RateService.getRateWrapper(
            plan.Id, 'DEFAULT', 15, Date.today().addYears(-5)
        );
        Test.stopTest();
        System.assertEquals(false, rate.rateFound, 'No rate found for past effective date');
    }

    @isTest
    static void testGetRatesForPlans_BulkLookup() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'RATE-TEST-01'];
        Set<Id> planIds = new Set<Id>{ plan.Id };
        Test.startTest();
        Map<Id, DD_CPQController.RateWrapper> rateMap = DD_RateService.getRatesForPlans(
            planIds, 'SF_BAY', 15, Date.today()
        );
        Test.stopTest();
        System.assertEquals(1, rateMap.size(), 'Should return rate for 1 plan');
        System.assertEquals(true, rateMap.get(plan.Id).rateFound, 'Rate should be found');
        System.assertEquals(55.00, rateMap.get(plan.Id).rateEO, 'EO should be 55.00');
    }

    @isTest
    static void testBulkRateLookup_200Plans() {
        List<DD_Plan__c> plans = new List<DD_Plan__c>();
        for (Integer i = 0; i < 50; i++) {
            plans.add(new DD_Plan__c(
                Name = 'Bulk Plan ' + i,
                Plan_Code__c = 'BULK-' + i,
                Plan_Type__c = 'PPO',
                Product_Line__c = 'Dental',
                Segment_Eligibility__c = 'Small Business',
                Is_Active__c = true,
                Effective_Start__c = Date.today().addYears(-1)
            ));
        }
        insert plans;

        List<DD_PlanRate__c> rates = new List<DD_PlanRate__c>();
        for (DD_Plan__c p : plans) {
            for (String tier : new List<String>{ 'EO', 'ES', 'EC', 'EF' }) {
                rates.add(new DD_PlanRate__c(
                    Plan__c = p.Id,
                    Rate_Territory__c = 'DEFAULT',
                    Rating_Tier__c = tier,
                    Monthly_Rate__c = 40.00,
                    Effective_Date__c = Date.today().addYears(-1),
                    Group_Size_Min__c = 2,
                    Group_Size_Max__c = 99
                ));
            }
        }
        insert rates;

        Set<Id> planIds = new Map<Id, DD_Plan__c>(plans).keySet();
        Test.startTest();
        Map<Id, DD_CPQController.RateWrapper> rateMap = DD_RateService.getRatesForPlans(
            planIds, 'DEFAULT', 15, Date.today()
        );
        Test.stopTest();
        System.assertEquals(50, rateMap.size(), 'Should return rates for all 50 plans');
    }
}
