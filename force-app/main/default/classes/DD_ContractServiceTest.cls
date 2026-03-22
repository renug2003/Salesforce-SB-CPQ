/**
 * DD_ContractServiceTest
 * @description Tests for DD_ContractService — contract lifecycle.
 */
@isTest
private class DD_ContractServiceTest {

    @TestSetup
    static void setupTestData() {
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'Contract Test Employer',
            Billing_ZIP__c = '94105',
            Total_Employees__c = 15,
            Segment__c = 'Small Business',
            Status__c = 'Active'
        );
        insert emp;

        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            Status__c = 'Accepted'
        );
        insert quote;

        DD_Group__c grp = new DD_Group__c(
            Employer__c = emp.Id,
            Source_Quote__c = quote.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            Renewal_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Pending'
        );
        insert grp;
    }

    @isTest
    static void testCreateFromGroup() {
        DD_Group__c grp = [SELECT Id FROM DD_Group__c LIMIT 1];

        Test.startTest();
        Id contractId = DD_ContractService.createFromGroup(grp.Id);
        Test.stopTest();

        System.assertNotEquals(null, contractId, 'Contract ID should be returned');

        DD_Contract__c contract = [
            SELECT Id, Status__c, Group__c, Employer__c, Total_Annual_Premium__c
            FROM DD_Contract__c WHERE Id = :contractId
        ];
        System.assertEquals('Draft', contract.Status__c);
        System.assertEquals(grp.Id, contract.Group__c);
    }

    @isTest
    static void testSignContract_Valid() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            End_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Pending Signature'
        );
        insert contract;

        Test.startTest();
        DD_ContractService.signContract(contract.Id, Date.today(), 'John CEO', 'Chief Executive Officer');
        Test.stopTest();

        DD_Contract__c signed = [
            SELECT Is_Signed__c, Signed_Date__c, Signed_By_Name__c, Signed_By_Title__c
            FROM DD_Contract__c WHERE Id = :contract.Id
        ];
        System.assertEquals(true, signed.Is_Signed__c);
        System.assertEquals(Date.today(), signed.Signed_Date__c);
        System.assertEquals('John CEO', signed.Signed_By_Name__c);
        System.assertEquals('Chief Executive Officer', signed.Signed_By_Title__c);
    }

    @isTest
    static void testSignContract_FutureDate_ThrowsException() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            End_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Pending Signature'
        );
        insert contract;

        Test.startTest();
        try {
            DD_ContractService.signContract(contract.Id, Date.today().addDays(5), 'Jane', 'CFO');
            System.assert(false, 'Should throw exception for future signed date');
        } catch (DD_CPQException e) {
            System.assert(e.getMessage().contains('past'), 'Error should mention past date requirement');
        }
        Test.stopTest();
    }

    @isTest
    static void testSignContract_BlankSignerName_ThrowsException() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            End_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Pending Signature'
        );
        insert contract;

        Test.startTest();
        try {
            DD_ContractService.signContract(contract.Id, Date.today(), '', 'CEO');
            System.assert(false, 'Should throw exception for blank signer name');
        } catch (DD_CPQException e) {
            System.assert(e.getMessage().contains('Signer name'), 'Error should mention signer name');
        }
        Test.stopTest();
    }

    @isTest
    static void testTerminateContract_Active() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(-6),
            End_Date__c = Date.today().addMonths(6),
            Status__c = 'Active'
        );
        insert contract;

        Test.startTest();
        DD_ContractService.terminateContract(contract.Id, Date.today(), 'Voluntary Cancellation');
        Test.stopTest();

        DD_Contract__c terminated = [
            SELECT Status__c, Termination_Date__c, Termination_Reason__c
            FROM DD_Contract__c WHERE Id = :contract.Id
        ];
        System.assertEquals('Terminated', terminated.Status__c);
        System.assertEquals(Date.today(), terminated.Termination_Date__c);
        System.assertEquals('Voluntary Cancellation', terminated.Termination_Reason__c);
    }

    @isTest
    static void testTerminateContract_DraftStatus_ThrowsException() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1),
            End_Date__c = Date.today().addMonths(13),
            Status__c = 'Draft'
        );
        insert contract;

        Test.startTest();
        try {
            DD_ContractService.terminateContract(contract.Id, Date.today(), 'Non-Payment');
            System.assert(false, 'Should throw exception for Draft contract');
        } catch (DD_CPQException e) {
            System.assert(e.getMessage().contains('Active or Approved'), 'Error should mention allowed statuses');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetContractDetail() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = emp.Id,
            Start_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            End_Date__c = Date.today().addMonths(13).toStartOfMonth(),
            Status__c = 'Draft'
        );
        insert contract;

        Test.startTest();
        DD_Contract__c detail = DD_ContractService.getContractDetail(contract.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Contract detail should not be null');
        System.assertEquals('Draft', detail.Status__c);
        System.assertNotEquals(null, detail.Employer__r.Name, 'Employer name should be populated');
    }

    @isTest
    static void testContractTrigger_BulkValidation_200Records() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        List<DD_Contract__c> contracts = new List<DD_Contract__c>();
        for (Integer i = 0; i < 200; i++) {
            contracts.add(new DD_Contract__c(
                Employer__c = emp.Id,
                Start_Date__c = Date.today().addMonths(1),
                End_Date__c = Date.today().addMonths(13)
            ));
        }
        Test.startTest();
        insert contracts;
        Test.stopTest();
        System.assertEquals(200, contracts.size(), 'Bulk insert of 200 contracts should succeed');
    }
}
