import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createContractFromGroup from '@salesforce/apex/DD_CPQController.createContractFromGroup';

export default class DdCreateContractAction extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isCreating = false;
    @track isDone = false;
    @track hasError = false;
    @track errorMessage = '';

    contractId;

    async handleCreate() {
        this.isCreating = true;
        this.hasError = false;
        try {
            this.contractId = await createContractFromGroup({ groupId: this.recordId });
            this.isDone = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Contract Created',
                message: 'The contract record and PDF have been created successfully.',
                variant: 'success'
            }));
        } catch (error) {
            this.hasError = true;
            this.errorMessage = error?.body?.message || error?.message || 'An unexpected error occurred.';
        } finally {
            this.isCreating = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleViewContract() {
        this.dispatchEvent(new CloseActionScreenEvent());
        if (this.contractId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.contractId,
                    actionName: 'view'
                }
            });
        }
    }
}
