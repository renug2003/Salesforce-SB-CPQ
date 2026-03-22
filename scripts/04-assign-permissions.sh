#!/bin/bash
# 04-assign-permissions.sh
# Assigns DD CPQ permission sets to the current (deploying) user.
# Usage: ./scripts/04-assign-permissions.sh <org-alias>
# Example: ./scripts/04-assign-permissions.sh my-sandbox
#
# To assign to additional users:
#   sf org assign permset --name DD_CPQ_Admin    --on-behalf-of user@example.com --target-org <alias>
#   sf org assign permset --name DD_CPQ_Sales_Rep --on-behalf-of user@example.com --target-org <alias>

set -e

TARGET=${1:-"cpq-dev"}

echo "Assigning DD CPQ permission sets to current user (org: $TARGET)..."

# Assign Admin permission set — ignore duplicate assignment errors (idempotent).
sf org assign permset \
  --name DD_CPQ_Admin \
  --target-org "$TARGET" 2>&1 | grep -v "Duplicate PermissionSetAssignment" || true

echo "DD_CPQ_Admin assigned."

echo ""
echo "To assign Sales Rep permissions to another user:"
echo "  sf org assign permset --name DD_CPQ_Sales_Rep --on-behalf-of user@example.com --target-org $TARGET"
