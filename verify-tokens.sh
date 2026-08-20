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
# IF A CLAIM IS MISSING (None), check in THIS order — these are the real causes,
# in the order they bite on IS 7.3.x. Console "Access Token Attributes" alone is
# NOT sufficient; the following are the actual gates:
#
#   1. companyId is missing:
#      -> companyId not bound to an OIDC scope the token carries.
#         Bind it to the 'profile' scope (configure-apps.sh does this), OR:
#         PUT $IS_HOST/api/server/v1/oidc/scopes/profile with companyId in claims.
#
#   2. roles is missing (companyId present):
#      -> the application's associatedRoles.allowedAudience is APPLICATION but the
#         business roles are ORGANIZATION audience. They never meet.
#         Fix: PATCH the app with associatedRoles.allowedAudience = ORGANIZATION.
#         (configure-apps.sh does this.) This is the #1 cause and the least obvious.
#
#   3. BOTH missing, even after 1 and 2:
#      -> deployment.toml lacks [oauth] authorize_all_scopes = true, or IS was not
#         restarted after adding it. This is a SERVER FILE edit + restart, not an
#         API call — see README "Server prerequisite". No script can do it.
#
#   Also: the app's requestedClaims must include companyId and roles, and the
#   OIDC accessToken.accessTokenAttributes must list both. configure-apps.sh sets
#   these. They are per-application — configuring one app does nothing for another.
#
# NOTE: IS caches tokens. If you change config and the token looks unchanged,
# check the jti — an identical jti means you got the cached token back. Revoke
# the refresh token, or wait for expiry, before retesting.
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