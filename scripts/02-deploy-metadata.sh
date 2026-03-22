#!/bin/bash
# 02-deploy-metadata.sh
# Deploys all Delta Dental CPQ metadata in correct dependency order.
# Usage: ./scripts/02-deploy-metadata.sh <org-alias>
# Example: ./scripts/02-deploy-metadata.sh my-sandbox

set -e

TARGET=${1:-"cpq-dev"}

echo "Deploying Delta Dental CPQ to org: $TARGET"

# ── Step 1: Custom Metadata Type definition + ZIP territory records ──────────
echo ""
echo "Step 1: Custom Metadata (ZIP Territories)..."
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
  --target-org "$TARGET" --wait 15

# ── Step 2: Core custom objects (in dependency order) ───────────────────────
echo ""
echo "Step 2: Core Custom Objects..."
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

# ── Step 3: Apex classes (all service classes + test classes) ────────────────
echo ""
echo "Step 3: Apex Classes..."
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
  --metadata ApexClass:DD_CPQController \
  --metadata ApexClass:DD_CPQControllerTest \
  --target-org "$TARGET" --wait 20

# ── Step 4: Trigger ──────────────────────────────────────────────────────────
echo ""
echo "Step 4: Triggers..."
sf project deploy start \
  --metadata ApexTrigger:DD_ContractTrigger \
  --target-org "$TARGET" --wait 10

# ── Step 5: Flows ────────────────────────────────────────────────────────────
echo ""
echo "Step 5: Flows..."
sf project deploy start \
  --metadata Flow:DD_Contract_SignatureApproval \
  --metadata Flow:DD_Contract_DailyStatusCheck \
  --metadata Flow:DD_Quote_SetTerritory \
  --target-org "$TARGET" --wait 15

# ── Step 6: LWC components ───────────────────────────────────────────────────
echo ""
echo "Step 6: LWC Components..."
sf project deploy start \
  --metadata LightningComponentBundle:ddDesignTokens \
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
  --target-org "$TARGET" --wait 20

# ── Step 7: App, tabs, custom labels, permission sets ───────────────────────
echo ""
echo "Step 7: App, Tabs, Labels, Permission Sets..."
sf project deploy start \
  --metadata CustomLabel:DD_CPQ_Labels \
  --metadata CustomTab:DD_Employer__c \
  --metadata CustomTab:DD_Quote__c \
  --metadata CustomTab:DD_Plan__c \
  --metadata CustomTab:DD_PlanBenefit__c \
  --metadata CustomTab:DD_PlanRate__c \
  --metadata CustomTab:DD_Contract__c \
  --metadata CustomTab:DD_Group__c \
  --metadata CustomTab:DD_Proposal__c \
  --metadata CustomTab:DD_Census__c \
  --metadata CustomTab:DD_QuoteLineItem__c \
  --metadata CustomApplication:DD_CPQ_App \
  --metadata PermissionSet:DD_CPQ_Admin \
  --metadata PermissionSet:DD_CPQ_Sales_Rep \
  --target-org "$TARGET" --wait 15

echo ""
echo "Deployment complete! Opening org..."
sf org open --target-org "$TARGET"
