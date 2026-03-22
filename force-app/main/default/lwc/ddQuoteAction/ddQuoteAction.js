import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import DdQuoteModal from 'c/ddQuoteModal';

export default class DdQuoteAction extends NavigationMixin(LightningElement) {
    @api recordId;
    _modalOpened = false;

    // renderedCallback is used instead of connectedCallback because
    // Salesforce sets @api recordId AFTER connectedCallback for Quick Actions.
    // renderedCallback guarantees all @api properties are available.
    renderedCallback() {
        if (this._modalOpened) return;
        this._modalOpened = true;

        // Store employer ID in sessionStorage so ddQuoteWizard can read it reliably.
        // LightningModal.open() property passing is unreliable for @api props.
        if (this.recordId) {
            sessionStorage.setItem('ddcpq_employer_id', this.recordId);
        } else {
            sessionStorage.removeItem('ddcpq_employer_id');
        }

        DdQuoteModal.open({
            size: 'large',
            label: 'New Quote'
        }).then(result => {
            sessionStorage.removeItem('ddcpq_employer_id');
            if (result?.quoteId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.quoteId,
                        actionName: 'view'
                    }
                });
            }
            this.dispatchEvent(new CloseActionScreenEvent());
        });
    }
}
