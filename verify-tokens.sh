#!/usr/bin/env bash
#
# Obtains an access token for each seeded user and prints the roles and
# companyId claims. This is the acceptance evidence for US-E0-1.
#
# Expected output — one line per user, each with exactly one business role
# plus the IS built-in "everyone":
#
#   companyadmin1 -> ['CompanyAdmin', 'everyone'] COMP-001
#   areamanager1  -> ['AreaManager', 'everyone']  COMP-001
#   agencyop1     -> ['AgencyOperator', 'everyone'] COMP-001
#   salesrep1     -> ['SalesRep', 'everyone']     COMP-001
#   shopowner1    -> ['ShopOwner', 'everyone']    COMP-001
#
# If a claim is missing, check in this order:
#   1. Application -> Protocol -> Access Token Attributes  (governs the ACCESS token)
#   2. Application -> User Attributes                       (governs ID token / userinfo)
#   3. Application -> Roles tab -> audience set to Organization
# These are per-application settings; configuring one app does nothing for another.
#
# NOTE: IS caches tokens. If you change roles or attributes and the token looks
# unchanged, check the jti — an identical jti means you got the cached token back.
# Revoke the refresh token before retesting.
#
# Usage:  ./verify-tokens.sh

set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || { echo "ERROR: .env not found. Copy .env.example to .env first." >&2; exit 1; }
# shellcheck disable=SC1091
source .env

[[ -n "${TEST_CLIENT_ID:-}" ]] || { echo "ERROR: TEST_CLIENT_ID not set in .env" >&2; exit 1; }

for U in companyadmin1 areamanager1 agencyop1 salesrep1 shopowner1; do
  printf '  %-15s -> ' "$U"
  curl -sk -u "$TEST_CLIENT_ID:$TEST_CLIENT_SECRET" -X POST "$IS_HOST/oauth2/token" \
    -d "grant_type=password&username=$U&password=$SEED_USER_PASSWORD&scope=openid profile roles" \
   | python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
if 'access_token' not in d:
    print('ERROR', d.get('error_description', d)); raise SystemExit
p = json.loads(base64.urlsafe_b64decode(d['access_token'].split('.')[1] + '=='))
print(p.get('roles'), p.get('companyId'))
"
done