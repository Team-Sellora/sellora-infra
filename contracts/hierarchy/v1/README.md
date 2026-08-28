# Hierarchy event contracts - v1

These are versioned JSON Schema contracts for organisational hierarchy events.

## Events

| Event | Entity key |
| --- | --- |
| `AgencyRegistered` | `agencyId` |
| `TerritoryAssignedToAgency` | `territoryId` |
| `ShopRegistered` | `shopId` |
| `ShopUpdated` | `shopId` |
| `SalesRepAssigned` | `salesRepId` |
| `HierarchyEntityDeactivated` | `entityId` |

## Shared event rules

Every event includes:

- `eventId`: unique event UUID.
- `eventType`: fixed event name.
- `schemaVersion`: currently `1.0`.
- `companyId`: tenant/company UUID.
- `entityId`: entity UUID used as the broker message key.
- `effectiveAt`: UTC timestamp at which the change became effective.
- `correlationId`: request/trace identifier propagated from the initiating request.

## Publishing rules

- Publish UTF-8 JSON that validates against the relevant schema.
- Use `entityId` as the broker message key to preserve ordering for each entity.
- Write the outbox row in the same database transaction as the hierarchy change.
- Consumers must reject unsupported major schema versions.
- Breaking contract changes require a new `v2` schema; never modify a published `v1` schema incompatibly.