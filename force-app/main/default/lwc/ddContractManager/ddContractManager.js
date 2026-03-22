import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import signContract from '@salesforce/apex/DD_CPQController.signContract';

const CONTRACT_FIELDS = [
    'DD_Contract__c.Id',
    'DD_Contract__c.Name',
    'DD_Contract__c.Status__c',
    'DD_Contract__c.Start_Date__c',
    'DD_Contract__c.End_Date__c',
    'DD_Contract__c.Is_Signed__c',
    'DD_Contract__c.Signed_Date__c',
    'DD_Contract__c.Signed_By_Name__c',
    'DD_Contract__c.Signed_By_Title__c',
    'DD_Contract__c.Total_Annual_Premium__c',
    'DD_Contract__c.Auto_Renew__c',
    'DD_Contract__c.Employer__r.Name'
];

const STATUS_ORDER = ['Draft','Pending Signature','Approved','Active','Expired'];

export default class DdContractManager extends LightningElement {
    @api recordId;
    @track showSignModal = false;
    @track isLoading = false;
    @track signerName = '';
    @track signerTitle = '';
    @track signedDate = new Date().toISOString().substring(0, 10);

    _wiredResult;

    @wire(getRecord, { recordId: '$recordId', fields: CONTRACT_FIELDS })
    wiredContract(result) {
        this._wiredResult = result;
    }

    get contract() {
        return this._wiredResult?.data?.fields ? {
            Id: this._wiredResult.data.fields.Id?.value,
            Name: this._wiredResult.data.fields.Name?.value,
            Status__c: this._wiredResult.data.fields.Status__c?.value,
            Start_Date__c: this._wiredResult.data.fields.Start_Date__c?.value,
            End_Date__c: this._wiredResult.data.fields.End_Date__c?.value,
            Is_Signed__c: this._wiredResult.data.fields.Is_Signed__c?.value,
            Signed_Date__c: this._wiredResult.data.fields.Signed_Date__c?.value,
            Signed_By_Name__c: this._wiredResult.data.fields.Signed_By_Name__c?.value,
            Signed_By_Title__c: this._wiredResult.data.fields.Signed_By_Title__c?.value,
            Total_Annual_Premium__c: this._wiredResult.data.fields.Total_Annual_Premium__c?.value,
            Auto_Renew__c: this._wiredResult.data.fields.Auto_Renew__c?.value,
            Employer__r: { Name: this._wiredResult.data.fields['Employer__r']?.value?.fields?.Name?.value }
        } : null;
    }

    get canSign() {
        return this.contract && !this.contract.Is_Signed__c
            && ['Draft','Pending Signature'].includes(this.contract.Status__c);
    }

    get canTerminate() {
        return this.contract && this.contract.Status__c === 'Active';
    }

    get statusBadgeClass() {
        const s = this.contract?.Status__c || '';
        const map = { 'Active': 'ddcm-badge ddcm-badge-active',
                      'Approved': 'ddcm-badge ddcm-badge-approved',
                      'Expired': 'ddcm-badge ddcm-badge-expired',
                      'Draft': 'ddcm-badge ddcm-badge-draft' };
        return map[s] || 'ddcm-badge ddcm-badge-draft';
    }

    get startDateDisplay() {
        return this.formatDate(this.contract?.Start_Date__c);
    }
    get endDateDisplay() {
        return this.formatDate(this.contract?.End_Date__c);
    }
    get signedDateDisplay() {
        return this.formatDate(this.contract?.Signed_Date__c);
    }
    get todayISO() {
        return new Date().toISOString().substring(0, 10);
    }
    get signFormInvalid() {
        return !this.signerName || !this.signerTitle || !this.signedDate;
    }

    getTimelineStep(step) {
        const currentIdx = STATUS_ORDER.indexOf(this.contract?.Status__c || 'Draft');
        const stepIdx = STATUS_ORDER.indexOf(step);
        let css = 'ddcm-tl-step';
        if (stepIdx < currentIdx) css += ' ddcm-tl-done';
        if (stepIdx === currentIdx) css += ' ddcm-tl-current';
        return css;
    }
    get timelineStepDraft() { return this.getTimelineStep('Draft'); }
    get timelineStepPendingSignature() { return this.getTimelineStep('Pending Signature'); }
    get timelineStepApproved() { return this.getTimelineStep('Approved'); }
    get timelineStepActive() { return this.getTimelineStep('Active'); }
    get timelineStepExpired() { return this.getTimelineStep('Expired'); }

    formatDate(val) {
        if (!val) return '—';
        return new Date(val + 'T00:00:00').toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    openSignModal() { this.showSignModal = true; }
    closeSignModal() { this.showSignModal = false; }
    stopPropagation(e) { e.stopPropagation(); }

    handleSignerNameChange(e) { this.signerName = e.target.value; }
    handleSignerTitleChange(e) { this.signerTitle = e.target.value; }
    handleSignedDateChange(e) { this.signedDate = e.target.value; }

    async handleConfirmSign() {
        this.isLoading = true;
        try {
            await signContract({
                contractId: this.recordId,
                signedDate: this.signedDate,
                signerName: this.signerName,
                signerTitle: this.signerTitle
            });
            this.closeSignModal();
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Contract Signed',
                message: 'Contract has been signed and is now Approved.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message || 'Failed to sign contract.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}
