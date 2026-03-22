import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateProposalPDF from '@salesforce/apex/DD_CPQController.generateProposalPDF';

export default class DdGenerateProposalAction extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isGenerating = false;
    @track isDone = false;
    @track hasError = false;
    @track errorMessage = '';

    async handleGenerate() {
        this.isGenerating = true;
        this.hasError = false;
        try {
            await generateProposalPDF({ quoteId: this.recordId });
            this.isDone = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Proposal PDF Created',
                message: 'The PDF has been saved to the Files section of this Quote record.',
                variant: 'success'
            }));
        } catch (error) {
            this.hasError = true;
            this.errorMessage = error?.body?.message || error?.message || 'An error occurred.';
        } finally {
            this.isGenerating = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleViewFiles() {
        // Close the action screen, then navigate to the Quote record
        // The Files related list on the record page will show the generated PDF
        this.dispatchEvent(new CloseActionScreenEvent());
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}
