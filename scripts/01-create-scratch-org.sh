#!/bin/bash
# 01-create-scratch-org.sh
# Creates a Delta Dental CPQ scratch org, deploys all metadata, loads data,
# and assigns permissions. Run from the dd-cpq project root.
#
# Usage:   ./scripts/01-create-scratch-org.sh [alias] [duration-days]
# Example: ./scripts/01-create-scratch-org.sh dd-cpq-scratch 30
#
# Prerequisites:
#   - Salesforce CLI installed: npm install -g @salesforce/cli
#   - Dev Hub authenticated: sf org login web --alias dev-hub --set-default-dev-hub

set -e

ALIAS="${1:-dd-cpq-scratch}"
DURATION="${2:-30}"

echo "======================================================"
echo " Delta Dental CPQ — Scratch Org Setup"
echo " Alias: $ALIAS  |  Duration: ${DURATION} days"
echo "======================================================"

# Verify Dev Hub is available
sf org list --filter devhubs 2>/dev/null | grep -q "DevHub" || {
  echo "No Dev Hub found. Authenticate first:"
  echo "  sf org login web --alias dev-hub --set-default-dev-hub"
  exit 1
}

echo ""
echo "► Creating scratch org..."
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias "$ALIAS" \
  --duration-days "$DURATION" \
  --set-default

echo ""
echo "► Scratch org created:"
sf org display --target-org "$ALIAS"

echo ""
echo "► Deploying all metadata..."
./scripts/02-deploy-metadata.sh "$ALIAS"

echo ""
echo "► Loading sample data..."
./scripts/03-load-sample-data.sh "$ALIAS"

echo ""
echo "► Assigning permission sets..."
./scripts/04-assign-permissions.sh "$ALIAS"

echo ""
echo "======================================================"
echo " Setup complete! Opening org..."
echo "======================================================"
sf org open --target-org "$ALIAS"
