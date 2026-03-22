#!/bin/bash
# 01-create-scratch-org.sh
# Creates and configures a Delta Dental CPQ scratch org

set -e

ALIAS="dd-cpq-scratch"
DURATION=30

echo "🦷 Creating Delta Dental CPQ scratch org..."
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias "$ALIAS" \
  --duration-days "$DURATION" \
  --set-default

echo "✅ Scratch org created: $ALIAS"
sf org display --target-org "$ALIAS"
