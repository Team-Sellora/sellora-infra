#!/usr/bin/env bash
#
# Creates the five SalesFlow business roles in WSO2 Identity Server 7.x.
#
# Roles are created with ORGANIZATION audience, not Application audience.
# This matters: once IS is registered as the API Manager Key Manager, the SPA's
# OAuth client is created inside IS by APIM via DCR. Application-audience roles
# are scoped to a single application and will not appear in tokens issued to a
# DCR-created client. Organization-audience roles will.
#
# Idempotent — re-running skips roles that already exist.
#
# Usage:  ./seed-roles.sh

set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "ERROR: .env not found. Copy .env.example to .env first."; exit 1; }
# shellcheck disable=SC1091
source .env

AUTH="$IS_ADMIN_USER:$IS_ADMIN_PASS"
ROLES=(CompanyAdmin AreaManager AgencyOperator SalesRep ShopOwner)

# The organization ID is needed as the role audience. Read it from the built-in
# "everyone" role rather than hardcoding it, so this works on a fresh instance.
ORG_ID=$(curl -sk -u "$AUTH" "$IS_HOST/scim2/v2/Roles" | python3 -c "
import sys, json
for r in json.load(sys.stdin).get('Resources', []):
    if r['displayName'] == 'everyone':
        print(r['audience']['value']); break
")

[ -n "$ORG_ID" ] || { echo 'ERROR: could not resolve organization ID.'; exit 1; }
echo "Organization ID: $ORG_ID"
echo

EXISTING=$(curl -sk -u "$AUTH" "$IS_HOST/scim2/v2/Roles" | python3 -c "
import sys, json
print(' '.join(r['displayName'] for r in json.load(sys.stdin).get('Resources', [])))
")

for ROLE in "${ROLES[@]}"; do
  if [[ " $EXISTING " == *" $ROLE "* ]]; then
    echo "  = $ROLE (already exists, skipped)"
    continue
  fi

  CODE=$(curl -sk -u "$AUTH" -X POST "$IS_HOST/scim2/v2/Roles" \
    -H 'Content-Type: application/scim+json' \
    -d "{
      \"schemas\": [\"urn:ietf:params:scim:schemas:extension:2.0:Role\"],
      \"displayName\": \"$ROLE\",
      \"audience\": { \"value\": \"$ORG_ID\", \"type\": \"organization\" }
    }" -o /dev/null -w '%{http_code}')

  if [ "$CODE" = "201" ]; then
    echo "  + $ROLE created"
  else
    echo "  ! $ROLE FAILED (HTTP $CODE)"
  fi
done

echo
echo "Role IDs:"
curl -sk -u "$AUTH" "$IS_HOST/scim2/v2/Roles" | python3 -c "
import sys, json
for r in sorted(json.load(sys.stdin).get('Resources', []), key=lambda x: x['displayName']):
    print('  %-16s %s' % (r['displayName'], r['id']))
"
