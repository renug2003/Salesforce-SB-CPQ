import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createGroupFromQuote from '@salesforce/apex/DD_CPQController.createGroupFromQuote';

export default class DdGroupManager extends LightningElement {
    @api quoteId;
    @api employer = {};
    @track group = { Group_Name__c: '', Effective_Date__c: '', Billing_Day__c: 1, Billing_Method__c: 'List Bill', Total_Enrolled__c: 0 };
    @track isLoading = false;
    @track isSaving = false;

    get isListBill() { return this.group.Billing_Method__c === 'List Bill'; }
    get isSelfBill() { return this.group.Billing_Method__c === 'Self Bill'; }

    connectedCallback() {
        if (this.employer) {
            this.group = { ...this.group, Group_Name__c: this.employer.Name || '', SIC_Code__c: this.employer.SIC_Code__c || '' };
        }
    }

    handleFieldChange(e) {
        this.group = { ...this.group, [e.target.dataset.field]: e.target.value };
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const groupId = await createGroupFromQuote({ quoteId: this.quoteId });
            this.dispatchEvent(new ShowToastEvent({ title: 'Group Created', message: 'Group record created successfully.', variant: 'success' }));
            this.dispatchEvent(new CustomEvent('groupcreated', { detail: { groupId } }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: e?.body?.message || 'Failed to create group.', variant: 'error' }));
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }
}
