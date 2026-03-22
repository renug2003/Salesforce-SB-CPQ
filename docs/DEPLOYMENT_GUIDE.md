# Delta Dental CPQ — Deployment Guide
## Step-by-Step Instructions for Claude Code / VS Code

---

## Prerequisites

Install these before starting:

```bash
# 1. Node.js (v18+)
node --version

# 2. Salesforce CLI
npm install -g @salesforce/cli
sf --version

# 3. Verify CLI
sf doctor
```

---

## PHASE 1: Setup (Run Once)

### Step 1.1 — Clone / Open Project in VS Code
Open the `dd-cpq` folder in VS Code with the Claude Code extension enabled.

### Step 1.2 — Authenticate to Your Salesforce Org

**For a Developer/Sandbox org:**
```bash
sf org login web --alias dd-cpq-dev --set-default
```

**To create a scratch org (recommended for development):**
```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dd-cpq-scratch \
  --duration-days 30 \
  --set-default
```

**Verify connection:**
```bash
sf org display --target-org dd-cpq-dev
```

---

## PHASE 2: Deploy Metadata

### Step 2.1 — Deploy Custom Metadata Types First
```bash
sf project deploy start \
  --metadata CustomObject:DD_ZIP_Territory__mdt \
  --target-org dd-cpq-dev
```

### Step 2.2 — Deploy All Custom Objects
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
  --target-org dd-cpq-dev
```

### Step 2.3 — Deploy Apex Classes
```bash
sf project deploy start \
  --metadata ApexClass:DD_CPQException \
  --metadata ApexClass:DD_TerritoryService \
  --metadata ApexClass:DD_RateService \
  --metadata ApexClass:DD_QuoteService \
  --metadata ApexClass:DD_ProposalService \
  --metadata ApexClass:DD_CPQController \
  --target-org dd-cpq-dev
```

### Step 2.4 — Deploy Apex Triggers
```bash
sf project deploy start \
  --metadata ApexTrigger:DD_ContractTrigger \
  --target-org dd-cpq-dev
```

### Step 2.5 — Deploy Flows
```bash
sf project deploy start \
  --metadata Flow:DD_Contract_SignatureApproval \
  --metadata Flow:DD_Contract_DailyStatusCheck \
  --metadata Flow:DD_Quote_SetTerritory \
  --target-org dd-cpq-dev
```

### Step 2.6 — Deploy LWC Components
```bash
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
  --metadata LightningComponentBundle:ddQuoteWizard \
  --target-org dd-cpq-dev
```

### Step 2.7 — Deploy App, Tabs & Permission Sets
```bash
sf project deploy start \
  --metadata CustomTab:DD_Employer__c \
  --metadata CustomTab:DD_Quote__c \
  --metadata CustomTab:DD_Plan__c \
  --metadata CustomTab:DD_Contract__c \
  --metadata CustomTab:DD_Group__c \
  --metadata CustomApplication:DD_CPQ_App \
  --metadata PermissionSet:DD_CPQ_Admin \
  --metadata PermissionSet:DD_CPQ_Sales_Rep \
  --target-org dd-cpq-dev
```

### Step 2.8 — Deploy Everything at Once (Shortcut)
```bash
sf project deploy start \
  --source-dir force-app \
  --target-org dd-cpq-dev \
  --wait 30
```

---

## PHASE 3: Load Sample Data

### Step 3.1 — Load ZIP Territory Mappings (Custom Metadata)
Custom Metadata records are deployed as metadata — they're already included in the deploy above via `/force-app/main/default/customMetadata/`.

### Step 3.2 — Load Sample Plans
```bash
sf data import tree \
  --files data/sample-plans.json \
  --target-org dd-cpq-dev
```

### Step 3.3 — Load Plan Benefits
```bash
sf data import tree \
  --files data/sample-benefits.json \
  --target-org dd-cpq-dev
```

### Step 3.4 — Load Sample Rates
```bash
sf data import tree \
  --files data/sample-rates.json \
  --target-org dd-cpq-dev
```

---

## PHASE 4: Configure Org

### Step 4.1 — Assign Permission Sets
```bash
# Assign admin permission set to your user
sf org assign permset \
  --name DD_CPQ_Admin \
  --target-org dd-cpq-dev

# Or for a sales rep
sf org assign permset \
  --name DD_CPQ_Sales_Rep \
  --on-behalf-of someuser@example.com \
  --target-org dd-cpq-dev
```

### Step 4.2 — Activate the Scheduled Flow
Navigate to Setup → Flows → `DD_Contract_DailyStatusCheck` → Activate

### Step 4.3 — Open the Org
```bash
sf org open --target-org dd-cpq-dev
```

Navigate to: **App Launcher → Delta Dental CPQ**

---

## PHASE 5: Run Tests

```bash
# Run all CPQ tests
sf apex run test \
  --target-org dd-cpq-dev \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 10

# Run specific test class
sf apex run test \
  --target-org dd-cpq-dev \
  --class-names DD_CPQControllerTest \
  --result-format human
```

---

## Troubleshooting

### Common Issues

**"Cannot find object" error on deploy:**
```bash
# Check API version
sf project generate manifest --source-dir force-app
# Ensure sfdx-project.json sourceApiVersion matches org API version
```

**Flow activation fails:**
- Navigate to Setup → Flows manually
- Ensure all referenced objects are deployed first
- Check for any missing field references

**LWC components not appearing in App Builder:**
- Verify `isExposed: true` in `js-meta.xml`
- Check target configuration matches your page type

**Permission errors on Apex:**
```bash
# Check FLS on objects
sf org describe metadata --metadata CustomField --target-org dd-cpq-dev
```

**Scheduled flow not running:**
- Go to Setup → Scheduled Jobs to verify the flow is queued
- Check System → Apex Jobs for any failures

### Useful Debug Commands

```bash
# View deployment status
sf project deploy report --target-org dd-cpq-dev

# Check org limits
sf limits api display --target-org dd-cpq-dev

# View recent Apex logs
sf apex tail log --target-org dd-cpq-dev

# Query sample data
sf data query \
  --query "SELECT Id, Name, Plan_Code__c, Is_Active__c FROM DD_Plan__c" \
  --target-org dd-cpq-dev

# Query quotes
sf data query \
  --query "SELECT Id, Name, Status__c, Total_Monthly_Premium__c FROM DD_Quote__c" \
  --target-org dd-cpq-dev
```

---

## Directory Reference

```
dd-cpq/
├── CLAUDE.md                          ← Claude Code agent instructions
├── sfdx-project.json                  ← Project configuration
├── config/
│   └── project-scratch-def.json       ← Scratch org definition
├── docs/
│   ├── SPECIFICATION.md               ← Full solution spec
│   └── DEPLOYMENT_GUIDE.md            ← This file
├── data/
│   ├── sample-plans.json              ← DDCA plan catalog seed data
│   ├── sample-benefits.json           ← Plan benefits seed data
│   └── sample-rates.json              ← Rate table seed data
├── scripts/
│   ├── 01-create-scratch-org.sh       ← Scratch org setup
│   ├── 02-deploy-metadata.sh          ← Full deploy script
│   ├── 03-load-sample-data.sh         ← Data load script
│   └── 04-assign-permissions.sh       ← Permission assignment
└── force-app/main/default/
    ├── objects/                        ← 10 custom objects
    ├── classes/                        ← Apex service layer
    ├── triggers/                       ← Contract trigger
    ├── flows/                          ← Contract lifecycle flows
    ├── lwc/                            ← 10 LWC components
    ├── customMetadata/                 ← ZIP territory mappings
    ├── permissionsets/                 ← 4 permission sets
    ├── tabs/                           ← Custom tabs
    └── applications/                   ← DD CPQ Lightning app
```

---

## Contract Lifecycle Testing

After deployment, test the contract lifecycle:

```bash
# 1. Create a test contract via UI or:
sf data create record \
  --sobject DD_Contract__c \
  --values "Employer__c=<employer_id> Start_Date__c=2025-07-01 End_Date__c=2026-06-30 Status__c=Draft" \
  --target-org dd-cpq-dev

# 2. Sign it (triggers the approval flow):
sf data update record \
  --sobject DD_Contract__c \
  --record-id <contract_id> \
  --values "Is_Signed__c=true Signed_Date__c=2025-06-01 Signed_By_Name__c='John Smith' Signed_By_Title__c='CEO'" \
  --target-org dd-cpq-dev

# 3. Verify status changed to Approved:
sf data query \
  --query "SELECT Id, Name, Status__c, Is_Signed__c FROM DD_Contract__c WHERE Id='<contract_id>'" \
  --target-org dd-cpq-dev
```
