import { LightningElement, api, track } from 'lwc';

export default class DdProposalViewer extends LightningElement {
    @api proposalData = {};

    get todayDisplay() {
        return new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
    }

    @api
    printProposal() {
        window.print();
    }
}
