# Sellora Gateway URL & Versioning Convention

**Status:** Adopted · **Applies to:** every API published through WSO2 API Manager
**Owner:** Platform (E0) · **Related stories:** US-E0-2 (CSP-38, CSP-41)

---

## 1. Purpose

Every Sellora service is reached through the WSO2 API Manager gateway — never
directly. For the frontend and every service-to-service caller to build URLs
predictably, all published APIs MUST follow one path and versioning pattern.
Without this, services would be published under inconsistent paths and every
client would have to special-case each one.

This document is the single source of truth for that pattern.

## 2. The pattern

```
https://<gateway-host>:<gateway-port>/sellora/<service>/<version>/<resource>
```

| Segment           | Meaning                                              | Example        |
|-------------------|-----------------------------------------------------|----------------|
| `<gateway-host>`  | Gateway host (env-specific)                          | `13.61.228.129`|
| `<gateway-port>`  | Gateway HTTPS port                                   | `8244`         |
| `sellora`         | Fixed root namespace for all Sellora APIs           | `sellora`      |
| `<service>`       | Short service/domain name (see §4)                  | `ref`, `org`   |
| `<version>`       | API version (see §3)                                 | `1.0.0`        |
| `<resource>`      | The resource path within the API                    | `/organizations` |

**Worked example (the reference API published in CSP-38):**

```
https://13.61.228.129:8244/sellora/ref/1.0.0/test
```

- **APIM Context:** `/sellora/ref`
- **Version:** `1.0.0`
- APIM composes the deployed path as `{context}/{version}` → `/sellora/ref/1.0.0`

## 3. Versioning approach — PATH-based

Versioning is carried **in the URL path**, not in a header.

- The version segment sits **after** the service name: `/sellora/<service>/<version>/`.
- Format is semantic: `MAJOR.MINOR.PATCH` (e.g. `1.0.0`). Callers pin to the
  version string they were built against.
- A breaking change is published as a **new API version** in APIM (e.g. `2.0.0`),
  which produces a new path `/sellora/<service>/2.0.0/`. The old version stays
  deployed until consumers migrate, then is deprecated/retired via the APIM
  lifecycle.

**Why path, not header:** the version is visible in every request and log, is
trivial for the SPA and curl/Postman to construct, and matches WSO2 APIM's native
URL construction (`{context}/{version}`), so there is no translation layer between
the convention and the tool.

**Why `<service>/<version>` and not `<version>/<service>`:** this is exactly how
APIM builds the deployed URL from an API's context + version. Documenting the
tool's native shape means every published API matches the convention with zero
rework, and there is no impedance mismatch between what is configured and what is
documented.

## 4. Service name registry

`<service>` is a short, lowercase, hyphen-free token per bounded context. Reserve
names here as services are added so two teams never collide.

| Service            | `<service>` token | Epic | Example base path              |
|--------------------|-------------------|------|--------------------------------|
| Reference / template | `ref`           | E0   | `/sellora/ref/1.0.0`           |
| Organization & Hierarchy | `org`       | E1   | `/sellora/org/1.0.0`           |
| Product & Catalog  | `product`         | E2   | `/sellora/product/1.0.0`       |
| Inventory          | `inventory`       | E3   | `/sellora/inventory/1.0.0`     |
| Order & Replenishment | `order`        | E4   | `/sellora/order/1.0.0`         |
| Notification       | `notification`    | E5   | `/sellora/notification/1.0.0`  |
| Delivery & Returns | `delivery`        | E6   | `/sellora/delivery/1.0.0`      |
| Audit & Reporting  | `audit`           | E7   | `/sellora/audit/1.0.0`         |

> Add a row here in the same PR that publishes a new service.

## 5. Rules for publishing a new API (checklist)

1. Set the APIM **Context** to `/sellora/<service>` — nothing else in front of it.
2. Set **Version** to a semantic version (`1.0.0` for the first release).
3. Do **not** put the version in the context; let APIM append it.
4. Register the `<service>` token in the table in §4.
5. Backend endpoint stays **internal** (loopback / private) — the gateway is the
   only entry point.
6. Security: OAuth2 enabled; scopes follow the scope-naming convention
   (`sellora:<domain>:<action>`) — see the scope convention doc.

## 6. Environment note

`<gateway-host>` and `<gateway-port>` vary by environment (dev VM today, cloud
later). Only the **host:port** changes between environments — the
`/sellora/<service>/<version>/` portion is identical everywhere, so clients only
reconfigure a base URL, never the path structure.

Current dev gateway: `https://13.61.228.129:8244`

---

_Last updated: 2026-08-24 · Committed to `sellora-infra`._