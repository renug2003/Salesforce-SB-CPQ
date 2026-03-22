/**
 * DD_ContractService
 * @description Contract lifecycle operations — create, sign, terminate, and renew contracts.
 */
public with sharing class DD_ContractService {

    /**
     * @description Creates a contract from a group record.
     */
    public static Id createFromGroup(Id groupId) {
        DD_Group__c grp = [
            SELECT Id, Employer__c, Source_Quote__c, Effective_Date__c, Renewal_Date__c
            FROM DD_Group__c
            WHERE Id = :groupId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Decimal annualPremium = 0;
        if (grp.Source_Quote__c != null) {
            List<DD_Quote__c> quotes = [
                SELECT Total_Annual_Premium__c
                FROM DD_Quote__c
                WHERE Id = :grp.Source_Quote__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (!quotes.isEmpty() && quotes[0].Total_Annual_Premium__c != null) {
                annualPremium = quotes[0].Total_Annual_Premium__c;
            }
        }

        DD_Contract__c contract = new DD_Contract__c(
            Employer__c = grp.Employer__c,
            Group__c = groupId,
            Quote__c = grp.Source_Quote__c,
            Start_Date__c = grp.Effective_Date__c,
            End_Date__c = grp.Renewal_Date__c != null
                ? grp.Renewal_Date__c.addDays(-1)
                : grp.Effective_Date__c.addYears(1).addDays(-1),
            Status__c = 'Draft',
            Total_Annual_Premium__c = annualPremium,
            Auto_Renew__c = true
        );
        insert contract;
        return contract.Id;
    }

    /**
     * @description Marks a contract as signed and transitions to Approved via flow.
     */
    public static void signContract(Id contractId, Date signedDate, String signerName, String signerTitle) {
        if (signedDate == null || signedDate > Date.today()) {
            throw new DD_CPQException('Signed date must be today or in the past.');
        }
        if (String.isBlank(signerName)) {
            throw new DD_CPQException('Signer name is required.');
        }

        update new DD_Contract__c(
            Id = contractId,
            Is_Signed__c = true,
            Signed_Date__c = signedDate,
            Signed_By_Name__c = signerName,
            Signed_By_Title__c = signerTitle
        );
    }

    /**
     * @description Terminates an active contract early.
     */
    public static void terminateContract(Id contractId, Date terminationDate, String reason) {
        DD_Contract__c contract = [
            SELECT Id, Status__c, Start_Date__c
            FROM DD_Contract__c
            WHERE Id = :contractId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (contract.Status__c != 'Active' && contract.Status__c != 'Approved') {
            throw new DD_CPQException(
                'Only Active or Approved contracts can be terminated. Current status: ' + contract.Status__c
            );
        }
        if (terminationDate < contract.Start_Date__c) {
            throw new DD_CPQException('Termination date cannot be before contract start date.');
        }

        update new DD_Contract__c(
            Id = contractId,
            Status__c = 'Terminated',
            Termination_Date__c = terminationDate,
            Termination_Reason__c = reason
        );
    }

    /**
     * @description Returns full contract details for display.
     */
    @AuraEnabled(cacheable=true)
    public static DD_Contract__c getContractDetail(Id contractId) {
        List<DD_Contract__c> contracts = [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c,
                   Is_Signed__c, Signed_Date__c, Signed_By_Name__c, Signed_By_Title__c,
                   Auto_Renew__c, Total_Annual_Premium__c, Notes__c,
                   Termination_Date__c, Termination_Reason__c,
                   Days_Until_Expiration__c,
                   Employer__r.Name, Employer__r.Billing_ZIP__c,
                   Group__r.Name, Quote__r.Name
            FROM DD_Contract__c
            WHERE Id = :contractId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (contracts.isEmpty()) {
            throw new DD_CPQException('Contract not found: ' + contractId);
        }
        return contracts[0];
    }
}
