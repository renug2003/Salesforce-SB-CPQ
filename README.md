# Delta Dental of California — Small Business CPQ

> A fully native Salesforce Sales Cloud CPQ solution for Small Business (2–99 employees) group dental plans. No managed packages. Built with Lightning Web Components, Apex, and Visualforce PDF generation.

[![Salesforce API](https://img.shields.io/badge/Salesforce-API%20v60.0-00A1E0?logo=salesforce)](https://developer.salesforce.com)
[![LWC](https://img.shields.io/badge/UI-Lightning%20Web%20Components-00A1E0)](https://developer.salesforce.com/docs/component-library)
[![Apex](https://img.shields.io/badge/Logic-Apex-00A1E0)](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Object Model](#object-model)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [LWC Components](#lwc-components)
- [Apex Classes](#apex-classes)
- [Flows & Automation](#flows--automation)
- [PDF Generation](#pdf-generation)
- [Deployment Guide](#deployment-guide)
- [Brand Guidelines](#brand-guidelines)
- [Roadmap](#roadmap)

---

## Overview

This solution covers the full Small Business group dental sales lifecycle on Salesforce Sales Cloud:

| Stage | Capability |
|-------|-----------|
| **Quoting** | Guided 6-step wizard: employer info → plan selection → rate configuration → summary |
| **Proposal** | Branded PDF proposal generated server-side via Visualforce, saved as Salesforce File |
| **Enrollment** | Convert accepted quote to Group record with enrolled member counts |
| **Contracting** | Create contract from Group, generate contract PDF with full benefit schedule |
| **Lifecycle** | Daily flows manage contract activation, expiration, and renewal prompts |

**Plans supported (DDCA 2025 benefit documents):**
- Delta Dental PPO™ Children's Dental — Small Business
- Delta Dental PPO™ Family Dental — Small Business (Core & Enhanced tiers)
- DeltaVision™ VSP Essential & Premier Vision

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Lightning Experience UI                       │
│   ddQuoteWizard · ddPlanSelector · ddContractManager · ...       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ @AuraEnabled Apex
┌──────────────────────────▼──────────────────────────────────────┐
│                      DD_CPQController                             │
│  (single controller — all LWC ↔ Apex calls route through here)  │
└──┬──────────────┬──────────────┬──────────────┬─────────────────┘
   │              │              │              │
   ▼              ▼              ▼              ▼
DD_QuoteService  DD_ProposalService  DD_ContractService  DD_RateService
DD_PlanService   DD_TerritoryService
   │
   ▼
┌─────────────────────────────────────────────────────────────────┐
│              Visualforce PDF (renderAs=pdf)                      │
│   DD_ProposalPDF.page · DD_ContractPDF.page                     │
│          → ContentVersion → ContentDocumentLink                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- Single `DD_CPQController` as the LWC ↔ Apex boundary (no direct service calls from LWC)
- VF PDF generated server-side using `PageReference.getContent()` — no JS libraries, no callouts
- PDF generated from *existing* committed records (Group/Quote) to avoid transaction visibility issues
- All SOQL uses `WITH SECURITY_ENFORCED` for FLS compliance
- `without sharing` only on VF PDF controllers (PDF background service pattern)

---

## Object Model

```
DD_Employer__c
    ├── DD_Census__c          (enrolled member census)
    ├── DD_Quote__c
    │     ├── DD_QuoteLineItem__c ──► DD_Plan__c
    │     │                                ├── DD_PlanBenefit__c
    │     │                                └── DD_PlanRate__c
    │     └── DD_Proposal__c   (linked PDF file)
    ├── DD_Group__c            (post-sale enrollment)
    │     └── DD_Contract__c   (linked contract PDF file)
    └── (Custom Metadata)
          └── DD_ZIP_Territory__mdt
```

### Contract Lifecycle

```
Draft
  └─► [Create Contract & PDF button on Group]
        └─► Draft ──► Pending Signature
                          └─► [Is_Signed = true + Signed_Date]
                                └─► Approved (via Flow)
                                      └─► [Start Date = Today, daily flow]
                                            └─► Active
                                                  ├─► [End Date < Today] ──► Expired
                                                  └─► [Manual]           ──► Terminated
```

---

## Quick Start

### Prerequisites

- Salesforce CLI (`sf`) installed — [Install Guide](https://developer.salesforce.com/tools/salesforcecli)
- Authenticated to your org: `sf org login web --alias dd-cpq-dev`

### Deploy to Developer Org / Sandbox

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/dd-cpq.git
cd dd-cpq

# Authenticate to your org
sf org login web --alias dd-cpq-dev

# Deploy all metadata
sf project deploy start --source-dir force-app --target-org dd-cpq-dev

# Load sample plan and rate data
sf data import tree --files data/sample-plans.json --target-org dd-cpq-dev
sf data import tree --files data/sample-rates.json --target-org dd-cpq-dev
sf data import tree --files data/sample-benefits.json --target-org dd-cpq-dev

# Assign permission sets
sf org assign permset --name DD_CPQ_Admin --target-org dd-cpq-dev

# Open the org
sf org open --target-org dd-cpq-dev
# Navigate: App Launcher → Delta Dental CPQ
```

### Scratch Org (Full Reset)

```bash
bash scripts/01-create-scratch-org.sh
bash scripts/02-deploy-metadata.sh dd-cpq-scratch
bash scripts/03-load-sample-data.sh dd-cpq-scratch
bash scripts/04-assign-permissions.sh dd-cpq-scratch
```

---

## Project Structure

```
dd-cpq/
├── .github/
│   └── workflows/
│       └── ci.yml                    ← GitHub Actions: validate on PR
├── config/
│   └── project-scratch-def.json      ← Scratch org definition
├── data/
│   ├── sample-plans.json             ← 6 real DDCA plan records
│   ├── sample-rates.json             ← EO/ES/EC/EF rate tables
│   ├── sample-benefits.json          ← Benefit grids per plan
│   └── plan-benefits.json
├── docs/
│   ├── SPECIFICATION.md              ← Full business + data spec
│   ├── DEPLOYMENT_GUIDE.md           ← Step-by-step deploy guide
│   └── STATIC_RESOURCES.md          ← Static resource notes
├── scripts/
│   ├── 01-create-scratch-org.sh
│   ├── 02-deploy-metadata.sh
│   ├── 03-load-sample-data.sh
│   └── 04-assign-permissions.sh
├── force-app/main/default/
│   ├── objects/                      ← Custom objects & fields
│   ├── classes/                      ← Apex service classes & tests
│   ├── lwc/                          ← Lightning Web Components
│   ├── pages/                        ← Visualforce PDF pages
│   ├── layouts/                      ← Page layouts
│   ├── quickActions/                 ← Quick actions (LWC screen actions)
│   ├── aura/                         ← Aura wrappers (action overrides)
│   ├── flows/                        ← Flows (contract lifecycle, territory)
│   ├── triggers/                     ← Apex triggers
│   ├── permissionsets/               ← Permission sets
│   ├── tabs/                         ← Custom tabs
│   ├── applications/                 ← Lightning App definition
│   └── customMetadata/               ← ZIP → Territory mapping
├── sfdx-project.json
├── CLAUDE.md                         ← Claude Code agent instructions
└── README.md
```

---

## LWC Components

| Component | Purpose | Target |
|-----------|---------|--------|
| `ddQuoteWizard` | 6-step guided selling wizard (parent) | App/Record page |
| `ddGuidedSelling` | Step 1: Employer information form | Child of wizard |
| `ddPlanSelector` | Step 2: Plan grid, compare modal, benefits tab | Child of wizard |
| `ddRateConfigurator` | Step 3: Tier subscriber counts + employer contribution | Child of wizard |
| `ddQuoteSummary` | Step 4: Premium breakdown, totals | Child of wizard |
| `ddProposalViewer` | Proposal preview and PDF download | Quote record page |
| `ddGroupManager` | Group enrollment setup form | Quote record page |
| `ddContractManager` | Contract details + signature capture | Contract record page |
| `ddBrandedHeader` | Global DDCA branded navigation bar | App page |
| `ddPdfGenerator` | PDF generation trigger component | Quick Action |
| `ddGenerateProposalAction` | Generate Proposal PDF — screen action on Quote | Quick Action |
| `ddCreateContractAction` | Create Contract & PDF — screen action on Group | Quick Action |
| `ddQuoteStandaloneAction` | New Quote wizard — screen action (standalone) | Quick Action |
| `ddQuoteRelatedGroups` | Groups related list on Quote record | Record page |
| `ddDesignTokens` | Shared DDCA CSS design tokens | CSS import |

---

## Apex Classes

| Class | Type | Purpose |
|-------|------|---------|
| `DD_CPQController` | Controller | All `@AuraEnabled` methods for LWC components |
| `DD_QuoteService` | Service | Quote creation, totals calculation, quote→group conversion |
| `DD_PlanService` | Service | Plan catalog queries with segment/date filtering |
| `DD_RateService` | Service | Rate table lookups by plan/territory/group size |
| `DD_TerritoryService` | Service | ZIP code → rate territory via Custom Metadata |
| `DD_ProposalService` | Service | Proposal creation, VF PDF generation, file linking |
| `DD_ContractService` | Service | Contract creation from Group, signing, termination |
| `DD_ProposalPDFController` | VF Controller | Data provider for `DD_ProposalPDF.page` |
| `DD_ContractPDFController` | VF Controller | Data provider for `DD_ContractPDF.page` (reads from Group) |
| `DD_CPQException` | Exception | Custom exception class for business rule violations |

Each service class has a corresponding `*Test` class with ≥85% coverage.

---

## Flows & Automation

| Flow | Type | Trigger | Purpose |
|------|------|---------|---------|
| `DD_Contract_SignatureApproval` | Record-Triggered | `Is_Signed__c` changes to `true` | Set Status = 'Approved' |
| `DD_Contract_DailyStatusCheck` | Scheduled | Daily 1 AM PT | Activate approved contracts, expire ended contracts |
| `DD_Quote_SetTerritory` | Record-Triggered | `ZIP_Code__c` changes | Populate `Rate_Territory__c` via Territory Service |

---

## PDF Generation

Two server-side Visualforce PDFs are generated using `PageReference.getContent()`:

### Proposal PDF (`DD_ProposalPDF.page`)
- Generated from `DD_Quote__c` + `DD_QuoteLineItem__c` records
- Shows employer info, premium summary, per-plan rate breakdown
- Triggered via **Generate Proposal** quick action on Quote record
- Saved as `ContentVersion`, linked to both Quote and Proposal records

### Contract PDF (`DD_ContractPDF.page`)
- Generated from `DD_Group__c` + `Source_Quote__r` + `DD_QuoteLineItem__c` records
- Shows full Schedule of Benefits: deductibles, Class I–IV coinsurance tables, rate breakdown
- Includes General Provisions, Limitations, and Signature block
- Generated **before** contract creation to avoid transaction visibility issue with `getContent()`
- Triggered via **Create Contract** quick action on Group record
- Saved as `ContentVersion`, linked to the new `DD_Contract__c` record

> **Note:** `PageReference.getContent()` renders VF pages via a separate HTTP request in a new transaction context. Always pass IDs of *committed* records as parameters — newly inserted records in the same transaction are not visible.

---

## Deployment Guide

See [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) for full instructions including:
- Deploy order (objects → metadata → Apex → triggers → flows → LWC → layouts)
- Permission set assignment
- Sample data loading
- Post-deploy validation checklist

---

## Brand Guidelines

| Token | Value | Usage |
|-------|-------|-------|
| `--dd-navy` | `#1F4788` | Headers, primary buttons |
| `--dd-blue-mid` | `#2E6DB4` | Secondary elements, links |
| `--dd-gold` | `#C89B2A` | Accents, signature CTAs |
| `--dd-success` | `#1B7A3E` | Active status, confirmed states |
| `--dd-green` | `#006B3C` | PDF headers, section titles |
| `--dd-light-green` | `#8BC34A` | PDF accent bars |

All LWC components import design tokens from `c/ddDesignTokens`.

---

## Roadmap

### Phase 2
- [ ] DocuSign e-signature integration (replace checkbox `Is_Signed__c`)
- [ ] DDCA Rating Engine REST API (real-time rates, replace static rate table)
- [ ] Salesforce Experience Cloud broker self-service portal
- [ ] Renewal quoting workflow with year-over-year comparison

### Phase 3
- [ ] Large Group segment (100+ employees) — plan catalog extension
- [ ] Medicare Supplement product line
- [ ] Individual & Family plan (ACA-compliant)
- [ ] Multi-state group support

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Deploy to a scratch org and test: `bash scripts/01-create-scratch-org.sh`
4. Ensure all Apex tests pass: `sf apex run test --target-org dd-cpq-scratch --code-coverage`
5. Open a pull request against `main`

---

*Built for Delta Dental of California · Enterprise Architecture*
*Salesforce Sales Cloud · API v60.0 · No Managed Packages*
