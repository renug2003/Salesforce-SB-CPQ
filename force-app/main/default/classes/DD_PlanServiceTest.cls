/**
 * DD_PlanServiceTest
 * @description Tests for DD_PlanService — plan catalog queries.
 */
@isTest
private class DD_PlanServiceTest {

    @TestSetup
    static void setupTestData() {
        List<DD_Plan__c> plans = new List<DD_Plan__c>{
            new DD_Plan__c(
                Name = 'PPO Basic',
                Plan_Code__c = 'PPO-BASIC',
                Plan_Type__c = 'PPO',
                Product_Line__c = 'Dental',
                Network__c = 'Delta PPO',
                Deductible_Individual__c = 50,
                Annual_Maximum__c = 1000,
                Coinsurance_Preventive__c = 100,
                Coinsurance_Basic__c = 80,
                Coinsurance_Major__c = 50,
                Segment_Eligibility__c = 'Small Business',
                Is_Active__c = true,
                Effective_Start__c = Date.today().addYears(-1),
                Sort_Order__c = 1
            ),
            new DD_Plan__c(
                Name = 'DHMO Value',
                Plan_Code__c = 'DHMO-VAL',
                Plan_Type__c = 'HMO',
                Product_Line__c = 'Dental',
                Network__c = 'DeltaCare',
                Deductible_Individual__c = 0,
                Annual_Maximum__c = 2000,
                Coinsurance_Preventive__c = 100,
                Coinsurance_Basic__c = 90,
                Coinsurance_Major__c = 60,
                Segment_Eligibility__c = 'Small Business',
                Is_Active__c = true,
                Effective_Start__c = Date.today().addYears(-1),
                Sort_Order__c = 2
            ),
            new DD_Plan__c(
                Name = 'Expired Plan',
                Plan_Code__c = 'EXPIRED-01',
                Plan_Type__c = 'PPO',
                Product_Line__c = 'Dental',
                Segment_Eligibility__c = 'Small Business',
                Is_Active__c = true,
                Effective_Start__c = Date.today().addYears(-2),
                Effective_End__c = Date.today().addYears(-1)
            )
        };
        insert plans;
    }

    @isTest
    static void testGetActivePlans_Dental() {
        Test.startTest();
        List<DD_Plan__c> plans = DD_PlanService.getActivePlans('Dental', Date.today());
        Test.stopTest();
        System.assert(plans.size() >= 2, 'Should return at least 2 active dental plans');
        for (DD_Plan__c p : plans) {
            System.assertEquals('Dental', p.Product_Line__c);
        }
    }

    @isTest
    static void testGetActivePlans_All() {
        Test.startTest();
        List<DD_Plan__c> plans = DD_PlanService.getActivePlans('All', Date.today());
        Test.stopTest();
        System.assert(plans.size() >= 2, 'Should return all active plans');
    }

    @isTest
    static void testGetActivePlans_ExcludesExpired() {
        Test.startTest();
        List<DD_Plan__c> plans = DD_PlanService.getActivePlans('All', Date.today());
        Test.stopTest();
        for (DD_Plan__c p : plans) {
            System.assert(
                p.Effective_End__c == null || p.Effective_End__c >= Date.today(),
                'Expired plans should be excluded'
            );
        }
    }

    @isTest
    static void testGetPlanWithBenefits() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'PPO-BASIC' LIMIT 1];

        DD_PlanBenefit__c benefit = new DD_PlanBenefit__c(
            Plan__c = plan.Id,
            Benefit_Category__c = 'Preventive',
            Name = 'Oral Exam',
            In_Network_Coinsurance__c = 100,
            Out_Network_Coinsurance__c = 80,
            Sort_Order__c = 1
        );
        insert benefit;

        Test.startTest();
        DD_Plan__c result = DD_PlanService.getPlanWithBenefits(plan.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Plan should be returned');
        System.assertEquals('PPO-BASIC', result.Plan_Code__c);
        System.assertEquals(1, result.Plan_Benefits__r.size(), 'Should include 1 benefit');
    }

    @isTest
    static void testGetPlanWithBenefits_NotFound() {
        Test.startTest();
        try {
            DD_PlanService.getPlanWithBenefits('001000000000000AAA');
            System.assert(false, 'Should have thrown DD_CPQException');
        } catch (DD_CPQException e) {
            System.assert(e.getMessage().contains('not found'), 'Error message should say not found');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActivePlanIds() {
        Test.startTest();
        Set<Id> ids = DD_PlanService.getActivePlanIds('Dental', Date.today());
        Test.stopTest();
        System.assert(ids.size() >= 2, 'Should return at least 2 plan IDs');
    }
}