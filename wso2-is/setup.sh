#!/bin/bash
# sellora-infra/wso2-is/setup.sh
# Run this ONCE against a fresh Identity Server instance.
# Requires: IS must be running and reachable at IS_URL.

set -e  # Stop on any error

IS_URL="${IS_URL:-https://130.210.62.210:9443}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
AUTH=$(echo -n "$ADMIN_USER:$ADMIN_PASS" | base64)

echo "Target IS: $IS_URL"
echo ""

# ─────────────────────────────────────────────
echo "Step 1: Creating custom claims..."
# ─────────────────────────────────────────────

curl -k -s -X POST "$IS_URL/api/server/v1/claim-dialects/local/claims" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "claimURI": "http://wso2.org/claims/companyId",
    "description": "Sellora company ID",
    "displayName": "Company ID",
    "dataType": "String",
    "required": true
  }'
echo " ✓ companyId claim created"

curl -k -s -X POST "$IS_URL/api/server/v1/claim-dialects/local/claims" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "claimURI": "http://wso2.org/claims/sellorRole",
    "description": "Sellora platform role",
    "displayName": "Sellora Role",
    "dataType": "String",
    "required": true
  }'
echo " ✓ sellorRole claim created"

# ─────────────────────────────────────────────
echo ""
echo "Step 2: Creating Sellora OIDC application..."
# ─────────────────────────────────────────────

curl -k -s -X POST "$IS_URL/api/server/v1/applications" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sellora",
    "description": "Sellora SaaS platform OIDC application",
    "inboundProtocolConfiguration": {
      "oidc": {
        "grantTypes": ["authorization_code", "refresh_token"],
        "callbackURLs": ["http://localhost:3000/callback"],
        "allowedOrigins": ["http://localhost:3000"],
        "pkce": {
          "mandatory": true,
          "supportPlainTransformAlgorithm": false
        },
        "accessToken": {
          "type": "JWT",
          "userAccessTokenExpiryInSeconds": 900,
          "refreshTokenExpiryInSeconds": 86400
        }
      }
    }
  }'
echo " ✓ OIDC application created"

# ─────────────────────────────────────────────
echo ""
echo "Step 3: Creating test users..."
# ─────────────────────────────────────────────

create_user() {
  local USERNAME=$1
  local ROLE=$2
  curl -k -s -X POST "$IS_URL/scim2/Users" \
    -H "Authorization: Basic $AUTH" \
    -H "Content-Type: application/json" \
    -d "{
      \"schemas\": [\"urn:ietf:params:scim:schemas:core:2.0:User\"],
      \"userName\": \"$USERNAME\",
      \"password\": \"Test@1234\",
      \"emails\": [{\"value\": \"$USERNAME\", \"primary\": true}],
      \"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User\": {
        \"companyId\": \"comp-001\",
        \"sellorRole\": \"$ROLE\"
      }
    }"
  echo " ✓ $USERNAME ($ROLE) created"
}

create_user "admin@testco.com"    "CompanyAdmin"
create_user "areamanager@testco.com" "AreaManager"
create_user "agency@testco.com"   "AgencyOperator"
create_user "rep@testco.com"      "SalesRep"
create_user "shop@testco.com"     "ShopOwner"

echo ""
echo "Sellora IS setup complete."
echo "All test users have password: Test@1234"
