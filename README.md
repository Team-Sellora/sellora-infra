# Identity Server — US-E0-1

WSO2 Identity Server 7.3.0 configuration for Sellora. Covers the five business
roles, the `companyId` tenant claim, the seeded test users, and — critically —
the scope/application wiring that makes those claims actually appear in tokens.

## Environment

Hosted on AWS EC2 (Ubuntu 24.04), IS and APIM on one instance.

| Product | Port | URL |
|---|---|---|
| **Identity Server 7.3.0** | 9443 | `https://13.61.228.129:9443/console` |
| **API Manager 4.5.0** | 9444 (offset 1) | `https://13.61.228.129:9444/admin` |

> **Migration note:** originally hosted on OCI (`130.210.62.210`); migrated to
> AWS (`13.61.228.129`) on 2026-08-20. All references use the AWS IP. If the
> instance is stopped/started without an Elastic IP the public IP changes —
> update `.env` and re-run.

> **Port note:** this puts IS on 9443 and APIM on 9444 — the reverse of the WSO2
> docs, which assume APIM on 9443. Swap ports in any endpoint table copied from
> the docs.

Tenant: `carbon.super` only. See "Multi-tenancy".

## Setup order

```bash
cp .env.example .env      # fill in admin creds, test client, APP_IDS
./seed-roles.sh           # 1. five organization-audience roles
./seed-users.sh           # 2. five users, companyId, role assignment
# 3. SERVER PREREQUISITE — see below (deployment.toml edit + IS restart)
./configure-apps.sh       # 4. scope binding + per-app claim/role wiring
./verify-tokens.sh        # 5. acceptance evidence
```

## Server prerequisite (manual — no script can do this)

`configure-apps.sh` handles the scope and application config over the REST API,
but one setting is a server-side file edit and restart, not an API call. **Do
this once, between step 2 and step 4**, or both claims will be missing from
every token no matter what else is correct.

SSH to the instance and add to `~/wso2is/repository/conf/deployment.toml`:

```toml
[oauth]
authorize_all_scopes = true
```

Then restart IS and wait for it to come up:

```bash
cd ~/wso2is
sh bin/wso2server.sh restart
tail -f repository/logs/wso2carbon.log   # wait for "WSO2 Carbon started"
```

Without this, IS lists the access-token attributes but does not release them —
the token comes back with neither `roles` nor `companyId`.

## Why claims appear in the token — the four gates (IS 7.3)

This was the hard lesson of US-E0-1. Storing `companyId` on a user and assigning
a role is NOT enough. Four independent things must line up, and each is silent
when it is the one missing:

1. **`companyId` bound to an OIDC scope the token carries.** Bound to `profile`.
   A mapped attribute that is not on a released scope never appears.
   *(configure-apps.sh, step 1.)*
2. **`[oauth] authorize_all_scopes = true`** in deployment.toml, IS restarted.
   *(Server prerequisite above — manual.)*
3. **Application `associatedRoles.allowedAudience = ORGANIZATION.`** The business
   roles are Organization-audience; the IS default for a new app is APPLICATION,
   so the app looks for application-scoped roles, finds none, and the `roles`
   claim is empty. This is the least obvious gate and cost the most time.
   *(configure-apps.sh, step 2.)*
4. **Per-app `requestedClaims` include companyId + roles, and OIDC
   `accessToken.accessTokenAttributes` lists both.** Per-application — one app's
   config does nothing for another. *(configure-apps.sh, step 2.)*

## Manual console steps (attribute creation only)

Only the attribute *definition* is console work with no scripted equivalent. Do
this before `configure-apps.sh`.

### Create the `companyId` attribute

Console → **User Attributes & Stores → Attributes → New Attribute**

- Attribute name: `companyId` → becomes `http://wso2.org/claims/companyId`
- Display name: `Company ID`
- **Attribute Mappings** tab → PRIMARY → Mapped Attribute Name: `companyId`,
  "Manage in user store" ticked
- **General** tab → Attribute Configurations → tick **Display → Administrator
  Console** only. Leave **Required off** (required blocks creating any user
  without a companyId, including DCR-created clients).

Then map it to OIDC: **Attributes and Mappings → OpenID Connect → New
Attribute** → OIDC attribute `companyId`, mapped to `Company ID`.

The scope binding (adding companyId to the `profile` scope) is done by
`configure-apps.sh` — no need to do it in the console.

## Applications

| Application | Type | UUID | Purpose |
|---|---|---|---|
| `Sellora` | Single-Page Application (public, PKCE) | `248db66f-93ac-4566-9b62-0e6885cc440e` | The real SPA — US-E0-3 |
| `Sellora CLI Test` | Standard-based OIDC (confidential) | `80deb025-f61a-44ae-a3aa-bdf5b0c44754` | CLI token testing only |

The SPA is a public client with no secret; password grant is unavailable to it
by design (PKCE replaces it). The CLI test app exists purely to pull tokens from
a terminal — **it must not be used by any application code.** Both apps are
configured by `configure-apps.sh` (set both UUIDs in `APP_IDS`).

The SPA cannot be token-tested with password grant; its correctness is confirmed
by matching config (ORGANIZATION audience, both claims requested), which is
identical to the CLI app that verifies cleanly.

## Claim contract

Every downstream service depends on this shape. Do not change it without
updating US-E0-3 and US-E0-4.

```json
{
  "sub":        "6c83c690-72bb-46ef-a8fb-5902303924a8",
  "roles":      ["SalesRep", "everyone"],
  "companyId":  "COMP-001",
  "iss":        "https://13.61.228.129:9443/oauth2/token",
  "org_handle": "carbon.super"
}
```

**`roles` is an array, not a string.** `AddJwtBearer` will not map it to
`ClaimTypes.Role` automatically — set `RoleClaimType = "roles"` in
`TokenValidationParameters`. Each array element becomes a separate claim.

**`everyone` appears in every token.** IS built-in that all users inherit. Role
policies must match the specific role — a check for "has any role" passes for
every authenticated user.

## Token lifetimes

| Token | Lifetime | Rationale |
|---|---|---|
| Access | 3600s (1h) | Limits exposure of a leaked token; avoids constant refreshes |
| Refresh | 86400s (24h) | One working day — user re-authenticates daily |

Set on both applications (OIDC accessToken config). Refresh Token grant enabled
so the SPA renews silently without a new login redirect.

## Multi-tenancy

**Do not use WSO2 tenants for Sellora companies.** The APIM and IS 7.x data
models differ; tenancy support with IS 7.x as key manager is version-dependent
and fragile. Tenancy is the `companyId` claim plus EF Core global query filters,
per US-E0-4. WSO2 stays single-tenant on `carbon.super`; companies are
application data.

## Seeded test users

All five belong to `COMP-001`, password in `.env`.

| userName | Role |
|---|---|
| `companyadmin1` | CompanyAdmin |
| `areamanager1` | AreaManager |
| `agencyop1` | AgencyOperator |
| `salesrep1` | SalesRep |
| `shopowner1` | ShopOwner |

## Reproducibility status (AC3)

AC3 asks for a clean start with no manual steps. Current status:

- **Scripted:** roles, users, companyId values, scope binding, per-app claim and
  role-audience wiring, access-token attributes. (`seed-*.sh`, `configure-apps.sh`)
- **Manual:** the `companyId` attribute *definition* in the console, and the
  `deployment.toml` `authorize_all_scopes` edit + IS restart.

So AC3 is *substantially* met — a rebuild is three scripts plus two documented
manual steps, not a pile of undocumented console clicking. Full automation of the
attribute definition and deployment.toml is deferred to US-E0-6 (Compose stack).

## Troubleshooting

| Symptom | Cause |
|---|---|
| `roles` is None, `companyId` present | App `associatedRoles.allowedAudience` is APPLICATION; must be ORGANIZATION |
| Both `roles` and `companyId` None | deployment.toml missing `authorize_all_scopes`, or IS not restarted |
| `companyId` None, `roles` present | companyId not bound to a scope the token carries (bind to `profile`) |
| `companyId` accepted on user but absent | Wrong schema URN — custom extension omits `ietf:params` |
| Token identical across retests (same `jti`) | Cached token; revoke the refresh token first |
| `invalid_client` | Public SPA has no secret; use the confidential CLI app |
| `unauthorized_client` | Grant type not enabled on the application |
| `Authentication failed` | Wrong user password (not the admin password) |
| `Invalid user store name` | Don't prefix usernames with `DEFAULT/`; PRIMARY takes no prefix |
| Script `JSONDecodeError` | curl returned empty — CRLF in `.env` (`sed -i 's/\r$//'`), or wrong `IS_HOST` |