# CLAUDE.md — Delta Dental of California Small Business CPQ
## Instructions for Claude Code Agent

This file guides Claude Code in building the Delta Dental of California Small Business CPQ solution on Salesforce Sales Cloud using the Salesforce CLI (sf).

---

## Project Overview

You are building a custom Small Business (2–99 employees) CPQ solution for Delta Dental of California on Salesforce Sales Cloud. The solution uses **no managed CPQ package** — everything is native Salesforce configuration plus custom Lightning Web Components.

**Key constraint:** Use maximum out-of-the-box Salesforce features. Only build custom code where OOTB is insufficient.

---

## Repository Structure

```
dd-cpq/
├── CLAUDE.md                          ← You are here
├── docs/
│   ├── SPECIFICATION.md               ← Full business + data spec
│   └── DEPLOYMENT_GUIDE.md            ← Step-by-step deploy instructions
├── config/
│   └── project-scratch-def.json       ← Scratch org definition
├── scripts/
│   ├── 01-create-scratch-org.sh
│   ├── 02-deploy-metadata.sh
│   ├── 03-load-sample-data.sh
│   └── 04-assign-permissions.sh
├── force-app/main/default/
│   ├── objects/                        ← Custom objects + fields
│   ├── classes/                        ← Apex classes
│   ├── triggers/                       ← Apex triggers
│   ├── flows/                          ← Flow definitions
│   ├── lwc/                            ← Lightning Web Components
│   ├── pages/                          ← Visualforce (PDF only)
│   ├── layouts/                        ← Page layouts
│   ├── permissionsets/                 ← Permission sets
│   ├── tabs/                           ← Custom tabs
│   ├── applications/                   ← Lightning app
│   ├── customMetadata/                 ← ZIP territory mapping
│   └── labels/                         ← Custom labels
└── data/
    ├── sample-plans.json
    ├── sample-rates.json
    └── sample-zip-territories.json
```

---

## Build Order (CRITICAL — follow this sequence)

### Step 1: Custom Objects
Deploy objects in dependency order:
1. `DD_Employer__c`
2. `DD_Plan__c`
3. `DD_PlanBenefit__c` (child of DD_Plan__c)
4. `DD_PlanRate__c` (child of DD_Plan__c)
5. `DD_Census__c` (child of DD_Employer__c)
6. `DD_Quote__c` (lookup to DD_Employer__c)
7. `DD_QuoteLineItem__c` (master-detail to DD_Quote__c, lookup to DD_Plan__c)
8. `DD_Proposal__c` (lookup to DD_Quote__c)
9. `DD_Group__c` (lookup to DD_Employer__c)
10. `DD_Contract__c` (lookup to DD_Group__c, DD_Employer__c, DD_Quote__c)

### Step 2: Custom Metadata
Deploy `DD_ZIP_Territory__mdt` with sample California ZIP codes.

### Step 3: Apex Classes
Deploy in this order:
1. `DD_TerritoryService` — ZIP to territory lookup
2. `DD_RateService` — Rate table queries
3. `DD_PlanService` — Plan catalog queries
4. `DD_QuoteService` — Quote business logic
5. `DD_ProposalService` — Proposal PDF generation
6. `DD_ContractService` — Contract lifecycle
7. `DD_CPQController` — Main LWC Apex controller
8. Test classes for all above

### Step 4: Triggers
1. `DD_ContractTrigger` — Validates signing, prevents backdating

### Step 5: Flows
1. `DD_Contract_SignatureApproval` — Record-triggered
2. `DD_Contract_DailyStatusCheck` — Scheduled (daily 1 AM PT)
3. `DD_Quote_SetTerritory` — Record-triggered, sets rate territory from ZIP

### Step 6: LWC Components
Deploy in this order:
1. `ddBrandedHeader`
2. `ddGuidedSelling`
3. `ddPlanSelector`
4. `ddRateConfigurator`
5. `ddQuoteSummary`
6. `ddProposalViewer`
7. `ddGroupManager`
8. `ddContractManager`
9. `ddPdfGenerator`
10. `ddQuoteWizard` (parent — depends on all above)

### Step 7: App + Tabs + Layouts
1. Custom tabs for each object
2. Lightning app `DD_CPQ_App`
3. Page layouts
4. Permission sets

---

## Salesforce CLI Commands Reference

```bash
# Authenticate to org
sf org login web --alias dd-cpq-dev

# Create scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias dd-cpq-scratch --duration-days 30

# Deploy all metadata
sf project deploy start --source-dir force-app --target-org dd-cpq-dev

# Deploy specific component
sf project deploy start --metadata LightningComponentBundle:ddQuoteWizard --target-org dd-cpq-dev

# Run Apex tests
sf apex run test --target-org dd-cpq-dev --code-coverage --result-format human

# Load data
sf data import tree --files data/sample-plans.json --target-org dd-cpq-dev

# Open org
sf org open --target-org dd-cpq-dev
```

---

## Coding Standards

### Apex
- All classes must have corresponding test classes with minimum 85% coverage
- Use `@AuraEnabled(cacheable=true)` for read-only LWC controller methods
- Use `@AuraEnabled` for DML operations
- Bulkify all trigger logic — handle collections, not single records
- Use Custom Labels for all user-facing strings
- No SOQL in loops — ever
- Use `WITH SECURITY_ENFORCED` on all SOQL queries
- Handle all exceptions with custom `DD_CPQException` class

### LWC
- All components use Delta Dental CSS design tokens (defined in `ddDesignTokens.css`)
- Import design tokens: `@import 'c/ddDesignTokens'`
- Use `@wire` service for simple data reads
- Use imperative Apex for complex operations
- All components must be accessible (ARIA labels, keyboard navigation)
- Use `lightning-record-edit-form` for standard field editing
- Custom styling: never override SLDS base components, always use CSS custom properties

### Security
- Field-level security enforced on all Apex queries
- Sharing rules applied to all objects
- Tax_ID__c uses Platform Encryption
- Date_of_Birth__c uses Platform Encryption
- No hardcoded IDs anywhere — use Custom Metadata or Custom Labels

---

## Delta Dental Brand Guidelines

Always apply these styles in LWC components:

```css
/* Primary colors */
--dd-navy: #1F4788;
--dd-blue-mid: #2E6DB4;
--dd-gold: #C89B2A;

/* Usage */
/* Headers/nav: --dd-navy background, white text */
/* CTAs: --dd-blue-mid background */
/* Accents/badges: --dd-gold */
/* Page background: #F5F7FA */
/* Card backgrounds: white with box-shadow */
```

Button hierarchy:
- Primary: navy background (#1F4788), white text
- Secondary: white background, navy border, navy text
- Destructive: red (#C62828)

---

## Object API Names Quick Reference

| Object | API Name |
|--------|----------|
| Employer | DD_Employer__c |
| Plan | DD_Plan__c |
| Plan Benefit | DD_PlanBenefit__c |
| Plan Rate | DD_PlanRate__c |
| Census | DD_Census__c |
| Quote | DD_Quote__c |
| Quote Line Item | DD_QuoteLineItem__c |
| Proposal | DD_Proposal__c |
| Group | DD_Group__c |
| Contract | DD_Contract__c |
| ZIP Territory (CMDT) | DD_ZIP_Territory__mdt |

---

## Key Business Rules to Implement

1. **Quote Expiration:** Auto-set to 30 days from creation date
2. **Territory Lookup:** ZIP → Territory via DD_ZIP_Territory__mdt
3. **Rate Matching:** Match plan + territory + group size range + effective date
4. **Contract Signing (Phase 1):** When Is_Signed__c = true AND Signed_Date__c is populated → Status = 'Approved'
5. **Contract Activation:** Daily flow — if Status = 'Approved' AND Start_Date__c = Today → Status = 'Active'
6. **Contract Expiration:** Daily flow — if Status = 'Active' AND End_Date__c < Today → Status = 'Expired'
7. **Plan Filtering:** Only show plans where Segment_Eligibility__c includes 'Small Business' AND Is_Active__c = true
8. **Group Size Validation:** Employer must have 2–99 total employees for SB segment

---

## Testing Requirements

For each Apex class, create a test class named `[ClassName]Test`:
- Use `@isTest` and `TestDataFactory` pattern
- Test governor limits with 200-record bulk tests
- Test positive, negative, and boundary cases
- Mock external callouts with `HttpCalloutMock`
- Use `Test.startTest()` / `Test.stopTest()` around DML + async

---

## Do NOT

- Do NOT install any managed packages (CPQ Steelbrick, etc.)
- Do NOT use Visualforce for UI (only for PDF generation background service)
- Do NOT hardcode record IDs, org IDs, or usernames
- Do NOT use `without sharing` unless explicitly documented with a reason
- Do NOT create fields without help text
- Do NOT deploy without running all Apex tests first
