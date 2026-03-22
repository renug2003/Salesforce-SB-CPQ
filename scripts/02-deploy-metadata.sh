#!/bin/bash
# 02-deploy-metadata.sh
# Deploys ALL Delta Dental CPQ metadata to a target org in correct dependency order.
#
# Usage:   ./scripts/02-deploy-metadata.sh <org-alias>
# Example: ./scripts/02-deploy-metadata.sh my-sandbox
#
# IMPORTANT — Deploy order must be respected:
#   1. Custom Metadata (ZIP territories)
#   2. Custom Objects (dependency order)
#   3. Static Resources
#   4. Apex Classes (service layer first, then controllers, then tests)
#   5. Visualforce Pages (depend on Apex controllers)
#   6. Apex Triggers (depend on objects + service classes)
#   7. Flows (depend on objects + Apex)
#   8. LWC Components (depend on Apex controllers)
#   9. Aura Components (depend on LWC)
#  10. Quick Actions (depend on LWC/Aura)
#  11. Page Layouts (depend on Quick Actions)
#  12. App, Tabs, Permission Sets

set -e

TARGET=${1:-"dd-cpq-dev"}
WAIT=20

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}► Step $1: $2${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✖ FAILED: $1${NC}"; exit 1; }

echo "======================================================"
echo " Delta Dental CPQ — Full Deployment"
echo " Target org: $TARGET"
echo "======================================================"

# Verify org is accessible
sf org display --target-org "$TARGET" > /dev/null 2>&1 || \
  fail "Cannot connect to org '$TARGET'. Run: sf org login web --alias $TARGET"

# ─────────────────────────────────────────────────────────────────────────────
step 1 "Custom Metadata Type + ZIP Territory records"
# ─────────────────────────────────────────────────────────────────────────────
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
  --target-org "$TARGET" --wait $WAIT

# ─────────────────────────────────────────────────────────────────────────────
step 2 "Custom Objects (dependency order)"
# ─────────────────────────────────────────────────────────────────────────────
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
  --target-org "$TARGET" --wait $WAIT

# ─────────────────────────────────────────────────────────────────────────────
step 3 "Static Resources"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata StaticResource:DD_Logo \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 4 "Custom Labels"
# ─────────────────────────────────────────────────────────────────────────────
# Deploy labels directory if it exists and has content
if ls force-app/main/default/labels/*.xml 2>/dev/null | grep -q .; then
  sf project deploy start \
    --source-dir force-app/main/default/labels \
    --target-org "$TARGET" --wait 10
else
  warn "No custom labels found — skipping."
fi

# ─────────────────────────────────────────────────────────────────────────────
step 5 "Apex Classes (service layer + controllers + test classes)"
# ─────────────────────────────────────────────────────────────────────────────
# Service classes first (no cross-dependencies between services)
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
  --target-org "$TARGET" --wait $WAIT

# PDF controllers (depend on objects, not on services)
sf project deploy start \
  --metadata ApexClass:DD_ProposalPDFController \
  --metadata ApexClass:DD_ContractPDFController \
  --target-org "$TARGET" --wait 10

# Main LWC controller (depends on all service classes)
sf project deploy start \
  --metadata ApexClass:DD_CPQController \
  --metadata ApexClass:DD_CPQControllerTest \
  --target-org "$TARGET" --wait $WAIT

# ─────────────────────────────────────────────────────────────────────────────
step 6 "Visualforce Pages (depend on PDF controllers)"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata ApexPage:DD_ProposalPDF \
  --metadata ApexPage:DD_ContractPDF \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 7 "Apex Trigger"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata ApexTrigger:DD_ContractTrigger \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 8 "Flows"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata Flow:DD_Contract_SignatureApproval \
  --metadata Flow:DD_Contract_DailyStatusCheck \
  --metadata Flow:DD_Quote_SetTerritory \
  --target-org "$TARGET" --wait $WAIT

# ─────────────────────────────────────────────────────────────────────────────
step 9 "LWC Components"
# ─────────────────────────────────────────────────────────────────────────────
# Design tokens first (other components import them)
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
  --target-org "$TARGET" --wait $WAIT

# Quote wizard sub-components
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteAction \
  --metadata LightningComponentBundle:ddQuoteModal \
  --target-org "$TARGET" --wait 10

# Standalone action components and page components
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteStandaloneAction \
  --metadata LightningComponentBundle:ddQuoteRelatedGroups \
  --metadata LightningComponentBundle:ddGenerateProposalAction \
  --metadata LightningComponentBundle:ddCreateContractAction \
  --target-org "$TARGET" --wait 10

# Parent wizard (depends on all child components above)
sf project deploy start \
  --metadata LightningComponentBundle:ddQuoteWizard \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 10 "Aura Components (depend on LWC)"
# ─────────────────────────────────────────────────────────────────────────────
# ddNewQuoteAction wraps ddQuoteStandaloneAction for standard New button override
sf project deploy start \
  --metadata AuraDefinitionBundle:ddNewQuoteAction \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 11 "Quick Actions (depend on LWC/Aura)"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata QuickAction:DD_Employer__c.New_Quote \
  --metadata QuickAction:DD_Quote__c.New_Quote \
  --metadata QuickAction:DD_Quote__c.Generate_Proposal \
  --metadata QuickAction:DD_Group__c.Create_Contract \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 12 "Page Layouts (depend on Quick Actions)"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata Layout:"DD_Employer__c-Employer Layout" \
  --metadata Layout:"DD_Plan__c-Plan Layout" \
  --metadata Layout:"DD_PlanBenefit__c-Plan Benefit Layout" \
  --metadata Layout:"DD_PlanRate__c-Plan Rate Layout" \
  --metadata Layout:"DD_Quote__c-Quote Layout" \
  --metadata Layout:"DD_Proposal__c-Proposal Layout" \
  --metadata Layout:"DD_Group__c-Group Layout" \
  --metadata Layout:"DD_Contract__c-Contract Layout" \
  --target-org "$TARGET" --wait $WAIT

# ─────────────────────────────────────────────────────────────────────────────
step 13 "DD_Quote__c Object (New button override via Aura)"
# ─────────────────────────────────────────────────────────────────────────────
# This sets actionOverride on Quote object pointing to ddNewQuoteAction.
# Must deploy AFTER the Aura component.
sf project deploy start \
  --metadata CustomObject:DD_Quote__c \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
step 14 "Tabs, App, Permission Sets"
# ─────────────────────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────────────────────
step 15 "Lightning Experience Theme (Delta Dental Green)"
# ─────────────────────────────────────────────────────────────────────────────
sf project deploy start \
  --metadata BrandingSet:DD_CPQ_BrandingSet \
  --metadata LightningExperienceTheme:DD_CPQ_Theme \
  --target-org "$TARGET" --wait 10

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo -e "${GREEN} Deployment complete!${NC}"
echo "======================================================"
echo ""
echo "Next steps:"
echo "  1. Load sample data:     ./scripts/03-load-sample-data.sh $TARGET"
echo "  2. Assign permissions:   ./scripts/04-assign-permissions.sh $TARGET"
echo "  3. Activate theme:       Setup → Themes and Branding → DD CPQ Theme → Activate"
echo "  4. Activate daily flow:  Setup → Flows → DD_Contract_DailyStatusCheck → Activate"
echo "  4. Open org:             sf org open --target-org $TARGET"
echo ""
