/**
 * DD_CPQControllerTest
 * @description Test class for DD_CPQController. Minimum 85% coverage required.
 */
@isTest
private class DD_CPQControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test employer
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'Test Employer Co',
            Billing_ZIP__c = '94105',
            Total_Employees__c = 15,
            Eligible_Employees__c = 12,
            Segment__c = 'Small Business',
            Status__c = 'Prospect',
            Requested_Effective_Date__c = Date.today().addMonths(1).toStartOfMonth()
        );
        insert emp;

        // Create test plan
        DD_Plan__c plan = new DD_Plan__c(
            Name = 'Test PPO Plan',
            Plan_Code__c = 'TEST-PPO-01',
            Plan_Type__c = 'PPO',
            Product_Line__c = 'Dental',
            Network__c = 'Delta PPO',
            Deductible_Individual__c = 50,
            Deductible_Family__c = 150,
            Annual_Maximum__c = 1500,
            Coinsurance_Preventive__c = 100,
            Coinsurance_Basic__c = 80,
            Coinsurance_Major__c = 50,
            Segment_Eligibility__c = 'Small Business',
            Is_Active__c = true,
            Effective_Start__c = Date.today().addMonths(-1),
            Sort_Order__c = 1
        );
        insert plan;

        // Create test rate
        DD_PlanRate__c rate = new DD_PlanRate__c(
            Plan__c = plan.Id,
            Rate_Territory__c = 'DEFAULT',
            Rating_Tier__c = 'EO',
            Monthly_Rate__c = 38.75,
            Effective_Date__c = Date.today().addMonths(-1),
            Group_Size_Min__c = 2,
            Group_Size_Max__c = 99
        );
        insert rate;
    }

    @isTest
    static void testGetAvailablePlans_Dental() {
        Date effectiveDate = Date.today().addMonths(1).toStartOfMonth();
        Test.startTest();
        List<DD_CPQController.PlanWrapper> plans = DD_CPQController.getAvailablePlans(
            'Dental', '15', effectiveDate
        );
        Test.stopTest();
        System.assertNotEquals(null, plans, 'Plans should not be null');
        System.assert(plans.size() > 0, 'Should return at least one dental plan');
        System.assertEquals('Dental', plans[0].productLine, 'Should be dental plans');
    }

    @isTest
    static void testGetAvailablePlans_AllProductLines() {
        Date effectiveDate = Date.today().addMonths(1).toStartOfMonth();
        Test.startTest();
        List<DD_CPQController.PlanWrapper> plans = DD_CPQController.getAvailablePlans(
            'All', '15', effectiveDate
        );
        Test.stopTest();
        System.assertNotEquals(null, plans);
    }

    @isTest
    static void testGetRatesForPlan() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'TEST-PPO-01' LIMIT 1];
        Date effectiveDate = Date.today().addMonths(1).toStartOfMonth();
        Test.startTest();
        DD_CPQController.RateWrapper rate = DD_CPQController.getRatesForPlan(
            plan.Id, '94105', 15, effectiveDate
        );
        Test.stopTest();
        System.assertNotEquals(null, rate, 'Rate wrapper should not be null');
    }

    @isTest
    static void testSaveEmployer_Valid() {
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'New Test Employer',
            Billing_ZIP__c = '90001',
            Total_Employees__c = 25,
            Segment__c = 'Small Business'
        );
        Test.startTest();
        Id empId = DD_CPQController.saveEmployer(JSON.serialize(emp));
        Test.stopTest();
        System.assertNotEquals(null, empId, 'Employer ID should be returned');
    }

    @isTest
    static void testSaveEmployer_InvalidSize() {
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'Too Large Corp',
            Billing_ZIP__c = '94105',
            Total_Employees__c = 150,
            Segment__c = 'Small Business'
        );
        Test.startTest();
        try {
            DD_CPQController.saveEmployer(JSON.serialize(emp));
            System.assert(false, 'Should have thrown exception for >99 employees');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'Exception thrown as expected for employee count out of range');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAndGetQuote() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c LIMIT 1];

        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            ZIP_Code__c = '94105',
            Employee_Count__c = 15
        );

        List<DD_QuoteLineItem__c> lineItems = new List<DD_QuoteLineItem__c>{
            new DD_QuoteLineItem__c(
                Plan__c = plan.Id,
                Rate_EO__c = 38.75,
                Count_EO__c = 10,
                Employer_Contribution_Pct__c = 100,
                Is_Selected__c = true
            )
        };

        Test.startTest();
        Id quoteId = DD_CPQController.createQuote(
            JSON.serialize(quote),
            JSON.serialize(lineItems)
        );
        Test.stopTest();

        System.assertNotEquals(null, quoteId);

        // Verify totals were recalculated
        DD_Quote__c savedQuote = [
            SELECT Total_Monthly_Premium__c FROM DD_Quote__c WHERE Id = :quoteId
        ];
        System.assertEquals(387.50, savedQuote.Total_Monthly_Premium__c);
    }

    @isTest
    static void testContractSigningFlow() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];

        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            End_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Pending Signature'
        );
        insert contract;

        Test.startTest();
        DD_CPQController.signContract(
            contract.Id,
            Date.today(),
            'Jane Smith',
            'CFO'
        );
        Test.stopTest();

        DD_Contract__c signed = [
            SELECT Is_Signed__c, Signed_By_Name__c, Status__c
            FROM DD_Contract__c WHERE Id = :contract.Id
        ];
        System.assertEquals(true, signed.Is_Signed__c);
        System.assertEquals('Jane Smith', signed.Signed_By_Name__c);
    }

    @isTest
    static void testContractTrigger_PreventBackdating() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addDays(30),
            End_Date__c = Date.today().addDays(395)
        );
        insert contract;

        Test.startTest();
        try {
            contract.Is_Signed__c = true;
            contract.Signed_Date__c = Date.today().addDays(10); // future date
            update contract;
            System.assert(false, 'Should have thrown error for future signed date');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('future'), 'Error should mention future date');
        }
        Test.stopTest();
    }

    @isTest
    static void testTerritoryService() {
        Test.startTest();
        String territory = DD_CPQController.getTerritoryForZIP('94105');
        Test.stopTest();
        System.assertNotEquals(null, territory);
    }

    @isTest
    static void testGetPlanBenefits() {
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c LIMIT 1];

        DD_PlanBenefit__c benefit = new DD_PlanBenefit__c(
            Plan__c = plan.Id,
            Benefit_Category__c = 'Preventive',
            Name = 'Oral Exam',
            In_Network_Coinsurance__c = 100,
            Out_Network_Coinsurance__c = 90,
            Sort_Order__c = 1
        );
        insert benefit;

        Test.startTest();
        List<DD_PlanBenefit__c> benefits = DD_CPQController.getPlanBenefits(plan.Id);
        Test.stopTest();

        System.assert(benefits.size() > 0, 'Should return plan benefits');
        System.assertEquals('Preventive', benefits[0].Benefit_Category__c);
    }

    @isTest
    static void testQuoteService_RecalculateTotals() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c LIMIT 1];

        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            Status__c = 'Draft'
        );
        insert quote;

        DD_QuoteLineItem__c li = new DD_QuoteLineItem__c(
            Quote__c = quote.Id,
            Plan__c = plan.Id,
            Rate_EO__c = 50.00,
            Count_EO__c = 5,
            Employer_Contribution_Pct__c = 75,
            Is_Selected__c = true
        );
        insert li;

        Test.startTest();
        DD_QuoteService.recalculateTotals(quote.Id);
        Test.stopTest();

        DD_Quote__c updated = [SELECT Total_Monthly_Premium__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals(250.00, updated.Total_Monthly_Premium__c);
    }
}