#!/usr/bin/env bash
#
# Configures the OIDC scope bindings and per-application claim/role settings
# that make companyId and roles actually appear in access tokens on IS 7.3.x.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# seed-roles.sh and seed-users.sh create the roles, users and companyId values,
# but on IS 7.3 that is NOT enough — the token still comes back empty. Four extra
# things must line up, none of which the seed scripts do. Each is invisible when
# it is the one missing:
#
#   1. companyId must be bound to an OIDC SCOPE the token carries (profile).
#      Being a mapped attribute is not enough; the scope gates its release.
#   2. deployment.toml must have [oauth] authorize_all_scopes = true.
#      (Server-level — see README. NOT set by this script.)
#   3. Each application's requestedClaims must include companyId AND roles.
#   4. Each application's associatedRoles.allowedAudience must be ORGANIZATION,
#      because the business roles are Organization-audience. The IS default is
#      APPLICATION, which silently yields an empty roles claim.
#   Plus: the app's accessTokenAttributes must list companyId and roles.
#
# This script does 1, 3, 4 and the accessTokenAttributes for every app listed in
# APP_IDS. Item 2 is a deployment.toml edit + restart, documented in the README.
#
# Run AFTER seed-roles.sh and seed-users.sh, and after the deployment.toml edit.
#
# Usage:  ./configure-apps.sh

set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || { echo "ERROR: .env not found. Copy .env.example to .env first." >&2; exit 1; }
# shellcheck disable=SC1091
source .env

AUTH="$IS_ADMIN_USER:$IS_ADMIN_PASS"

# Application internal UUIDs (NOT client IDs) to configure.
# Get them with:
#   curl -sk -u admin:admin "$IS_HOST/api/server/v1/applications" \
#     | python3 -c "import sys,json;[print(a['id'],a['name']) for a in json.load(sys.stdin)['applications']]"
# Set APP_IDS in .env as a space-separated list, e.g.
#   APP_IDS="80deb025-... 248db66f-..."
[[ -n "${APP_IDS:-}" ]] || { echo "ERROR: APP_IDS not set in .env (space-separated application UUIDs)." >&2; exit 1; }

COMPANY_CLAIM="http://wso2.org/claims/companyId"
ROLES_CLAIM="http://wso2.org/claims/roles"

echo "=== 1. Bind companyId to the 'profile' OIDC scope ==="
# Fetch the current profile-scope claim list, append companyId if absent, PUT back.
PROFILE_CLAIMS=$(curl -sk -u "$AUTH" "$IS_HOST/api/server/v1/oidc/scopes/profile" | python3 -c "
import sys, json
d = json.load(sys.stdin)
claims = d.get('claims', [])
if 'companyId' not in claims:
    claims.append('companyId')
print(json.dumps(claims))
")

curl -sk -u "$AUTH" -X PUT "$IS_HOST/api/server/v1/oidc/scopes/profile" \
  -H 'Content-Type: application/json' \
  -d "{
    \"displayName\": \"Profile\",
    \"description\": \"Retrieve profile information of the user.\",
    \"claims\": $PROFILE_CLAIMS
  }" -o /dev/null -w "  profile scope -> %{http_code}\n"

echo
echo "=== 2. Per-application configuration ==="
for APP in $APP_IDS; do
  NAME=$(curl -sk -u "$AUTH" "$IS_HOST/api/server/v1/applications/$APP" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('name','?'))")
  echo "  App: $NAME ($APP)"

  # 2a. requestedClaims + ORGANIZATION role audience
  CODE=$(curl -sk -u "$AUTH" -X PATCH "$IS_HOST/api/server/v1/applications/$APP" \
    -H 'Content-Type: application/json' \
    -d "{
      \"claimConfiguration\": {
        \"dialect\": \"LOCAL\",
        \"requestedClaims\": [
          { \"claim\": { \"uri\": \"$COMPANY_CLAIM\" }, \"mandatory\": false },
          { \"claim\": { \"uri\": \"$ROLES_CLAIM\" }, \"mandatory\": false }
        ]
      },
      \"associatedRoles\": { \"allowedAudience\": \"ORGANIZATION\", \"roles\": [] }
    }" -o /dev/null -w '%{http_code}')
  echo "      claims + org role audience -> HTTP $CODE"

  # 2b. accessTokenAttributes on the OIDC inbound protocol
  CODE2=$(curl -sk -u "$AUTH" -X PUT \
    "$IS_HOST/api/server/v1/applications/$APP/inbound-protocols/oidc" \
    -H 'Content-Type: application/json' \
    -d "$(curl -sk -u "$AUTH" "$IS_HOST/api/server/v1/applications/$APP/inbound-protocols/oidc" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d.setdefault('accessToken', {})
d['accessToken']['type'] = 'JWT'
d['accessToken']['accessTokenAttributes'] = ['companyId', 'roles']
print(json.dumps(d))
")" -o /dev/null -w '%{http_code}')
  echo "      access token attributes -> HTTP $CODE2"
done

echo
echo "Done. Run ./verify-tokens.sh to confirm roles + companyId reach the JWT."
echo "If still empty, confirm deployment.toml has [oauth] authorize_all_scopes = true and IS was restarted."