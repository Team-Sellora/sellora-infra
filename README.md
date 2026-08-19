# Identity Server — US-E0-1

WSO2 Identity Server 7.x configuration for SalesFlow. Covers the five business
roles, the `companyId` tenant claim, and the seeded test users.

## Environment

| Product | Offset | Port | URL |
|---|---|---|---|
| **Identity Server 7.x** | 0 | 9443 | `https://130.210.62.210:9443/console` |
| **API Manager** | 1 | 9444 | `https://130.210.62.210:9444/admin` |

> **This is the reverse of the WSO2 documentation**, which assumes APIM on 9443
> and IS on 9444. Swap the ports in any endpoint table you copy from the docs.

Tenant: `carbon.super` only. See "Multi-tenancy" below.

## Setup order

```bash
cp .env.example .env      # fill in admin creds + test client
./seed-roles.sh           # five organization-audience roles
./seed-users.sh           # five users, companyId, role assignment
./verify-tokens.sh        # acceptance evidence
```

The scripts are idempotent — safe to re-run.

## Manual console steps (not scripted)

Attribute and application configuration is console work. **Do these before
running the scripts on a clean instance**, or `companyId` will not persist and
will not reach any token.

### 1. Create the `companyId` attribute

Console → **User Attributes & Stores → Attributes → New Attribute**

- Attribute name: `companyId` → becomes `http://wso2.org/claims/companyId`
- Display name: `Company ID`
- **Attribute Mappings** tab → PRIMARY → Mapped Attribute Name: `companyId`,
  "Manage in user store" ticked
- **General** tab → Attribute Configurations → tick **Display → Administrator
  Console** only. Leave Required off — making it required blocks creating any
  user without a companyId, including anything APIM creates via DCR.

### 2. Map it to OIDC

Console → **Attributes and Mappings → OpenID Connect → New Attribute**

- OIDC attribute: `companyId`
- Mapped to: `Company ID`

### 3. Add it to the `profile` scope

Same screen → **Scopes** button → open `profile` → add `companyId`.

Using `profile` rather than a custom scope means the SPA's standard
`openid profile` request picks it up in US-E0-3, with no extra scope to thread
through the APIM application.

### 4. Per-application settings

**These are per-application. Configuring one app does nothing for another.**

For each application that needs the claims:

- **Protocol → Token type:** JWT (not Opaque)
- **Protocol → Access Token Attributes:** add `companyId` and `roles`
  — this governs the **access token**, which is what the .NET services validate
- **User Attributes:** add `Company ID`
  — this governs the **ID token and userinfo**
- **Roles tab:** audience set to **Organization**

## Applications

| Application | Type | Purpose |
|---|---|---|
| `Sellora` | Single-Page Application (public, PKCE) | The real SPA client — US-E0-3 |
| `SalesFlow CLI Test` | Standard-based OIDC (confidential) | CLI token testing only |

The SPA is a public client and has no secret; password grant is unavailable to
it by design. The CLI test app exists purely so tokens can be pulled from a
terminal — **it must not be used by any application code.**

## Claim contract

Every downstream service depends on this shape. Do not change it without
updating US-E0-3 and US-E0-4.

```json
{
  "sub":       "ca374af7-062b-476c-bb7f-906ee3d1cc33",
  "roles":     ["SalesRep", "everyone"],
  "companyId": "COMP-001",
  "iss":       "https://130.210.62.210:9443/oauth2/token",
  "org_handle": "carbon.super"
}
```

**`roles` is an array, not a string.** `AddJwtBearer` will not map it to
`ClaimTypes.Role` automatically — set `RoleClaimType = "roles"` in
`TokenValidationParameters`. Each array element becomes a separate claim.

**`everyone` appears in every token.** It is an IS built-in that all users
inherit. Role policies must match the specific role — a check for "has any
role" will pass for every authenticated user.

## Multi-tenancy

**Do not use WSO2 tenants for SalesFlow companies.** The APIM and IS 7.x data
models differ; on APIM 4.3/4.4 tenancy is not supported with IS 7.x as key
manager, and on 4.7 it requires explicit tenant-sharing configuration.

Tenancy is the `companyId` claim plus EF Core global query filters, per
US-E0-4. WSO2 stays single-tenant on `carbon.super`; companies are application
data.

## Seeded test users

All five belong to `COMP-001`, password in `.env`.

| userName | Role |
|---|---|
| `companyadmin1` | CompanyAdmin |
| `areamanager1` | AreaManager |
| `agencyop1` | AgencyOperator |
| `salesrep1` | SalesRep |
| `shopowner1` | ShopOwner |

## Known gaps

- **Attribute and application config is manual.** Sections 1–4 above are console
  steps with no scripted equivalent today. US-E0-1 Acceptance Scenario 3 ("clean
  start with no manual console steps") is therefore only partially met. Carry
  this to **US-E0-6** when the Compose stack lands.
- **Certificate uses `CN=localhost`** while the host is a bare IP, so calls to
  `https://130.210.62.210:9443` fail hostname verification. Internal APIM → IS
  calls use `localhost` as a workaround. Replace with a keystore carrying the IP
  in its SAN before the demo.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `companyId` accepted but silently absent | Wrong schema URN — custom extension omits `ietf:params` |
| Token identical across retests (same `jti`) | Cached token; revoke the refresh token first |
| `roles` missing but `companyId` present | Application Roles tab audience, or `roles` absent from Access Token Attributes |
| Claim stored on user but absent from JWT | Not added to that application's Access Token Attributes |
| `invalid_client` | Public client — no secret; or wrong credentials |
| `unauthorized_client` | Grant type not enabled on the application |
| `Invalid user store name` | Do not prefix usernames with `DEFAULT/`; PRIMARY takes no prefix |

## Token lifetimes

| Token | Lifetime | Rationale |
|---|---|---|
| Access | 3600s (1h) | Short enough to limit exposure of a leaked token; long enough to avoid constant refreshes |
| Refresh | 86400s (24h) | One working day — user re-authenticates daily |

Set on the Sellora SPA application (Protocol tab). Refresh Token grant enabled
so the SPA renews silently without sending the user back to the login page.
EOF