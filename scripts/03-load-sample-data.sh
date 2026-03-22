#!/bin/bash
# 03-load-sample-data.sh
# Loads Delta Dental CPQ sample plans, benefits, and rates.
# Usage: ./scripts/03-load-sample-data.sh <org-alias>
# Example: ./scripts/03-load-sample-data.sh my-sandbox
#
# NOTE: Plans, benefits, and rates are imported in a single composite call so
# that @PlanRef cross-references resolve correctly. Do NOT split into separate
# imports — the cross-file references only resolve within the same API request.

set -e

TARGET=${1:-"cpq-dev"}

echo "Loading Delta Dental CPQ sample data to: $TARGET"

# Import plans + child benefits + rates in one composite request.
# Cross-references (@PlanRef1 … @PlanRef6) in benefits and rates resolve
# to the plan records created in the same transaction.
echo ""
echo "Importing plans, benefits, and rates..."
sf data import tree \
  --files data/sample-plans.json \
  --files data/sample-benefits.json \
  --files data/sample-rates.json \
  --target-org "$TARGET"

echo ""
echo "Sample data loaded. Record counts:"
sf data query --query "SELECT COUNT() FROM DD_Plan__c"        --target-org "$TARGET"
sf data query --query "SELECT COUNT() FROM DD_PlanBenefit__c" --target-org "$TARGET"
sf data query --query "SELECT COUNT() FROM DD_PlanRate__c"    --target-org "$TARGET"
