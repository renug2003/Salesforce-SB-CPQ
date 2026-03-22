import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue, createRecord } from 'lightning/uiRecordApi';
import getAvailablePlans from '@salesforce/apex/DD_CPQController.getAvailablePlans';
import getRatesForPlan from '@salesforce/apex/DD_CPQController.getRatesForPlan';
import getTerritoryForZIP from '@salesforce/apex/DD_CPQController.getTerritoryForZIP';
import saveEmployer from '@salesforce/apex/DD_CPQController.saveEmployer';
import createQuote from '@salesforce/apex/DD_CPQController.createQuote';
import generateProposalPDF from '@salesforce/apex/DD_CPQController.generateProposalPDF';
import searchBrokerAccounts from '@salesforce/apex/DD_CPQController.searchBrokerAccounts';
import getPlanBenefits from '@salesforce/apex/DD_CPQController.getPlanBenefits';

const EMPLOYER_FIELDS = [
    'DD_Employer__c.Name',
    'DD_Employer__c.DBA_Name__c',
    'DD_Employer__c.Billing_ZIP__c',
    'DD_Employer__c.Total_Employees__c',
    'DD_Employer__c.Eligible_Employees__c',
    'DD_Employer__c.SIC_Code__c',
    'DD_Employer__c.Broker_Account__c',
    'DD_Employer__c.Status__c',
    'DD_Employer__c.Segment__c',
    'DD_Employer__c.Requested_Effective_Date__c'
];

const STEPS = [
    { id: 1, number: '1', label: 'Employer Info', completed: false },
    { id: 2, number: '2', label: 'Coverage Type', completed: false },
    { id: 3, number: '3', label: 'Select Plans', completed: false },
    { id: 4, number: '4', label: 'Configure Rates', completed: false },
    { id: 5, number: '5', label: 'Review & Quote', completed: false },
    { id: 6, number: '6', label: 'Proposal', completed: false }
];

export default class DdQuoteWizard extends NavigationMixin(LightningElement) {

    @api title = 'Small Business Quote Wizard';
    /** When set (e.g. from a Quick Action on an Employer record), pre-populate employer data */
    @api employerId;

    @track currentStep = 1;
    @track steps = STEPS.map(s => ({ ...s }));

    // Active employer ID from sessionStorage (set by ddQuoteAction when launched from Employer page)
    @track activeEmployerId;

    connectedCallback() {
        // If no employerId prop, check sessionStorage for context set by ddQuoteAction
        if (!this.employerId) {
            const sessionId = sessionStorage.getItem('ddcpq_employer_id');
            if (sessionId) {
                this.activeEmployerId = sessionId;
            }
        }
    }

    // Wire: load employer from @api prop (passed directly from parent)
    @wire(getRecord, { recordId: '$employerId', fields: EMPLOYER_FIELDS })
    wiredEmployer({ data }) {
        if (data) this._populateFromRecord(data);
    }

    // Wire: load employer from sessionStorage context (Quick Action on Employer page)
    @wire(getRecord, { recordId: '$activeEmployerId', fields: EMPLOYER_FIELDS })
    wiredActiveEmployer({ data }) {
        if (data) this._populateFromRecord(data);
    }

    // Wire: load employer when user searches and selects one in standalone mode
    @track searchedEmployerId;
    @wire(getRecord, { recordId: '$searchedEmployerId', fields: EMPLOYER_FIELDS })
    wiredSearchedEmployer({ data }) {
        if (data) this._populateFromRecord(data);
    }

    _populateFromRecord(data) {
        this.employer = {
            Name: getFieldValue(data, 'DD_Employer__c.Name') || '',
            DBA_Name__c: getFieldValue(data, 'DD_Employer__c.DBA_Name__c') || '',
            Billing_ZIP__c: getFieldValue(data, 'DD_Employer__c.Billing_ZIP__c') || '',
            Total_Employees__c: getFieldValue(data, 'DD_Employer__c.Total_Employees__c'),
            Eligible_Employees__c: getFieldValue(data, 'DD_Employer__c.Eligible_Employees__c'),
            SIC_Code__c: getFieldValue(data, 'DD_Employer__c.SIC_Code__c') || '',
            Segment__c: getFieldValue(data, 'DD_Employer__c.Segment__c') || 'Small Business',
            Status__c: getFieldValue(data, 'DD_Employer__c.Status__c') || 'Prospect'
        };
        this.selectedBrokerId = getFieldValue(data, 'DD_Employer__c.Broker_Account__c') || null;
        const reqDate = getFieldValue(data, 'DD_Employer__c.Requested_Effective_Date__c');
        if (reqDate) this.effectiveDate = reqDate;
        if (this.employer.Billing_ZIP__c && this.employer.Billing_ZIP__c.length === 5) {
            getTerritoryForZIP({ zipCode: this.employer.Billing_ZIP__c })
                .then(t => { this.territoryDisplay = t; })
                .catch(() => { this.territoryDisplay = 'DEFAULT'; });
        }
    }

    // Employer form state
    @track employer = {
        Name: '',
        DBA_Name__c: '',
        Billing_ZIP__c: '',
        SIC_Code__c: '',
        Total_Employees__c: null,
        Eligible_Employees__c: null,
        Segment__c: 'Small Business',
        Status__c: 'Prospect'
    };
    @track selectedBrokerId;
    @track selectedBrokerName;
    @track effectiveDate;
    @track territoryDisplay;

    // Broker search (custom Apex-backed — avoids lightning-record-picker config error for Account)
    @track brokerSearchTerm = '';
    @track brokerSearchResults = [];
    @track showBrokerDropdown = false;
    _brokerSearchTimer;

    // Broker creation
    @track showNewBrokerForm = false;
    @track isSavingBroker = false;
    @track newBroker = { Name: '', Phone: '', brokerEmail: '', brokerLicense: '' };

    // Coverage type selection
    @track includeDental = true;
    @track includeVision = false;

    // Plans
    @track dentalPlans = [];
    @track visionPlans = [];
    @track isLoadingPlans = false;
    @track selectedPlanIds = new Set();
    @track planRatesMap = {};

    // Benefits panel
    @track showBenefitsPanel = false;
    @track benefitsPlanName = '';
    @track planBenefits = [];
    @track isLoadingBenefits = false;

    // Rate configuration
    @track employerContributionPct = 100;
    @track selectedPlansForRating = [];
    @track quoteNotes = '';

    // Quote totals
    @track totalMonthlyPremium = 0;
    @track employerMonthlyTotal = 0;
    @track employeeMonthlyTotal = 0;
    @track totalAnnualPremium = 0;

    // Saved state
    @track quoteId;
    @track quoteNumber;
    @track proposalId;

    // UI state
    @track isSaving = false;
    @track errorMessage;
    @track hasError = false;

    // ─── Computed Properties ────────────────────────────────────────────────────

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }

    get effectiveDateDisplay() {
        if (!this.effectiveDate) return 'TBD';
        return new Date(this.effectiveDate + 'T00:00:00').toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    get minEffectiveDate() {
        // Must be first of next month minimum
        const today = new Date();
        const firstOfNextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
        return firstOfNextMonth.toISOString().substring(0, 10);
    }

    get coverageTypeSelected() {
        return this.includeDental || this.includeVision;
    }

    get coverageTypeNotSelected() {
        return !this.coverageTypeSelected;
    }

    get noPlansSelected() {
        return this.selectedPlanIds.size === 0;
    }

    get dentalCardClass() {
        return `dd-coverage-card${this.includeDental ? ' dd-coverage-selected' : ''}`;
    }

    get visionCardClass() {
        return `dd-coverage-card${this.includeVision ? ' dd-coverage-selected' : ''}`;
    }

    get employeeContributionPct() {
        return 100 - this.employerContributionPct;
    }

    /** True when opened standalone (Quote page) — no employer context */
    get isStandalone() { return !this.employerId && !this.activeEmployerId; }

    /** True when employer is pre-loaded from an Employer record page — fields are read-only */
    get isEmployerLocked() { return !!(this.employerId || this.activeEmployerId); }

    /** True when an existing employer has been chosen via search in standalone mode */
    get hasSearchedEmployer() { return !!this.searchedEmployerId; }

    get noBrokerResults() { return this.brokerSearchResults.length === 0; }

    // ─── Employer Search (standalone mode) ──────────────────────────────────────

    handleExistingEmployerSelect(event) {
        // lightning-record-picker fires change with detail.value OR detail.recordId depending on version
        const selectedId = event.detail.value || event.detail.recordId || null;
        this.searchedEmployerId = selectedId;
        if (!selectedId) {
            // Cleared — reset form for new employer entry
            this.employer = {
                Name: '', DBA_Name__c: '', Billing_ZIP__c: '', SIC_Code__c: '',
                Total_Employees__c: null, Eligible_Employees__c: null,
                Segment__c: 'Small Business', Status__c: 'Prospect'
            };
            this.effectiveDate = null;
            this.territoryDisplay = null;
            this.selectedBrokerId = null;
        }
    }

    // ─── Step Navigation ────────────────────────────────────────────────────────

    handleStepClick(event) {
        const clickedStep = parseInt(event.currentTarget.dataset.step, 10);
        if (clickedStep < this.currentStep) {
            this.currentStep = clickedStep;
        }
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    updateStepStatus(completedStep) {
        this.steps = this.steps.map(s => ({
            ...s,
            completed: s.id <= completedStep,
            cssClass: this.getStepCss(s.id, completedStep)
        }));
    }

    getStepCss(stepId, completedStep) {
        let css = 'dd-step';
        if (stepId === this.currentStep + 1) css += ' dd-step-active';
        if (stepId <= completedStep) css += ' dd-step-completed';
        if (stepId > completedStep + 1) css += ' dd-step-future';
        return css;
    }

    // ─── Step 1: Employer Info ──────────────────────────────────────────────────

    handleEmployerFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        const fieldMap = {
            employerName: 'Name',
            dbaName: 'DBA_Name__c',
            taxId: 'Tax_ID__c',
            sic: 'SIC_Code__c',
            totalEmployees: 'Total_Employees__c',
            eligibleEmployees: 'Eligible_Employees__c'
        };
        if (fieldMap[field]) {
            this.employer = { ...this.employer, [fieldMap[field]]: value };
        }
    }

    handleZIPChange(event) {
        const zip = event.target.value;
        this.employer = { ...this.employer, Billing_ZIP__c: zip };
        if (zip && zip.length === 5) {
            getTerritoryForZIP({ zipCode: zip })
                .then(territory => {
                    this.territoryDisplay = territory;
                })
                .catch(() => {
                    this.territoryDisplay = 'DEFAULT';
                });
        }
    }

    handleEffectiveDateChange(event) {
        this.effectiveDate = event.target.value;
        // Validate first of month
        const d = new Date(this.effectiveDate + 'T00:00:00');
        if (d.getDate() !== 1) {
            this.showError('Effective date must be the first day of the month.');
        } else {
            this.clearError();
        }
    }

    handleBrokerChange(event) {
        this.selectedBrokerId = event.detail.value || event.detail.recordId || null;
        this.selectedBrokerName = event.detail.record?.fields?.Name?.value || null;
    }

    handleBrokerSearchInput(event) {
        const term = event.target.value;
        this.brokerSearchTerm = term;
        clearTimeout(this._brokerSearchTimer);
        if (!term || term.trim().length < 2) {
            this.brokerSearchResults = [];
            this.showBrokerDropdown = false;
            return;
        }
        // Debounce 300ms
        this._brokerSearchTimer = setTimeout(() => {
            searchBrokerAccounts({ searchTerm: term.trim() })
                .then(results => {
                    this.brokerSearchResults = results;
                    this.showBrokerDropdown = true;
                })
                .catch(() => {
                    this.brokerSearchResults = [];
                    this.showBrokerDropdown = true;
                });
        }, 300);
    }

    handleBrokerSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.selectedBrokerId = id;
        this.selectedBrokerName = name;
        this.brokerSearchTerm = name;
        this.showBrokerDropdown = false;
        this.brokerSearchResults = [];
    }

    handleBrokerClear() {
        this.selectedBrokerId = null;
        this.selectedBrokerName = null;
        this.brokerSearchTerm = '';
        this.showBrokerDropdown = false;
        this.brokerSearchResults = [];
    }

    handleShowNewBrokerForm() {
        this.showNewBrokerForm = true;
        this.newBroker = { Name: '', Phone: '', brokerEmail: '', brokerLicense: '' };
    }

    handleCancelNewBroker() {
        this.showNewBrokerForm = false;
    }

    handleNewBrokerFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        const fieldMap = {
            brokerName: 'Name',
            brokerPhone: 'Phone',
            brokerEmail: 'brokerEmail',
            brokerLicense: 'brokerLicense'
        };
        if (fieldMap[field]) {
            this.newBroker = { ...this.newBroker, [fieldMap[field]]: value };
        }
    }

    async handleSaveNewBroker() {
        if (!this.newBroker.Name || this.newBroker.Name.trim() === '') {
            this.showError('Broker agency name is required.');
            return;
        }
        this.isSavingBroker = true;
        try {
            const fields = { Name: this.newBroker.Name.trim(), Type: 'Producer' };
            if (this.newBroker.Phone) fields.Phone = this.newBroker.Phone;
            const descParts = [];
            if (this.newBroker.brokerEmail) descParts.push(`Email: ${this.newBroker.brokerEmail}`);
            if (this.newBroker.brokerLicense) descParts.push(`License: ${this.newBroker.brokerLicense}`);
            if (descParts.length > 0) fields.Description = descParts.join(' | ');
            const result = await createRecord({ apiName: 'Account', fields });
            this.selectedBrokerId = result.id;
            this.selectedBrokerName = this.newBroker.Name.trim();
            this.showNewBrokerForm = false;
            this.showToast('Broker Created', `${this.selectedBrokerName} added as a Producer account.`, 'success');
        } catch (error) {
            this.showError('Error creating broker: ' + this.extractError(error));
        } finally {
            this.isSavingBroker = false;
        }
    }

    async handleStep1Next() {
        try {
            if (this.employerId || this.activeEmployerId) {
                // Launched from Employer record page — always reuse the existing employer
                this._resolvedEmployerId = this.employerId || this.activeEmployerId;
            } else if (this.searchedEmployerId) {
                // User searched and selected an existing employer in standalone mode
                if (!this.effectiveDate) {
                    this.showError('Requested effective date is required.');
                    return;
                }
                this._resolvedEmployerId = this.searchedEmployerId;
            } else {
                // Creating a brand-new employer from the form
                if (!this.validateStep1()) return;
                if (!this._resolvedEmployerId) {
                    this.employer.Requested_Effective_Date__c = this.effectiveDate;
                    if (this.selectedBrokerId) this.employer.Broker_Account__c = this.selectedBrokerId;
                    const empId = await saveEmployer({ employerJSON: JSON.stringify(this.employer) });
                    this._resolvedEmployerId = empId;
                }
            }
            this.currentStep = 2;
            this.updateStepStatus(1);
        } catch (error) {
            this.showError(this.extractError(error));
        }
    }

    validateStep1() {
        if (!this.employer.Name || this.employer.Name.trim() === '') {
            this.showError('Employer name is required.');
            return false;
        }
        if (!this.employer.Billing_ZIP__c || this.employer.Billing_ZIP__c.length !== 5) {
            this.showError('Please enter a valid 5-digit ZIP code.');
            return false;
        }
        const empCount = parseInt(this.employer.Total_Employees__c, 10);
        if (!empCount || empCount < 2 || empCount > 99) {
            this.showError('Small Business segment requires 2–99 employees.');
            return false;
        }
        if (!this.effectiveDate) {
            this.showError('Requested effective date is required.');
            return false;
        }
        return true;
    }

    // ─── Step 2: Coverage Type ──────────────────────────────────────────────────

    toggleDental() {
        this.includeDental = !this.includeDental;
    }

    toggleVision() {
        this.includeVision = !this.includeVision;
    }

    handleStep2Next() {
        if (!this.coverageTypeSelected) return;
        this.currentStep = 3;
        this.updateStepStatus(2);
        this.loadPlans();
    }

    // ─── Step 3: Plan Selection ─────────────────────────────────────────────────

    async loadPlans() {
        this.isLoadingPlans = true;
        this.dentalPlans = [];
        this.visionPlans = [];

        try {
            const groupSize = String(this.employer.Total_Employees__c || 10);
            const effectiveDate = this.effectiveDate
                ? new Date(this.effectiveDate + 'T00:00:00').toISOString().substring(0, 10)
                : new Date().toISOString().substring(0, 10);

            const allPlans = await getAvailablePlans({
                productLine: 'All',
                groupSize: groupSize,
                effectiveDate: effectiveDate
            });

            // Fetch rates for all plans in parallel
            const ratePromises = allPlans.map(p =>
                getRatesForPlan({
                    planId: p.planId,
                    zipCode: this.employer.Billing_ZIP__c || '94105',
                    groupSize: parseInt(groupSize, 10),
                    effectiveDate: effectiveDate
                }).then(rate => ({ planId: p.planId, rate }))
                  .catch(() => ({ planId: p.planId, rate: null }))
            );

            const ratesArray = await Promise.all(ratePromises);
            ratesArray.forEach(r => {
                this.planRatesMap[r.planId] = r.rate;
            });

            const enrichPlan = plan => ({
                ...plan,
                selected: false,
                rate: this.planRatesMap[plan.planId] || null,
                cardClass: 'dd-plan-card',
                annualMaxDisplay: plan.annualMaximum ? `$${plan.annualMaximum.toLocaleString()}` : 'No Maximum'
            });

            if (this.includeDental) {
                this.dentalPlans = allPlans
                    .filter(p => p.productLine === 'Dental')
                    .map(enrichPlan);
            }
            if (this.includeVision) {
                this.visionPlans = allPlans
                    .filter(p => p.productLine === 'Vision')
                    .map(enrichPlan);
            }
        } catch (error) {
            this.showError('Error loading plans: ' + this.extractError(error));
        } finally {
            this.isLoadingPlans = false;
        }
    }

    handlePlanToggle(event) {
        const planId = event.currentTarget.dataset.planId;
        const updatePlanList = plans => plans.map(p => {
            if (p.planId === planId) {
                const selected = !p.selected;
                if (selected) {
                    this.selectedPlanIds.add(planId);
                } else {
                    this.selectedPlanIds.delete(planId);
                }
                return { ...p, selected, cardClass: selected ? 'dd-plan-card dd-plan-selected' : 'dd-plan-card' };
            }
            return p;
        });
        this.dentalPlans = updatePlanList(this.dentalPlans);
        this.visionPlans = updatePlanList(this.visionPlans);
    }

    handleViewBenefits(event) {
        event.stopPropagation();
        const planId = event.target.dataset.planId;
        const allPlans = [...this.dentalPlans, ...this.visionPlans];
        const plan = allPlans.find(p => p.planId === planId);
        this.benefitsPlanName = plan ? plan.planName : '';
        this.planBenefits = [];
        this.showBenefitsPanel = true;
        this.isLoadingBenefits = true;
        getPlanBenefits({ planId })
            .then(benefits => {
                this.planBenefits = benefits;
            })
            .catch(err => {
                this.showError('Error loading benefits: ' + this.extractError(err));
                this.showBenefitsPanel = false;
            })
            .finally(() => {
                this.isLoadingBenefits = false;
            });
    }

    handleCloseBenefits() {
        this.showBenefitsPanel = false;
        this.planBenefits = [];
    }

    handleBenefitsPanelClick(event) {
        event.stopPropagation();
    }

    handleStep3Next() {
        if (this.selectedPlanIds.size === 0) return;
        this.buildRatingPlans();
        this.currentStep = 4;
        this.updateStepStatus(3);
    }

    // ─── Step 4: Rate Configuration ────────────────────────────────────────────

    buildRatingPlans() {
        const allPlans = [...this.dentalPlans, ...this.visionPlans];
        const defaultEmployeeCount = Math.floor((this.employer.Total_Employees__c || 10) * 0.6);

        this.selectedPlansForRating = allPlans
            .filter(p => p.selected)
            .map(p => ({
                planId: p.planId,
                planName: p.planName,
                rates: p.rate || { rateEO: 0, rateES: 0, rateEC: 0, rateEF: 0 },
                countEO: defaultEmployeeCount,
                countES: 0,
                countEC: 0,
                countEF: 0,
                ...this.computePlanTotals(p.rate || {}, defaultEmployeeCount, 0, 0, 0)
            }));

        this.recalculateGrandTotals();
    }

    computePlanTotals(rates, eoCount, esCount, ecCount, efCount) {
        const pct = this.employerContributionPct / 100;
        const subtotalEO = (rates.rateEO || 0) * (eoCount || 0);
        const subtotalES = (rates.rateES || 0) * (esCount || 0);
        const subtotalEC = (rates.rateEC || 0) * (ecCount || 0);
        const subtotalEF = (rates.rateEF || 0) * (efCount || 0);
        const monthlyTotal = subtotalEO + subtotalES + subtotalEC + subtotalEF;

        return {
            subtotalEO: subtotalEO.toFixed(2),
            subtotalES: subtotalES.toFixed(2),
            subtotalEC: subtotalEC.toFixed(2),
            subtotalEF: subtotalEF.toFixed(2),
            monthlyTotal: monthlyTotal.toFixed(2),
            employerEO: (subtotalEO * pct).toFixed(2),
            employerES: (subtotalES * pct).toFixed(2),
            employerEC: (subtotalEC * pct).toFixed(2),
            employerEF: (subtotalEF * pct).toFixed(2),
            employerTotal: (monthlyTotal * pct).toFixed(2),
            employeeEO: (subtotalEO * (1 - pct)).toFixed(2),
            employeeES: (subtotalES * (1 - pct)).toFixed(2),
            employeeEC: (subtotalEC * (1 - pct)).toFixed(2),
            employeeEF: (subtotalEF * (1 - pct)).toFixed(2),
            employeeTotal: (monthlyTotal * (1 - pct)).toFixed(2)
        };
    }

    handleContributionChange(event) {
        this.employerContributionPct = parseInt(event.target.value, 10);
        this.recalculateAllPlans();
    }

    handleCountChange(event) {
        const planId = event.target.dataset.planId;
        const tier = event.target.dataset.tier;
        const count = parseInt(event.target.value, 10) || 0;
        const countField = `count${tier}`;

        this.selectedPlansForRating = this.selectedPlansForRating.map(p => {
            if (p.planId === planId) {
                const updated = { ...p, [countField]: count };
                return {
                    ...updated,
                    ...this.computePlanTotals(
                        p.rates,
                        tier === 'EO' ? count : p.countEO,
                        tier === 'ES' ? count : p.countES,
                        tier === 'EC' ? count : p.countEC,
                        tier === 'EF' ? count : p.countEF
                    )
                };
            }
            return p;
        });
        this.recalculateGrandTotals();
    }

    recalculateAllPlans() {
        this.selectedPlansForRating = this.selectedPlansForRating.map(p => ({
            ...p,
            ...this.computePlanTotals(p.rates, p.countEO, p.countES, p.countEC, p.countEF)
        }));
        this.recalculateGrandTotals();
    }

    recalculateGrandTotals() {
        let total = 0, employer = 0, employee = 0;
        this.selectedPlansForRating.forEach(p => {
            total += parseFloat(p.monthlyTotal) || 0;
            employer += parseFloat(p.employerTotal) || 0;
            employee += parseFloat(p.employeeTotal) || 0;
        });
        this.totalMonthlyPremium = total.toFixed(2);
        this.employerMonthlyTotal = employer.toFixed(2);
        this.employeeMonthlyTotal = employee.toFixed(2);
        this.totalAnnualPremium = (total * 12).toFixed(2);
    }

    handleStep4Next() {
        this.currentStep = 5;
        this.updateStepStatus(4);
    }

    // ─── Step 5: Save & Generate ────────────────────────────────────────────────

    handleNotesChange(event) {
        this.quoteNotes = event.target.value;
    }

    async handleSaveDraft() {
        await this.saveQuote('Draft');
    }

    async handleGenerateProposal() {
        if (this.isSaving) return;
        this.isSaving = true;
        try {
            // Save the quote first (or reuse if already saved)
            const savedQuoteId = this.quoteId || await this.saveQuote('Draft');
            if (!savedQuoteId) return;
            // Generate PDF server-side via Apex → VF renderAs=pdf
            const proposalId = await generateProposalPDF({ quoteId: savedQuoteId });
            this.proposalId = proposalId;
            this.currentStep = 6;
            this.updateStepStatus(5);
            this.showToast('Success', 'Proposal PDF created and saved to Salesforce Files on this Quote!', 'success');
        } catch (error) {
            this.showError('Error generating proposal: ' + this.extractError(error));
        } finally {
            this.isSaving = false;
        }
    }

    async saveQuote(status) {
        const quote = {
            Employer__c: this._resolvedEmployerId || this.employerId || this.activeEmployerId,
            Broker_Account__c: this.selectedBrokerId || null,
            Effective_Date__c: this.effectiveDate,
            ZIP_Code__c: this.employer.Billing_ZIP__c,
            Employee_Count__c: this.employer.Total_Employees__c,
            Status__c: status,
            Notes__c: this.quoteNotes,
            Total_Monthly_Premium__c: parseFloat(this.totalMonthlyPremium),
            Employer_Monthly_Total__c: parseFloat(this.employerMonthlyTotal),
            Employee_Monthly_Total__c: parseFloat(this.employeeMonthlyTotal)
        };

        const lineItems = this.selectedPlansForRating.map(p => ({
            Plan__c: p.planId,
            Rate_EO__c: p.rates.rateEO,
            Rate_ES__c: p.rates.rateES,
            Rate_EC__c: p.rates.rateEC,
            Rate_EF__c: p.rates.rateEF,
            Count_EO__c: p.countEO,
            Count_ES__c: p.countES,
            Count_EC__c: p.countEC,
            Count_EF__c: p.countEF,
            Employer_Contribution_Pct__c: this.employerContributionPct,
            Is_Selected__c: true
        }));

        const savedId = await createQuote({
            quoteJSON: JSON.stringify(quote),
            lineItemsJSON: JSON.stringify(lineItems)
        });
        this.quoteId = savedId;
        // Notify parent (e.g. Quick Action wrapper) that a quote was created
        this.dispatchEvent(new CustomEvent('quotecreated', { detail: { quoteId: savedId } }));
        this.showToast('Saved', 'Quote saved as draft.', 'success');
        return savedId;
    }

    async generateProposalPDF() {
        // Trigger the child PDF generator component
        const pdfGen = this.template.querySelector('c-dd-pdf-generator');
        if (pdfGen) {
            return await pdfGen.generatePDF({
                employer: this.employer,
                plans: this.selectedPlansForRating,
                effectiveDate: this.effectiveDateDisplay,
                totalMonthly: this.totalMonthlyPremium,
                employerMonthly: this.employerMonthlyTotal,
                employeeMonthly: this.employeeMonthlyTotal
            });
        }
        // Fallback: return empty if generator not available
        return { base64: btoa('placeholder'), contentVersionId: null };
    }

    // ─── Step 6 ─────────────────────────────────────────────────────────────────

    handleViewQuote() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.quoteId, actionName: 'view' }
        });
    }

    handleNewQuote() {
        // Reset all state
        this.currentStep = 1;
        this.employer = { Name: '', Billing_ZIP__c: '', Total_Employees__c: null, Segment__c: 'Small Business', Status__c: 'Prospect' };
        this.effectiveDate = null;
        this.selectedPlanIds = new Set();
        this.dentalPlans = [];
        this.visionPlans = [];
        this.selectedPlansForRating = [];
        this.quoteId = null;
        this.proposalId = null;
        this.updateStepStatus(0);
    }

    // ─── Utilities ──────────────────────────────────────────────────────────────

    showError(message) {
        this.errorMessage = message;
        this.hasError = true;
    }

    clearError() {
        this.hasError = false;
        this.errorMessage = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return JSON.stringify(error);
    }
}
