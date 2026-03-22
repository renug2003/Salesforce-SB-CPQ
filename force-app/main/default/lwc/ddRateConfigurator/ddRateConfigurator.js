import { LightningElement, api, track } from 'lwc';
export default class DdRateConfigurator extends LightningElement {
    @api plans = [];
    @api employerContributionPct = 100;
}
