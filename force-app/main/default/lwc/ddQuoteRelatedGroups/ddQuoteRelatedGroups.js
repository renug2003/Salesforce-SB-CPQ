import { LightningElement, api, wire } from 'lwc';
import getGroupsForQuote from '@salesforce/apex/DD_CPQController.getGroupsForQuote';
import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    {
        label: 'Group Number',
        fieldName: 'groupUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_self' },
        sortable: true
    },
    { label: 'Employer', fieldName: 'employerName', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true },
    { label: 'Effective Date', fieldName: 'Effective_Date__c', type: 'date', sortable: true },
    { label: 'Renewal Date', fieldName: 'Renewal_Date__c', type: 'date', sortable: true },
    { label: 'Total Enrolled', fieldName: 'Total_Enrolled__c', type: 'number', sortable: true }
];

export default class DdQuoteRelatedGroups extends NavigationMixin(LightningElement) {
    @api recordId;

    groups = [];
    columns = COLUMNS;
    isLoading = true;
    error;

    @wire(getGroupsForQuote, { quoteId: '$recordId' })
    wiredGroups({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.groups = data.map(g => ({
                ...g,
                groupUrl: '/' + g.Id,
                employerName: g.Employer__r ? g.Employer__r.Name : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'An error occurred loading groups.';
            this.groups = [];
        }
    }

    get hasGroups() {
        return this.groups && this.groups.length > 0;
    }
}
