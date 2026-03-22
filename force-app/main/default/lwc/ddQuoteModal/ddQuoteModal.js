import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';

export default class DdQuoteModal extends LightningModal {
    @api employerId;
    @track resolvedEmployerId;

    connectedCallback() {
        // Primary: use the prop passed via open() if available
        // Fallback: read from sessionStorage (set by ddQuoteAction when launched from Employer page)
        this.resolvedEmployerId = this.employerId || sessionStorage.getItem('ddcpq_employer_id') || null;
    }

    handleQuoteCreated(event) {
        this.close({ quoteId: event.detail.quoteId });
    }

    handleCancel() {
        this.close(null);
    }
}
