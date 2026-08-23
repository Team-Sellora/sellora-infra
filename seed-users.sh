#!/usr/bin/env bash
#
# Creates one test user per SalesFlow role, sets the companyId tenant claim,
# and assigns each user to its role.
#
# Run seed-roles.sh first.
#
# NOTE on schema URNs — these are deliberately inconsistent and it is easy to
# "correct" them into something broken:
#   core schema   -> urn:ietf:params:scim:schemas:core:2.0:User   (with ietf:params)
#   custom schema -> urn:scim:schemas:extension:custom:User       (WITHOUT ietf:params)
# Using the ietf form for the custom extension makes IS accept the request and
# silently discard companyId. Confirm against /scim2/Schemas if this ever breaks.
#
# Usage:  ./seed-users.sh

set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || { echo "ERROR: .env not found. Copy .env.example to .env first." >&2; exit 1; }
# shellcheck disable=SC1091
source .env

AUTH="$IS_ADMIN_USER:$IS_ADMIN_PASS"

# username:givenName:role
USERS=(
  "companyadmin1:Company:CompanyAdmin"
  "areamanager1:Area:AreaManager"
  "agencyop1:Agency:AgencyOperator"
  "salesrep1:Sales:SalesRep"
  "shopowner1:Shop:ShopOwner"
)

role_id () {
  local name="$1"
  curl -sk -u "$AUTH" "$IS_HOST/scim2/v2/Roles" | python3 -c "
import sys, json
for r in json.load(sys.stdin).get('Resources', []):
    if r['displayName'] == '$name':
        print(r['id']); break
"
}

user_id () {
  local name="$1"
  curl -sk -u "$AUTH" "$IS_HOST/scim2/Users?filter=userName+eq+$name" | python3 -c "
import sys, json
r = json.load(sys.stdin).get('Resources', [])
print(r[0]['id'] if r else '')
"
}

for ENTRY in "${USERS[@]}"; do
  IFS=':' read -r UNAME GIVEN ROLE <<< "$ENTRY"

  UID_EXISTING=$(user_id "$UNAME")
  if [[ -n "$UID_EXISTING" ]]; then
    echo "  = $UNAME (already exists, skipped)"
    UID_VAL="$UID_EXISTING"
  else
    UID_VAL=$(curl -sk -u "$AUTH" -X POST "$IS_HOST/scim2/Users" \
      -H 'Content-Type: application/scim+json' \
      -d "{
        \"schemas\": [\"urn:ietf:params:scim:schemas:core:2.0:User\"],
        \"userName\": \"$UNAME\",
        \"password\": \"$SEED_USER_PASSWORD\",
        \"name\": { \"givenName\": \"$GIVEN\", \"familyName\": \"User\" },
        \"emails\": [{ \"primary\": true, \"value\": \"$UNAME@test.local\" }],
        \"urn:scim:schemas:extension:custom:User\": { \"companyId\": \"$SEED_COMPANY_ID\" }
      }" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")

    [[ -n "$UID_VAL" ]] || { echo "  ! $UNAME FAILED to create" >&2; continue; }
    echo "  + $UNAME created ($UID_VAL)"
  fi

  RID=$(role_id "$ROLE")
  [[ -n "$RID" ]] || { echo "  ! role $ROLE not found — run seed-roles.sh first" >&2; continue; }

  CODE=$(curl -sk -u "$AUTH" -X PATCH "$IS_HOST/scim2/v2/Roles/$RID" \
    -H 'Content-Type: application/scim+json' \
    -d "{\"Operations\":[{\"op\":\"add\",\"path\":\"users\",\"value\":[{\"value\":\"$UID_VAL\"}]}]}" \
    -o /dev/null -w '%{http_code}')
  echo "      -> $ROLE (HTTP $CODE)"
done

echo
echo "Done. Run ./verify-tokens.sh to confirm claims reach the JWT."