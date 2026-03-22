import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';

export default class DdBrandedHeader extends NavigationMixin(LightningElement) {
    @api activePage = 'quotes';

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    currentUser;

    get currentUserName() {
        return getFieldValue(this.currentUser.data, NAME_FIELD) || 'User';
    }

    get navItems() {
        const pages = [
            { label: 'New Quote', page: 'new-quote' },
            { label: 'Quotes', page: 'quotes' },
            { label: 'Employers', page: 'employers' },
            { label: 'Plans', page: 'plans' },
            { label: 'Contracts', page: 'contracts' }
        ];
        return pages.map(p => ({
            ...p,
            cssClass: `dd-nav-item${p.page === this.activePage ? ' dd-nav-active' : ''}`
        }));
    }

    handleNavClick(event) {
        event.preventDefault();
        const page = event.currentTarget.dataset.page;
        this.dispatchEvent(new CustomEvent('navigate', { detail: { page } }));
    }
}
