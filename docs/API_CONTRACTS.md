# API Contracts

These are the interfaces the module's `Dio*RemoteDataSource` classes call.
They're written to match the request/response shapes each `*Model.fromJson`
expects — if a real backend team implements exactly this, no data-layer
code needs to change (only `useMockBackendProvider` flips to `false`).

All endpoints are relative to the `baseUrl` configured in `dioProvider`
(`lib/core/di/providers.dart`).

---

## `GET /flight/status`

**Query params:** `flightNumber` (string, required)

**Response 200:**
```json
{
  "flightNumber": "FZ123",
  "origin": "DXB",
  "destination": "LHR",
  "status": "delayed",
  "scheduledDeparture": "2026-07-22T14:00:00.000Z",
  "estimatedDeparture": "2026-07-22T14:35:00.000Z",
  "gate": "B12",
  "terminal": "2",
  "checkInCounter": "14-18",
  "boardingTime": "2026-07-22T13:40:00.000Z"
}
```
`status` ∈ `scheduled | boarding | delayed | departed | cancelled | landed`
(anything else maps to `unknown` client-side). All date/time fields are
ISO-8601 strings; the nullable ones may be omitted.

---

## `GET /booking`

**Query params:** `pnr` (string, required)

**Response 200:**
```json
{
  "pnr": "ABC123",
  "passengerName": "A. Passenger",
  "flight": { "...": "same shape as /flight/status" }
}
```

---

## `GET /seatmap`

**Query params:** `flightNumber` (string, required)

**Response 200:**
```json
{
  "flightNumber": "FZ123",
  "rows": 9,
  "currency": "USD",
  "seats": [
    {
      "seatNumber": "14A",
      "row": 14,
      "column": "A",
      "type": "window",
      "availability": "available",
      "priceDelta": 15,
      "isExitRow": true
    }
  ]
}
```
`type` ∈ `window | middle | aisle`. `availability` ∈
`available | occupied | selected | blocked`.

---

## `POST /seat/change`

**Body:**
```json
{ "pnr": "ABC123", "flightNumber": "FZ123", "seatNumber": "14A" }
```

**Response 200:** a single seat object (same shape as one entry in
`/seatmap`'s `seats` array), with `availability: "selected"`.

**Error cases the client distinguishes:** a `409`/domain-specific error
body should be surfaced as a failed request (any non-2xx) — the mock
backend models this as the seat simply no longer being available, which
the repository maps to `SeatUnavailableFailure`.

---

## `GET /baggage`

**Query params:** `pnr` **or** `flightNumber`, plus `view` = `allowance` | `options`

**Response 200 (`view=allowance`):**
```json
{ "checkedKg": 30, "cabinKg": 7 }
```

**Response 200 (`view=options`):**
```json
[
  { "id": "bag_5kg", "extraWeightKg": 5, "price": 25, "currency": "USD" },
  { "id": "bag_10kg", "extraWeightKg": 10, "price": 45, "currency": "USD" },
  { "id": "bag_20kg", "extraWeightKg": 20, "price": 80, "currency": "USD" }
]
```

---

## `POST /baggage/purchase`

**Body:**
```json
{ "pnr": "ABC123", "optionId": "bag_10kg" }
```

**Response 200:**
```json
{
  "id": "purchase_1737550000000",
  "option": { "id": "bag_10kg", "extraWeightKg": 10, "price": 45, "currency": "USD" },
  "status": "success",
  "confirmationCode": "BG54231"
}
```
`status` ∈ `pending | success | failed`. A declined payment should return
`status: "failed"` (or a non-2xx, which the client maps to
`PaymentFailure`).

---

## `GET /airport/details`

**Query params:** `flightNumber`, `airportCode`

**Response 200:**
```json
{
  "terminal": "2",
  "checkInCounter": "14-18",
  "gate": "B12",
  "walkingTimeMinutes": 12,
  "indoorMapAssetPath": null,
  "directions": [
    "Head to Check-in Row 14-18 on Level 2.",
    "Clear security and immigration.",
    "Follow signs to Gate B12 — approx. 12 min walk."
  ]
}
```

---

## `POST /chat/message`

This single endpoint is intentionally overloaded by `mode`, mirroring how
`ChatRemoteDataSource` calls it — a real backend can route on this field to
different internal handlers (or different models) without the client
changing.

**`mode: "intent_classification"`**
```json
// request
{ "model": "gpt-4.1-mini", "mode": "intent_classification", "input": "I want a window seat" }
// response
{ "intent": "seatSelection", "confidence": 0.92, "entities": {} }
```
`intent` must be one of the `IntentType` enum names (see
`docs/CLASS_DIAGRAM.md`); anything else maps to `unknown` client-side.

**`mode: "reply"`**
```json
// request
{ "model": "gpt-4.1-mini", "mode": "reply", "input": "...", "history": [ /* ChatMessage JSON */ ] }
// response — a single ChatMessage JSON object
{
  "id": "msg_123",
  "role": "assistant",
  "type": "text",
  "timestamp": "2026-07-22T14:00:00.000Z",
  "text": "Here's what I found — let me know if you'd like more detail.",
  "payload": null,
  "isStreaming": false
}
```

**`mode: "escalate"`**
```json
// request
{ "mode": "escalate", "reason": "Passenger requested a human agent", "summary": "..." }
// response
{ "queuePosition": 2, "estimatedWaitMinutes": 4 }
```

---

## Error handling contract

Any non-2xx response, connection failure, or timeout is caught by
`safeCall` (`lib/core/utils/safe_call.dart`) and mapped to a domain
`Failure` — see `docs/CLASS_DIAGRAM.md`'s failure hierarchy. A backend
doesn't need to match Dio's exception types exactly; a plain non-2xx
status is enough to surface as `ServerFailure`, and a request that never
completes surfaces as `TimeoutFailure`/`NetworkFailure` based on Dio's own
classification.
