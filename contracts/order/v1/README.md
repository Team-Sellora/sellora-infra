# Order event contracts — v1

Versioned JSON Schema contracts for order lifecycle events published on the `sellora.order.v1` topic.

## Topic

| Setting | Value |
|---|---|
| Topic name | `sellora.order.v1` |
| Bootstrap server (local) | `localhost:9092` |
| Message key | `orderReference` (ensures per-order ordering) |
| Partitions (local) | 3 |

## Events

| Event | Trigger | Message key |
|---|---|---|
| `OrderPlaced` | Rep submits a new order | `orderReference` |
| `OrderConfirmed` | Checkout transaction commits | `orderReference` |
| `PaymentRecorded` | Payment is captured at checkout | `orderReference` |
| `OrderCancelled` | Order is voided before fulfillment | `orderReference` |

## Shared event envelope

Every event includes:

- `eventId`: unique event UUID (for idempotent consumers).
- `eventType`: fixed event name matching the schema title.
- `schemaVersion`: currently `1.0`.
- `correlationId`: HTTP request trace ID propagated from the originating request.
- `occurredAt`: UTC timestamp at which the domain transition occurred.
- `orderReference`: the stable, human-readable order identifier used as the broker message key.
- `companyId`: tenant UUID for multi-tenant isolation.
- `checkoutLocation`: GPS coordinates (`latitude`, `longitude`, optional `accuracyMetres`) captured at the moment of checkout.

## Denormalised context

`OrderConfirmed` and `PaymentRecorded` carry `shopName`, `shopEmail`, `agencyName`, `agencyEmail` and `salesRepName` so the Notification service can compose and dispatch an email without making a synchronous call back to the Organization or Catalog services.

## Publishing rules

- Write the outbox row in the same database transaction as the order state change. A committed order must have its event; there is no valid state where an order commits and its event does not.
- Key every message by `orderReference` so all events for a single order land on the same partition and arrive in order.
- Publish UTF-8 JSON that validates against the relevant schema.
- Consumers must reject unsupported major schema versions.
- Breaking contract changes require a new `v2` schema directory; never modify a published `v1` schema incompatibly.
