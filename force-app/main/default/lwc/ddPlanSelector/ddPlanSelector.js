import { LightningElement, api, track } from 'lwc';
import getAvailablePlans from '@salesforce/apex/DD_CPQController.getAvailablePlans';
import getRatesForPlan from '@salesforce/apex/DD_CPQController.getRatesForPlan';
import getPlanBenefits from '@salesforce/apex/DD_CPQController.getPlanBenefits';

export default class DdPlanSelector extends LightningElement {
    @api zipCode = '94105';
    @api groupSize = 15;
    @api effectiveDate;
    @api preSelectedIds = [];

    @track allPlans = [];
    @track isLoading = true;
    @track productFilter = 'All';
    @track searchTerm = '';
    @track showBenefitsModal = false;
    @track activePlan = null;
    @track planBenefits = [];
    @track isLoadingBenefits = false;

    selectedPlanIds = new Set();
    comparePlanIds = new Set();

    connectedCallback() { this.loadPlans(); }

    async loadPlans() {
        this.isLoading = true;
        try {
            const plans = await getAvailablePlans({
                productLine: 'All',
                groupSize: String(this.groupSize),
                effectiveDate: this.effectiveDate || new Date().toISOString().substring(0, 10)
            });

            const ratePromises = plans.map(p =>
                getRatesForPlan({
                    planId: p.planId,
                    zipCode: this.zipCode,
                    groupSize: this.groupSize,
                    effectiveDate: this.effectiveDate || new Date().toISOString().substring(0, 10)
                }).then(r => ({ id: p.planId, rate: r })).catch(() => ({ id: p.planId, rate: null }))
            );
            const rates = await Promise.all(ratePromises);
            const rateMap = {};
            rates.forEach(r => { rateMap[r.id] = r.rate; });

            this.allPlans = plans.map(p => ({
                ...p,
                rate: rateMap[p.planId],
                selected: (this.preSelectedIds || []).includes(p.planId),
                compareSelected: false,
                annualMaxDisplay: p.annualMaximum ? `$${Number(p.annualMaximum).toLocaleString()}` : 'No Limit',
                cardClass: 'ddps-plan-card',
                selectBtnClass: 'ddps-btn-primary',
                selectBtnLabel: 'Select Plan'
            }));

        } catch (e) {
            console.error('Error loading plans', e);
        } finally {
            this.isLoading = false;
        }
    }

    get filteredPlans() {
        return this.allPlans
            .filter(p => this.productFilter === 'All' || p.productLine === this.productFilter)
            .filter(p => !this.searchTerm || p.planName.toLowerCase().includes(this.searchTerm.toLowerCase()))
            .map(p => ({
                ...p,
                cardClass: `ddps-plan-card${p.selected ? ' ddps-plan-selected' : ''}${p.compareSelected ? ' ddps-plan-compare' : ''}`,
                selectBtnClass: p.selected ? 'ddps-btn-selected' : 'ddps-btn-primary',
                selectBtnLabel: p.selected ? '✓ Selected' : 'Select Plan'
            }));
    }

    get hasPlans() { return this.filteredPlans.length > 0; }
    get selectedCount() { return [...this.allPlans.filter(p => p.compareSelected)].length; }
    get hasComparisons() { return this.selectedCount >= 2; }
    get dentalToggleClass() { return `ddps-toggle${this.productFilter === 'Dental' ? ' ddps-toggle-active' : ''}`; }
    get visionToggleClass() { return `ddps-toggle${this.productFilter === 'Vision' ? ' ddps-toggle-active' : ''}`; }
    get allToggleClass() { return `ddps-toggle${this.productFilter === 'All' ? ' ddps-toggle-active' : ''}`; }

    get benefitCategories() {
        const catOrder = ['Preventive', 'Basic', 'Major', 'Orthodontia', 'Vision'];
        const grouped = {};
        this.planBenefits.forEach(b => {
            const cat = b.Benefit_Category__c;
            if (!grouped[cat]) grouped[cat] = [];
            grouped[cat].push(b);
        });
        return catOrder
            .filter(c => grouped[c])
            .map(c => ({ name: c, benefits: grouped[c] }));
    }

    handleProductFilter(e) { this.productFilter = e.currentTarget.dataset.val; }
    handleSearch(e) { this.searchTerm = e.target.value; }

    handleSelectPlan(e) {
        const planId = e.currentTarget.dataset.planId;
        this.toggleSelection(planId);
    }

    handleSelectFromModal(e) {
        const planId = e.currentTarget.dataset.planId;
        this.toggleSelection(planId);
        this.closeBenefitsModal();
    }

    toggleSelection(planId) {
        this.allPlans = this.allPlans.map(p => {
            if (p.planId === planId) {
                const selected = !p.selected;
                if (selected) this.selectedPlanIds.add(planId);
                else this.selectedPlanIds.delete(planId);
                return { ...p, selected };
            }
            return p;
        });
        this.dispatchEvent(new CustomEvent('planselectionchange', {
            detail: { selectedPlanIds: [...this.selectedPlanIds] }
        }));
    }

    handleCompareToggle(e) {
        const planId = e.target.dataset.planId;
        const checked = e.target.checked;
        if (checked && this.comparePlanIds.size >= 3) {
            e.target.checked = false;
            return;
        }
        if (checked) this.comparePlanIds.add(planId);
        else this.comparePlanIds.delete(planId);
        this.allPlans = this.allPlans.map(p =>
            p.planId === planId ? { ...p, compareSelected: checked } : p
        );
    }

    handleCompare() {
        const ids = [...this.comparePlanIds];
        this.dispatchEvent(new CustomEvent('compare', { detail: { planIds: ids } }));
    }

    async handleViewBenefits(e) {
        e.stopPropagation();
        const planId = e.currentTarget.dataset.planId;
        this.activePlan = this.allPlans.find(p => p.planId === planId);
        this.showBenefitsModal = true;
        this.isLoadingBenefits = true;
        try {
            this.planBenefits = await getPlanBenefits({ planId });
        } catch (err) {
            this.planBenefits = [];
        } finally {
            this.isLoadingBenefits = false;
        }
    }

    closeBenefitsModal() { this.showBenefitsModal = false; this.activePlan = null; }
    stopProp(e) { e.stopPropagation(); }
}
