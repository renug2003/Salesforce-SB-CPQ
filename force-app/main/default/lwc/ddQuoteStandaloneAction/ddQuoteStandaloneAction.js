import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import DdQuoteModal from 'c/ddQuoteModal';

export default class DdQuoteStandaloneAction extends NavigationMixin(LightningElement) {
    @api recordId; // Quote record ID (ignored — not passed as employerId)

    connectedCallback() {
        DdQuoteModal.open({
            size: 'large',
            label: 'New Quote'
            // No employerId — user will search or create an employer in the wizard
        }).then(result => {
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
