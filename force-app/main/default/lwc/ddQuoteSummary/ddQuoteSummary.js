import { LightningElement, api } from 'lwc';
export default class DdQuoteSummary extends LightningElement {
    @api totalMonthly = 0;
    @api employerMonthly = 0;
    @api employeeMonthly = 0;
    @api plans = [];
}
