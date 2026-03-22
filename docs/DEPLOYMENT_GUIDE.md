# Delta Dental CPQ — Deployment Guide

> Complete step-by-step instructions for deploying to a new or different Salesforce org.
> Read this fully before starting — **deploy order matters**.

---

## Prerequisites

```bash
# Salesforce CLI (v2+)
npm install -g @salesforce/cli
sf --version   # must be 2.x+

# Verify doctor
sf doctor
```

---

## Quick Deploy (All-in-One)

```bash
# 1. Authenticate to your target org
sf org login web --alias my-org --set-default

# 2. Deploy everything in order
./scripts/02-deploy-metadata.sh my-org

# 3. Load sample plan/rate data
./scripts/03-load-sample-data.sh my-org

# 4. Assign permission sets to your user
./scripts/04-assign-permissions.sh my-org

# 5. Activate the scheduled flow manually
#    Setup → Flows → DD_Contract_DailyStatusCheck → Activate

# 6. Open the org
sf org open --target-org my-org
# App Launcher → Delta Dental CPQ
```

---

## Manual Step-by-Step Deploy

If the all-in-one script fails at any step, run each block individually.
**CRITICAL: Follow this exact order.**

---

### Step 1 — Custom Metadata (ZIP Territories)

```bash
TARGET=my-org

sf project deploy start \
  --metadata CustomObject:DD_ZIP_Territory__mdt \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90001 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90007 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90012 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90025 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90045 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90210 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90401 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_90501 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92037 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92101 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92103 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92108 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92121 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92130 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92374 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92501 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92503 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92602 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92612 \
  --metadata CustomMetadata:DD_ZIP_Territory.ZIP_92701 \
  --target-org "$TARGET" --wait 20
```

---

### Step 2 — Custom Objects

```bash
sf project deploy start \
  --metadata CustomObject:DD_Employer__c \
  --metadata CustomObject:DD_Plan__c \
  --metadata CustomObject:DD_PlanBenefit__c \
  --metadata CustomObject:DD_PlanRate__c \
  --metadata CustomObject:DD_Census__c \
  --metadata CustomObject:DD_Quote__c \
  --metadata CustomObject:DD_QuoteLineItem__c \
  --metadata CustomObject:DD_Proposal__c \
  --metadata CustomObject:DD_Group__c \
  --metadata CustomObject:DD_Contract__c \
  --target-org "$TARGET" --wait 20
```

---

### Step 3 — Static Resources

```bash
sf project deploy start \
  --metadata StaticResource:DD_Logo \
  --target-org "$TARGET" --wait 10
```

---

### Step 4 — Apex Service Classes

```bash
sf project deploy start \
  --metadata ApexClass:DD_CPQException \
  --metadata ApexClass:DD_TerritoryService \
  --metadata ApexClass:DD_TerritoryServiceTest \
  --metadata ApexClass:DD_RateService \
  --metadata ApexClass:DD_RateServiceTest \
  --metadata ApexClass:DD_PlanService \
  --metadata ApexClass:DD_PlanServiceTest \
  --metadata ApexClass:DD_QuoteService \
  --metadata ApexClass:DD_QuoteServiceTest \
  --metadata ApexClass:DD_ProposalService \
  --metadata ApexClass:DD_ProposalServiceTest \
  --metadata ApexClass:DD_ContractService \
  --metadata ApexClass:DD_ContractServiceTest \
  --target-org "$TARGET" --wait 20
```

---

### Step 5 — PDF Apex Controllers

```bash
sf project deploy start \
  --metadata ApexClass:DD_ProposalPDFController \
  --metadata ApexClass:DD_ContractPDFController \
  --target-org "$TARGET" --wait 10
```

---

### Step 6 — Main CPQ Controller

```bash
sf project deploy start \
  --metadata ApexClass:DD_CPQController \
  --metadata ApexClass:DD_CPQControllerTest \
  --target-org "$TARGET" --wait 20
```

---

### Step 7 — Visualforce PDF Pages

```bash
sf project deploy start \
  --metadata ApexPage:DD_ProposalPDF \
  --metadata ApexPage:DD_ContractPDF \
  --target-org "$TARGET" --wait 10
```

---

### Step 8 — Apex Trigger

```bash
sf project deploy start \
  --metadata ApexTrigger:DD_ContractTrigger \
  --target-org "$TARGET" --wait 10
```

---

### Step 9 — Flows

```bash
sf project deploy start \
  --metadata Flow:DD_Contract_SignatureApproval \
  --metadata Flow:DD_Contract_DailyStatusCheck \
  --metadata Flow:DD_Quote_SetTerritory \
  --target-org "$TARGET" --wait 20
```

---

### Step 10 — LWC Components

```bash
# Design tokens first
sf project deploy start \
  --metadata LightningComponentBundle:ddDesignTokens \
  --target-org "$TARGET" --wait 10

# Core wizard components
sf project deploy start \
  --metadata LightningComponentBundle:ddBrandedHeader \
  --metadata LightningComponentBundle:ddGuidedSelling \
  --metadata LightningComponentBundle:ddPlanSelector \
  --metadata LightningComponentBundle:ddRateConfigurator \
  --metadata LightningComponentBundle:ddQuoteSummary \
  --metadata LightningComponentBundle:ddProposalViewer \
  --metadata LightningComponentBundle:ddGroupManager \
  --metadata LightningComponentBundle:ddContractManager \
  --metadata LightningComponentBundle:ddPdfGenerator \
  --target-org "$TARGET" --wait 20

# Sub-components
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteAction \
  --metadata LightningComponentBundle:ddQuoteModal \
  --target-org "$TARGET" --wait 10

# Action + page components
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteStandaloneAction \
  --metadata LightningComponentBundle:ddQuoteRelatedGroups \
  --metadata LightningComponentBundle:ddGenerateProposalAction \
  --metadata LightningComponentBundle:ddCreateContractAction \
  --target-org "$TARGET" --wait 10

# Parent wizard (must be last — depends on all children)
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteWizard \
  --target-org "$TARGET" --wait 10
```

---

### Step 11 — Aura Component

```bash
# Wraps ddQuoteStandaloneAction for standard New button override on Quote
sf project deploy start \
  --metadata AuraDefinitionBundle:ddNewQuoteAction \
  --target-org "$TARGET" --wait 10
```

---

### Step 12 — Quick Actions

```bash
sf project deploy start \
  --metadata QuickAction:DD_Employer__c.New_Quote \
  --metadata QuickAction:DD_Quote__c.New_Quote \
  --metadata QuickAction:DD_Quote__c.Generate_Proposal \
  --metadata QuickAction:DD_Group__c.Create_Contract \
  --target-org "$TARGET" --wait 10
```

---

### Step 13 — Page Layouts

```bash
sf project deploy start \
  --metadata Layout:"DD_Employer__c-Employer Layout" \
  --metadata Layout:"DD_Plan__c-Plan Layout" \
  --metadata Layout:"DD_PlanBenefit__c-Plan Benefit Layout" \
  --metadata Layout:"DD_PlanRate__c-Plan Rate Layout" \
  --metadata Layout:"DD_Quote__c-Quote Layout" \
  --metadata Layout:"DD_Proposal__c-Proposal Layout" \
  --metadata Layout:"DD_Group__c-Group Layout" \
  --metadata Layout:"DD_Contract__c-Contract Layout" \
  --target-org "$TARGET" --wait 20
```

---

### Step 14 — Quote Object (New button override)

```bash
# Must deploy AFTER ddNewQuoteAction Aura bundle
sf project deploy start \
  --metadata CustomObject:DD_Quote__c \
  --target-org "$TARGET" --wait 10
```

---

### Step 15 — Tabs, App, Permission Sets

```bash
sf project deploy start \
  --metadata CustomTab:DD_Employer__c \
  --metadata CustomTab:DD_Quote__c \
  --metadata CustomTab:DD_Plan__c \
  --metadata CustomTab:DD_PlanBenefit__c \
  --metadata CustomTab:DD_PlanRate__c \
  --metadata CustomTab:DD_Contract__c \
  --metadata CustomTab:DD_Group__c \
  --metadata CustomTab:DD_Proposal__c \
  --metadata CustomTab:DD_Census__c \
  --metadata CustomTab:DD_New_Quote \
  --target-org "$TARGET" --wait 10

sf project deploy start \
  --metadata CustomApplication:DD_CPQ_App \
  --metadata PermissionSet:DD_CPQ_Admin \
  --metadata PermissionSet:DD_CPQ_Sales_Rep \
  --target-org "$TARGET" --wait 10
```

---

## Sample Data

```bash
# Load plans, benefits, and rates in one call
# (cross-references between files require same API request)
sf data import tree \
  --files data/sample-plans.json \
  --files data/sample-benefits.json \
  --files data/sample-rates.json \
  --target-org "$TARGET"

# Verify
sf data query --query "SELECT COUNT() FROM DD_Plan__c"        --target-org "$TARGET"
sf data query --query "SELECT COUNT() FROM DD_PlanBenefit__c" --target-org "$TARGET"
sf data query --query "SELECT COUNT() FROM DD_PlanRate__c"    --target-org "$TARGET"
```

---

## Permission Set Assignment

```bash
# Assign Admin to current deploying user
sf org assign permset --name DD_CPQ_Admin --target-org "$TARGET"

# Assign to additional users
sf org assign permset \
  --name DD_CPQ_Sales_Rep \
  --on-behalf-of rep@yourorg.com \
  --target-org "$TARGET"
```

---

## Post-Deploy Checklist

- [ ] All 15 deploy steps completed with no errors
- [ ] Sample data loaded: Plans (6), Benefits, Rates
- [ ] `DD_CPQ_Admin` permission set assigned to deploying user
- [ ] Navigate to Setup → Flows → `DD_Contract_DailyStatusCheck` → **Activate**
- [ ] Open org → App Launcher → **Delta Dental CPQ** is visible
- [ ] Create a test Employer record
- [ ] Click **New** on Quotes tab → Quote wizard opens (not default New form)
- [ ] Click **Generate Proposal** on a Quote → PDF saved to Files
- [ ] Click **Create Contract** on a Group → Contract record created + PDF in Files

---

## Known Issues & Fixes

### "Missing message metadata.transfer:Finalizing"

SOAP API intermittent timeout. **Simply retry the same command** — it succeeds on the second attempt.

```bash
# If this error occurs, just run the same deploy command again
sf project deploy start --metadata ... --target-org "$TARGET"
```

### Deploy shows "Unchanged" but org has old version

The DX local cache hash matches the previously-deployed version. To force-verify what's actually in the org:

```bash
# Retrieve current org version and check content
sf project retrieve start --metadata ApexClass:DD_CPQController --target-org "$TARGET"
grep -n "methodName" force-app/main/default/classes/DD_CPQController.cls
```

### "You can't add QuickActionType LightningWebComponent to a QuickActionList"

LWC Quick Actions must be added via `<platformActionList>` in layout XML, **not** `<quickActionList>`. The Group and Contract layouts already use the correct format. Do not change them to `quickActionList`.

### "LightningWebComponent not a valid ActionOverrideType"

Standard button overrides (like the New button on Quote) require an **Aura** component that implements `lightning:actionOverride`. The `ddNewQuoteAction` Aura bundle wraps `ddQuoteStandaloneAction` LWC for this purpose. Do not try to use LWC directly as an actionOverride.

### PageReference.getContent() "List has no rows for assignment to SObject"

`getContent()` renders VF pages via a separate HTTP request in a new transaction. Records inserted in the **current** transaction are not visible. Always pass IDs of **already-committed** records to VF pages used for PDF generation. The `DD_ContractPDF.page` uses `groupId` (existing record) not `contractId` (newly inserted) for this reason.

### Flow activation fails on deploy

Flows sometimes must be activated manually after deploy:
- Setup → Flows → `DD_Contract_DailyStatusCheck` → Activate

### "No WebLink named X found" for listViewButtons

LWC Screen Actions cannot be added as list view buttons. They are Quick Actions on record pages only.

---

## Useful Debug Commands

```bash
# Check what's in the org vs local
sf project retrieve start --metadata ApexClass:DD_CPQController --target-org "$TARGET"

# Run all Apex tests
sf apex run test \
  --target-org "$TARGET" \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 10

# View Apex logs
sf apex tail log --target-org "$TARGET"

# Query data
sf data query --query "SELECT Id, Name, Status__c FROM DD_Quote__c LIMIT 5" --target-org "$TARGET"
sf data query --query "SELECT Id, Name, Status__c FROM DD_Contract__c LIMIT 5" --target-org "$TARGET"
sf data query --query "SELECT Id, Name, Status__c FROM DD_Group__c LIMIT 5" --target-org "$TARGET"

# Check deployment status
sf project deploy report --target-org "$TARGET"
```

---

## Full Component Inventory

### Custom Objects (10)
| Object | API Name |
|--------|----------|
| Employer | `DD_Employer__c` |
| Plan | `DD_Plan__c` |
| Plan Benefit | `DD_PlanBenefit__c` |
| Plan Rate | `DD_PlanRate__c` |
| Census | `DD_Census__c` |
| Quote | `DD_Quote__c` |
| Quote Line Item | `DD_QuoteLineItem__c` |
| Proposal | `DD_Proposal__c` |
| Group | `DD_Group__c` |
| Contract | `DD_Contract__c` |

### Apex Classes (16)
| Class | Type |
|-------|------|
| `DD_CPQException` | Exception |
| `DD_TerritoryService` + Test | Service |
| `DD_RateService` + Test | Service |
| `DD_PlanService` + Test | Service |
| `DD_QuoteService` + Test | Service |
| `DD_ProposalService` + Test | Service |
| `DD_ContractService` + Test | Service |
| `DD_ProposalPDFController` | VF Controller |
| `DD_ContractPDFController` | VF Controller |
| `DD_CPQController` + Test | LWC Controller |

### Visualforce Pages (2)
| Page | Purpose |
|------|---------|
| `DD_ProposalPDF` | Branded proposal PDF — renders from Quote + QuoteLineItems |
| `DD_ContractPDF` | Contract PDF with benefit schedule — renders from Group + Source Quote |

### LWC Components (16)
| Component | Purpose |
|-----------|---------|
| `ddDesignTokens` | Shared DDCA CSS design tokens |
| `ddBrandedHeader` | Global branded nav bar |
| `ddGuidedSelling` | Wizard step 1: employer info |
| `ddPlanSelector` | Wizard step 2: plan grid + compare |
| `ddRateConfigurator` | Wizard step 3: tier counts + contribution |
| `ddQuoteSummary` | Wizard step 4: premium breakdown |
| `ddProposalViewer` | Proposal preview + PDF link |
| `ddGroupManager` | Group enrollment form |
| `ddContractManager` | Contract details + signature |
| `ddPdfGenerator` | PDF generation trigger |
| `ddQuoteWizard` | Parent 6-step wizard |
| `ddQuoteAction` | Quote action sub-component |
| `ddQuoteModal` | Quote modal sub-component |
| `ddQuoteStandaloneAction` | New Quote as RecordAction (ScreenAction) |
| `ddQuoteRelatedGroups` | Groups related list on Quote |
| `ddGenerateProposalAction` | Generate Proposal screen action on Quote |
| `ddCreateContractAction` | Create Contract screen action on Group |

### Aura Components (1)
| Component | Purpose |
|-----------|---------|
| `ddNewQuoteAction` | Wraps `ddQuoteStandaloneAction` for standard New button override on Quote (`lightning:actionOverride`) |

### Quick Actions (4)
| Action | Object | LWC |
|--------|--------|-----|
| `New_Quote` | `DD_Employer__c` | `ddQuoteStandaloneAction` |
| `New_Quote` | `DD_Quote__c` | `ddQuoteStandaloneAction` |
| `Generate_Proposal` | `DD_Quote__c` | `ddGenerateProposalAction` |
| `Create_Contract` | `DD_Group__c` | `ddCreateContractAction` |

### Page Layouts (8)
| Layout |
|--------|
| `DD_Employer__c-Employer Layout` |
| `DD_Plan__c-Plan Layout` |
| `DD_PlanBenefit__c-Plan Benefit Layout` |
| `DD_PlanRate__c-Plan Rate Layout` |
| `DD_Quote__c-Quote Layout` — includes Quote Line Items, Proposals, Groups related lists + Generate Proposal + New Quote actions |
| `DD_Proposal__c-Proposal Layout` — includes Files related list |
| `DD_Group__c-Group Layout` — includes Contracts related list + Create Contract action |
| `DD_Contract__c-Contract Layout` — includes Files related list (contract PDF appears here) |

### Flows (3)
| Flow | Type | Purpose |
|------|------|---------|
| `DD_Contract_SignatureApproval` | Record-Triggered | `Is_Signed__c = true` → Status = Approved |
| `DD_Contract_DailyStatusCheck` | Scheduled | Activate approved / expire ended contracts |
| `DD_Quote_SetTerritory` | Record-Triggered | ZIP change → populate Rate_Territory__c |
