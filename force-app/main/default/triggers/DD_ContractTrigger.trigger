/**
 * DD_ContractTrigger
 * @description Validates contract signing rules and prevents backdating.
 */
trigger DD_ContractTrigger on DD_Contract__c (before insert, before update) {
    for (DD_Contract__c contract : Trigger.new) {

        // Validate: Signed Date required when Is_Signed = true
        if (contract.Is_Signed__c == true && contract.Signed_Date__c == null) {
            contract.Signed_Date__c.addError(
                'Date Signed is required when marking the contract as signed.'
            );
        }

        // Validate: Signed Date cannot be in the future
        if (contract.Signed_Date__c != null && contract.Signed_Date__c > Date.today()) {
            contract.Signed_Date__c.addError(
                'Date Signed cannot be in the future.'
            );
        }

        // Validate: End Date must be after Start Date
        if (contract.Start_Date__c != null && contract.End_Date__c != null) {
            if (contract.End_Date__c <= contract.Start_Date__c) {
                contract.End_Date__c.addError(
                    'Contract End Date must be after the Start Date.'
                );
            }
        }

        // Prevent status regression (e.g., Active → Draft)
        if (Trigger.isUpdate) {
            DD_Contract__c oldContract = Trigger.oldMap.get(contract.Id);
            if (oldContract.Status__c == 'Active' && contract.Status__c == 'Draft') {
                contract.Status__c.addError(
                    'Cannot revert an Active contract to Draft. Use Terminated status instead.'
                );
            }
            if (oldContract.Status__c == 'Expired' && contract.Status__c == 'Draft') {
                contract.Status__c.addError(
                    'Cannot revert an Expired contract to Draft.'
                );
            }
        }
    }
}
