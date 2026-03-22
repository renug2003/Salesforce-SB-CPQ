# Delta Dental of California – Small Business CPQ Platform
## Salesforce Sales Cloud Implementation Specification

**Version:** 1.0  
**Author:** Enterprise Architecture – Delta Dental of California  
**Date:** March 2026  
**Segment:** Small Business (2–99 Employees)  
**Platform:** Salesforce Sales Cloud (No CPQ managed package – native config + custom LWC)

---

## 1. Executive Summary

This specification defines the end-to-end architecture for a **custom Small Business CPQ solution** built natively on Salesforce Sales Cloud. The solution covers:

- Product Catalog (Dental + Vision plans, rate tables, benefit grids)
- Guided Selling (employer size, ZIP, effective date, plan type)
- Quote creation, line items, PDF proposal generation
- Group/Employer setup
- Contract lifecycle (draft → signed → active → expired)
- Custom Lightning Web Components with Delta Dental of California branding
- Extensible data model supporting future segments (Large Group, Medicare, Individual)

---

## 2. Business Context

### 2.1 Segment Definition
- **Small Business (SB):** Employer groups with 2–99 enrolled employees
- **Products:** Dental PPO, Dental HMO, DeltaCare USA, VSP Vision
- **Sales Channel:** Broker/Agent assisted, Direct employer
- **Goal:** Replace legacy "Rapid Rater" with a modern, scalable Salesforce-native quoting platform

### 2.2 Key Business Requirements
| # | Requirement |
|---|-------------|
| BR-01 | Quote dental and vision plans simultaneously |
| BR-02 | Support employee + dependent tier rating |
| BR-03 | Generate branded PDF proposals from quotes |
| BR-04 | Guided selling based on group size, ZIP, effective date |
| BR-05 | Contract auto-activates on start date; expires on end date |
| BR-06 | Phase 1: signed checkbox + date = contract approved |
| BR-07 | Product catalog extensible to future segments |
| BR-08 | All UI branded with Delta Dental of California style guide |

---

## 3. Data Architecture

### 3.1 Core Custom Objects

#### DD_Employer__c (Account Extension / Standalone)
Represents the employer/group seeking coverage.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Employer Name | Name | Text(255) | |
| DBA Name | DBA_Name__c | Text(255) | |
| Tax ID (FEIN) | Tax_ID__c | Text(9) | Encrypted |
| SIC Code | SIC_Code__c | Text(4) | |
| ZIP Code | Billing_ZIP__c | Text(5) | Rate territory lookup |
| County | County__c | Text(100) | |
| State | State__c | Picklist | CA default |
| Group Size | Total_Employees__c | Number(3,0) | 2–99 |
| Eligible Employees | Eligible_Employees__c | Number(3,0) | |
| Effective Date | Requested_Effective_Date__c | Date | |
| Broker/Agent | Broker_Agent__c | Lookup(Contact) | |
| Account | Account__c | Lookup(Account) | Links to Sales Cloud Account |
| Status | Status__c | Picklist | Prospect/Active/Inactive |
| Segment | Segment__c | Picklist | Small Business/Large Group/Individual |

#### DD_Plan__c (Product Catalog Master)
Insurance plan definitions — the core of the product catalog.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Plan Name | Name | Text(255) | |
| Plan Code | Plan_Code__c | Text(20) | Unique |
| Plan Type | Plan_Type__c | Picklist | PPO/HMO/DeltaCare/Vision |
| Product Line | Product_Line__c | Picklist | Dental/Vision |
| Network | Network__c | Picklist | Delta Premier/PPO/DeltaCare |
| Deductible Individual | Deductible_Individual__c | Currency | |
| Deductible Family | Deductible_Family__c | Currency | |
| Annual Maximum | Annual_Maximum__c | Currency | |
| Ortho Lifetime Max | Ortho_Lifetime_Max__c | Currency | |
| Waiting Period | Waiting_Period__c | Picklist | None/6 months/12 months |
| Segment Eligibility | Segment_Eligibility__c | Multi-Picklist | SB/LG/Individual |
| Effective Start | Effective_Start__c | Date | |
| Effective End | Effective_End__c | Date | |
| Is Active | Is_Active__c | Checkbox | |
| Sort Order | Sort_Order__c | Number(3,0) | Display ordering |
| Description | Description__c | Long Text | |
| Highlights | Highlights__c | Rich Text | For proposal display |

#### DD_PlanBenefit__c (Benefit Grid)
Benefit details per plan (preventive, basic, major, ortho, vision).

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Plan | Plan__c | Master-Detail(DD_Plan__c) | |
| Benefit Category | Benefit_Category__c | Picklist | Preventive/Basic/Major/Ortho/Vision |
| Benefit Name | Benefit_Name__c | Text(100) | e.g. "Oral Exam" |
| In-Network Coinsurance | In_Network_Coinsurance__c | Percent | e.g. 100% |
| Out-of-Network Coinsurance | Out_Network_Coinsurance__c | Percent | |
| Frequency | Frequency__c | Text(50) | e.g. "2 per calendar year" |
| Notes | Notes__c | Text(255) | |
| Sort Order | Sort_Order__c | Number(3,0) | |

#### DD_PlanRate__c (Rate Table)
Monthly premium rates per plan, territory, and tier.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Plan | Plan__c | Master-Detail(DD_Plan__c) | |
| Rate Territory | Rate_Territory__c | Text(10) | ZIP-based territory |
| Rating Tier | Rating_Tier__c | Picklist | EO/ES/EC/EF |
| Monthly Rate | Monthly_Rate__c | Currency | Per employee |
| Employer Contribution % | Employer_Contribution_Pct__c | Percent | |
| Effective Date | Effective_Date__c | Date | |
| Expiration Date | Expiration_Date__c | Date | |
| Group Size Min | Group_Size_Min__c | Number | |
| Group Size Max | Group_Size_Max__c | Number | |

**Rating Tier Legend:**
- EO = Employee Only
- ES = Employee + Spouse
- EC = Employee + Child(ren)
- EF = Employee + Family

#### DD_Quote__c (Quote Header)
Central quoting object.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Quote Number | Name | Auto-Number | QT-{000000} |
| Employer | Employer__c | Lookup(DD_Employer__c) | |
| Broker | Broker__c | Lookup(Contact) | |
| Effective Date | Effective_Date__c | Date | |
| Expiration Date | Quote_Expiration_Date__c | Date | Default +30 days |
| Status | Status__c | Picklist | Draft/Presented/Accepted/Declined/Expired |
| Quote Type | Quote_Type__c | Picklist | New/Renewal/Addline |
| Total Monthly Premium | Total_Monthly_Premium__c | Currency | Roll-up |
| Total Annual Premium | Total_Annual_Premium__c | Formula | Monthly × 12 |
| Employee Count | Employee_Count__c | Number | From Employer |
| ZIP Code | ZIP_Code__c | Text | For territory |
| Rate Territory | Rate_Territory__c | Text | Derived from ZIP |
| Notes | Notes__c | Long Text | |
| PDF Generated | PDF_Generated__c | Checkbox | |
| PDF URL | PDF_URL__c | URL | Stored file link |
| Created By | CreatedById | Standard | |

#### DD_QuoteLineItem__c (Quote Lines)
Individual plan selections on a quote.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Quote | Quote__c | Master-Detail(DD_Quote__c) | |
| Plan | Plan__c | Lookup(DD_Plan__c) | |
| Plan Name | Plan_Name__c | Text | Formula from Plan |
| Plan Type | Plan_Type__c | Text | Formula |
| EO Rate | Rate_EO__c | Currency | From rate table |
| ES Rate | Rate_ES__c | Currency | |
| EC Rate | Rate_EC__c | Currency | |
| EF Rate | Rate_EF__c | Currency | |
| EO Count | Count_EO__c | Number | From census |
| ES Count | Count_ES__c | Number | |
| EC Count | Count_EC__c | Number | |
| EF Count | Count_EF__c | Number | |
| Monthly Subtotal | Monthly_Subtotal__c | Formula | Sum(rate × count) |
| Employer Contribution % | Employer_Contribution_Pct__c | Percent | |
| Employer Monthly Cost | Employer_Monthly_Cost__c | Formula | |
| Employee Monthly Cost | Employee_Monthly_Cost__c | Formula | |
| Is Selected | Is_Selected__c | Checkbox | Primary selection |

#### DD_Census__c (Employee Census)
Demographic data for rating.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Employer | Employer__c | Master-Detail(DD_Employer__c) | |
| Employee ID | Employee_ID__c | Text | |
| Date of Birth | Date_of_Birth__c | Date | |
| Gender | Gender__c | Picklist | |
| Coverage Tier | Coverage_Tier__c | Picklist | EO/ES/EC/EF |
| ZIP Code | ZIP_Code__c | Text | |
| Status | Status__c | Picklist | Active/Waiving/COBRA |
| Waiver Reason | Waiver_Reason__c | Picklist | |

#### DD_Proposal__c (Proposal)
Formal proposal document tracking.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Proposal Number | Name | Auto-Number | PR-{000000} |
| Quote | Quote__c | Lookup(DD_Quote__c) | |
| Employer | Employer__c | Lookup(DD_Employer__c) | |
| Status | Status__c | Picklist | Draft/Sent/Viewed/Accepted/Declined |
| Sent Date | Sent_Date__c | Date | |
| Expiration Date | Expiration_Date__c | Date | |
| PDF Content Version | PDF_Content_Version__c | Text | ContentVersion ID |
| Presented By | Presented_By__c | Lookup(User) | |
| Notes | Notes__c | Long Text | |

#### DD_Group__c (Group Setup — post-sale)
The enrolled group after quote acceptance.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Group Number | Name | Auto-Number | GRP-{000000} |
| Employer | Employer__c | Lookup(DD_Employer__c) | |
| Quote | Source_Quote__c | Lookup(DD_Quote__c) | |
| Group Name | Group_Name__c | Text | |
| SIC Code | SIC_Code__c | Text | |
| Effective Date | Effective_Date__c | Date | |
| Renewal Date | Renewal_Date__c | Date | |
| Status | Status__c | Picklist | Pending/Active/Lapsed/Terminated |
| Total Enrolled | Total_Enrolled__c | Number | Roll-up |
| Billing Day | Billing_Day__c | Number | Day of month |
| Billing Method | Billing_Method__c | Picklist | List Bill/Self-Bill |

#### DD_Contract__c (Contract Lifecycle)
Group insurance contract.

| Field | API Name | Type | Notes |
|-------|----------|------|-------|
| Contract Number | Name | Auto-Number | CTR-{000000} |
| Group | Group__c | Lookup(DD_Group__c) | |
| Employer | Employer__c | Lookup(DD_Employer__c) | |
| Quote | Quote__c | Lookup(DD_Quote__c) | |
| Status | Status__c | Picklist | Draft/Pending Signature/Approved/Active/Expired/Terminated |
| Start Date | Start_Date__c | Date | |
| End Date | End_Date__c | Date | Typically 12 months |
| Is Signed | Is_Signed__c | Checkbox | Phase 1 signature |
| Signed Date | Signed_Date__c | Date | |
| Signed By Name | Signed_By_Name__c | Text | |
| Signed By Title | Signed_By_Title__c | Text | |
| Auto Renew | Auto_Renew__c | Checkbox | |
| Termination Date | Termination_Date__c | Date | |
| Termination Reason | Termination_Reason__c | Picklist | |
| Total Annual Premium | Total_Annual_Premium__c | Currency | From Quote |
| PDF Content Version | Contract_PDF__c | Text | ContentVersion ID |

### 3.2 Territory-to-ZIP Mapping
Custom Metadata Type: `DD_ZIP_Territory__mdt`
- ZIP_Code__c (Text)
- Rate_Territory__c (Text)
- County__c (Text)
- Region__c (Text)

### 3.3 Object Relationships Diagram
```
Account ←──── DD_Employer__c ──────→ DD_Census__c
                    │
                    ├──→ DD_Quote__c ──→ DD_QuoteLineItem__c ──→ DD_Plan__c
                    │         │                                        │
                    │         │                                   DD_PlanBenefit__c
                    │         │                                   DD_PlanRate__c
                    │         ↓
                    │    DD_Proposal__c
                    │
                    ├──→ DD_Group__c
                    │         │
                    └──→ DD_Contract__c ←── DD_Group__c
```

---

## 4. Guided Selling Flow

### 4.1 Wizard Steps
1. **Employer Info** — Name, ZIP, group size, SIC, effective date
2. **Plan Type Selection** — Dental only / Vision only / Dental + Vision
3. **Plan Selection** — Filtered plans by territory + segment eligibility
4. **Rate Configuration** — Census upload or manual tier counts, contribution %
5. **Quote Summary** — Premium summary, employer vs employee split
6. **Proposal Generation** — PDF preview and send

### 4.2 Filtering Logic
```
Plans shown = DD_Plan__c WHERE:
  - Is_Active__c = true
  - Segment_Eligibility__c INCLUDES 'Small Business'
  - Effective_Start__c <= Requested Effective Date
  - Effective_End__c >= Requested Effective Date (or null)
  - Plan_Type__c matches user selection
```

### 4.3 Rate Lookup Logic
```
Rate = DD_PlanRate__c WHERE:
  - Plan__c = selected plan
  - Rate_Territory__c = ZIP territory (from DD_ZIP_Territory__mdt)
  - Group_Size_Min__c <= group size <= Group_Size_Max__c
  - Effective_Date__c <= quote effective date
  - Expiration_Date__c >= quote effective date (or null)
```

---

## 5. Contract Lifecycle Automation

### 5.1 State Machine
```
Draft → [Is_Signed__c = true AND Signed_Date__c set] → Approved
Approved → [Start_Date__c = Today] → Active       (Scheduled Flow, daily)
Active → [End_Date__c < Today] → Expired           (Scheduled Flow, daily)
Active → [Manual Termination] → Terminated
```

### 5.2 Automation Components
- **Flow: DD_Contract_SignatureApproval** — Record-triggered, when Is_Signed__c changes to true
- **Flow: DD_Contract_DailyStatusCheck** — Scheduled daily at 1:00 AM PT
- **Trigger: DD_ContractTrigger** — Validates signed date, prevents backdating

---

## 6. PDF Proposal Generation

### 6.1 Approach
- LWC component renders proposal HTML
- JavaScript `window.print()` or html2pdf.js converts to PDF
- File stored as Salesforce Files (ContentVersion) linked to DD_Proposal__c
- Download link surfaced in UI

### 6.2 Proposal Sections
1. Cover page — Delta Dental branding, employer name, date
2. Executive Summary — Selected plans overview
3. Plan Details — Benefits grid per plan
4. Rate Summary — Tier rates, employer/employee split
5. Terms & Conditions — Standard boilerplate
6. Signature Page

---

## 7. UI Architecture (LWC)

### 7.1 Component Inventory

| Component | Purpose |
|-----------|---------|
| `ddBrandedHeader` | Global header with Delta Dental logo + nav |
| `ddQuoteWizard` | Multi-step quote creation wizard (parent) |
| `ddGuidedSelling` | Step 1-2: employer info + plan type selection |
| `ddPlanSelector` | Step 3: plan grid with compare feature |
| `ddRateConfigurator` | Step 4: census/tier counts + contribution % |
| `ddQuoteSummary` | Step 5: premium breakdown |
| `ddProposalViewer` | Proposal preview + PDF download |
| `ddGroupManager` | Post-sale group setup form |
| `ddContractManager` | Contract details + signature capture |
| `ddPdfGenerator` | PDF rendering utility |

### 7.2 Delta Dental of California Brand Tokens

```css
--dd-navy: #1F4788;
--dd-blue-mid: #2E6DB4;
--dd-blue-light: #5B9BD5;
--dd-blue-pale: #DEEAF1;
--dd-gold: #C89B2A;
--dd-white: #FFFFFF;
--dd-gray-dark: #333333;
--dd-gray-mid: #666666;
--dd-gray-light: #F5F5F5;
--dd-success: #2E7D32;
--dd-warning: #F57C00;
--dd-error: #C62828;
--dd-font-primary: 'Proxima Nova', 'Helvetica Neue', Arial, sans-serif;
--dd-font-size-h1: 28px;
--dd-font-size-h2: 22px;
--dd-font-size-body: 14px;
--dd-border-radius: 6px;
--dd-shadow: 0 2px 8px rgba(31,71,136,0.15);
```

---

## 8. Permission Model

| Profile/Permission Set | Access |
|------------------------|--------|
| DD_CPQ_Sales_Rep | Create/Edit Quotes, read Plans |
| DD_CPQ_Broker_Portal | Read Quotes, read Proposals |
| DD_CPQ_Manager | Full access including delete |
| DD_CPQ_Admin | System config, metadata, all access |
| DD_CPQ_Read_Only | Read only all CPQ objects |

---

## 9. Integration Points (Future)

| System | Integration | Phase |
|--------|-------------|-------|
| DDCA Rating Engine | REST API real-time rates | Phase 2 |
| DocuSign | Electronic signature | Phase 2 |
| DDCA Group Admin | Group enrollment sync | Phase 2 |
| Salesforce Experience Cloud | Broker portal | Phase 3 |
| MuleSoft | Enterprise middleware | Phase 3 |

---

## 10. Non-Functional Requirements

| NFR | Requirement |
|-----|------------|
| Performance | Quote page load < 2s; PDF generation < 10s |
| Security | HIPAA-aligned field encryption for Tax ID, DOB |
| Scalability | Support 10,000+ employers, 500,000+ quote lines |
| Extensibility | Segment field on DD_Plan__c enables future segments |
| Compliance | Audit trail via Salesforce Field History + Platform Events |
| Availability | 99.9% uptime (Salesforce SLA) |

---

## 11. Deployment Phases

### Phase 1 (This Implementation)
- All custom objects and fields
- Product catalog (Dental + Vision)
- Guided selling LWC wizard
- Quote + proposal + PDF generation
- Checkbox-based contract signing
- Daily scheduled flows for contract status
- Delta Dental branded LWC UI

### Phase 2
- DocuSign e-signature integration
- Real-time rating API integration
- Broker portal (Experience Cloud)
- Renewal quoting workflow

### Phase 3
- Large Group segment extension
- Medicare Advantage catalog extension
- MuleSoft enterprise integration
- AI-powered plan recommendations
