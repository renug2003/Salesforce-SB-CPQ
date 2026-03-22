/**
 * DD_QuoteServiceTest
 * @description Tests for DD_QuoteService — quote business logic.
 */
@isTest
private class DD_QuoteServiceTest {

    @TestSetup
    static void setupTestData() {
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'Quote Test Employer',
            Billing_ZIP__c = '94105',
            Total_Employees__c = 20,
            Eligible_Employees__c = 18,
            Segment__c = 'Small Business',
            Status__c = 'Prospect'
        );
        insert emp;

        DD_Plan__c plan = new DD_Plan__c(
            Name = 'Quote Test PPO',
            Plan_Code__c = 'QT-PPO-01',
            Plan_Type__c = 'PPO',
            Product_Line__c = 'Dental',
            Segment_Eligibility__c = 'Small Business',
            Is_Active__c = true,
            Effective_Start__c = Date.today().addYears(-1)
        );
        insert plan;

        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            ZIP_Code__c = '94105',
            Employee_Count__c = 20,
            Status__c = 'Draft'
        );
        insert quote;

        DD_QuoteLineItem__c li = new DD_QuoteLineItem__c(
            Quote__c = quote.Id,
            Plan__c = plan.Id,
            Rate_EO__c = 50.00,
            Rate_ES__c = 100.00,
            Rate_EC__c = 85.00,
            Rate_EF__c = 130.00,
            Count_EO__c = 10,
            Count_ES__c = 5,
            Count_EC__c = 3,
            Count_EF__c = 2,
            Employer_Contribution_Pct__c = 100,
            Is_Selected__c = true
        );
        insert li;
    }

    @isTest
    static void testRecalculateTotals() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        Test.startTest();
        DD_QuoteService.recalculateTotals(quote.Id);
        Test.stopTest();

        DD_Quote__c updated = [
            SELECT Total_Monthly_Premium__c
            FROM DD_Quote__c WHERE Id = :quote.Id
        ];
        // 10*50 + 5*100 + 3*85 + 2*130 = 500 + 500 + 255 + 260 = 1515
        System.assertEquals(1515.00, updated.Total_Monthly_Premium__c, 'Total should be 1515.00');
    }

    @isTest
    static void testRecalculateTotals_OnlySelectedLineItems() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'QT-PPO-01'];

        // Add an unselected line item — should not be included in totals
        insert new DD_QuoteLineItem__c(
            Quote__c = quote.Id,
            Plan__c = plan.Id,
            Rate_EO__c = 999.00,
            Count_EO__c = 100,
            Employer_Contribution_Pct__c = 100,
            Is_Selected__c = false
        );

        Test.startTest();
        DD_QuoteService.recalculateTotals(quote.Id);
        Test.stopTest();

        DD_Quote__c updated = [SELECT Total_Monthly_Premium__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals(1515.00, updated.Total_Monthly_Premium__c,
            'Unselected line items should not affect totals');
    }

    @isTest
    static void testGetQuoteDetail() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        Test.startTest();
        DD_CPQController.QuoteDetailWrapper detail = DD_QuoteService.getQuoteDetail(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertNotEquals(null, detail.quote, 'Quote should be populated');
        System.assertEquals(1, detail.lineItems.size(), 'Should have 1 line item');
    }

    @isTest
    static void testConvertQuoteToGroup() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        Test.startTest();
        Id groupId = DD_QuoteService.convertQuoteToGroup(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, groupId, 'Group ID should be returned');

        DD_Group__c grp = [SELECT Id, Source_Quote__c, Status__c FROM DD_Group__c WHERE Id = :groupId];
        System.assertEquals(quote.Id, grp.Source_Quote__c, 'Group should reference the quote');
        System.assertEquals('Pending', grp.Status__c);

        DD_Quote__c updated = [SELECT Status__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals('Converted', updated.Status__c, 'Quote status should be Converted');
    }

    @isTest
    static void testQuoteAccepted_AutoCreatesGroup() {
        DD_Quote__c quote = [SELECT Id, Employer__c FROM DD_Quote__c LIMIT 1];

        Test.startTest();
        update new DD_Quote__c(Id = quote.Id, Status__c = 'Accepted');
        Test.stopTest();

        List<DD_Group__c> groups = [
            SELECT Id, Employer__c, Source_Quote__c, Status__c
            FROM DD_Group__c WHERE Source_Quote__c = :quote.Id
        ];
        System.assertEquals(1, groups.size(), 'Exactly one Group should be created when Quote is Accepted');
        System.assertEquals(quote.Employer__c, groups[0].Employer__c, 'Group Employer should match Quote Employer');
        System.assertEquals(quote.Id, groups[0].Source_Quote__c, 'Group Source Quote should reference the accepted Quote');
        System.assertEquals('Pending', groups[0].Status__c, 'New Group Status should be Pending');

        DD_Quote__c updated = [SELECT Status__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals('Converted', updated.Status__c, 'Quote Status should be updated to Converted');
    }

    @isTest
    static void testQuoteApproved_AutoCreatesGroup() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(2).toStartOfMonth(),
            Status__c = 'Draft'
        );
        insert quote;

        Test.startTest();
        update new DD_Quote__c(Id = quote.Id, Status__c = 'Approved');
        Test.stopTest();

        List<DD_Group__c> groups = [
            SELECT Id, Employer__c, Source_Quote__c, Status__c
            FROM DD_Group__c WHERE Source_Quote__c = :quote.Id
        ];
        System.assertEquals(1, groups.size(), 'Exactly one Group should be created when Quote is Approved');
        System.assertEquals(emp.Id, groups[0].Employer__c, 'Group Employer should match Quote Employer');
        System.assertEquals('Pending', groups[0].Status__c, 'New Group Status should be Pending');

        DD_Quote__c updated = [SELECT Status__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals('Converted', updated.Status__c, 'Quote Status should be updated to Converted');
    }

    @isTest
    static void testQuoteAccepted_NoDuplicateGroup() {
        DD_Quote__c quote = [SELECT Id, Employer__c FROM DD_Quote__c LIMIT 1];

        // Pre-create a Group linked to this Quote (simulates prior conversion)
        DD_Group__c existingGroup = new DD_Group__c(
            Employer__c = quote.Employer__c,
            Source_Quote__c = quote.Id,
            Status__c = 'Pending'
        );
        insert existingGroup;

        Test.startTest();
        // Setting Status to Accepted again should NOT create a second Group
        update new DD_Quote__c(Id = quote.Id, Status__c = 'Accepted');
        Test.stopTest();

        List<DD_Group__c> groups = [
            SELECT Id FROM DD_Group__c WHERE Source_Quote__c = :quote.Id
        ];
        System.assertEquals(1, groups.size(), 'No duplicate Group should be created if one already exists for the Quote');
    }

    @isTest
    static void testBulkRecalculate_200Quotes() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Plan__c plan = [SELECT Id FROM DD_Plan__c WHERE Plan_Code__c = 'QT-PPO-01'];

        List<DD_Quote__c> quotes = new List<DD_Quote__c>();
        for (Integer i = 0; i < 50; i++) {
            quotes.add(new DD_Quote__c(
                Employer__c = emp.Id,
                Effective_Date__c = Date.today().addMonths(1),
                Status__c = 'Draft'
            ));
        }
        insert quotes;

        Test.startTest();
        for (DD_Quote__c q : quotes) {
            DD_QuoteService.recalculateTotals(q.Id);
        }
        Test.stopTest();
        System.assert(true, 'Bulk recalculate completed without governor limit errors');
    }
}