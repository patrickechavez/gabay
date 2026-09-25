# Gabay Backend API Contract

The contract the Gabay iOS app is built against. This document is the source of
truth for the C# (.NET 8) backend. The iOS client in this repository will not
change to accommodate the backend: if a shape or status code here is wrong, this
document is wrong, not the app.

Last checked against the client code on `events-platform`.

## 1. Conventions

### Base URL

One API host per environment, set via `API_BASE_URL`:

| Environment | Placeholder |
|---|---|
| Development | `http://localhost:5000` |
| Staging | `https://staging-api.example.com` |
| Production | `https://api.example.com` |

All paths below are relative to that base. The client appends path components
with `/` separators, so `me` becomes `{base}/me` and `events/{id}/join` becomes
`{base}/events/{id}/join`.

### Authentication

- Every request except `auth/register`, `auth/login` and `auth/refresh` carries
  `Authorization: Bearer <accessToken>`.
- The access token is a JWT. The backend issues a short-lived access token and a
  longer-lived refresh token.
- A `401` on any request triggers the client to refresh the token once and
  retry. If refresh fails, the client clears its stored tokens and returns the
  user to sign-in. The backend does not need to handle this specially beyond
  returning `401` correctly.

### Content types

- Requests with a JSON body send `Content-Type: application/json`.
- Every request sends `Accept: application/json`, except the GPX download, which
  sends `Accept: application/gpx+xml`.
- The GPX upload is `multipart/form-data`.

### JSON naming

**camelCase, exactly as written here. No snake_case, and no case conversion on
either side.** The client decoder does not convert case, so a field named
`feePHP` must literally be `feePHP` in the wire JSON, and `distanceM` must be
`distanceM` (not `distance_m`).

### Dates

ISO 8601 strings. The client accepts both plain and fractional-second forms
(`2026-10-18T05:30:00+08:00` and `2026-10-18T05:30:00.000+08:00`). The client
sends plain ISO 8601 (no fractional seconds). Always include a timezone offset.

`expiresAt` is an ISO 8601 timestamp of when the access token expires. It is
nullable in the client only for defensive decoding; the backend should always
send it.

### Error format

A non-2xx response should carry a JSON body. The client reads the first
non-empty string it finds under any of these keys: `message`, `error`,
`detail`, `error_description`, `title`, `reason` (searched in that order, one
level of nesting supported).

For field-level validation errors, the client looks under `errors`, `error` or
`validation_errors`, in one of two shapes:

```json
{
  "message": "Please check the highlighted fields.",
  "errors": {
    "feePHP": ["Fee must be a positive number."],
    "joinURL": ["Join link must be a valid URL."]
  }
}
```

or a list form:

```json
{
  "errors": [
    { "field": "feePHP", "message": "Fee must be a positive number." },
    { "field": "joinURL", "message": "Join link must be a valid URL." }
  ]
}
```

The field name in the first shape is the JSON field name (camelCase), and the
client maps it to the form field. A plain-text body (non-JSON, under 500 bytes,
not starting with `<`) is also accepted as the message.

### Status codes the client understands

| Code | Meaning to the client | Effect |
|---|---|---|
| `400` with field errors | validation | inline field errors |
| `401` | unauthorized | refresh, then retry; sign out if refresh fails |
| `403` | forbidden | generic error |
| `404` | not found | generic error |
| `409` | conflict | generic error |
| `422` | validation | inline field errors |
| `426` | update required | "update the app" error |
| `429` | rate limited | retried, honoring `Retry-After` (seconds) |
| `503` | maintenance | "temporarily unavailable" |
| other `5xx` / unknown | server error | retried, then generic error |

Anything not listed above (including `400` without field errors) maps to a
generic server error.

The client retries idempotent requests (GET) automatically with exponential
backoff on retryable errors (offline, timeout, transport, `429`, `503`, `5xx`).
Non-idempotent requests are only retried when offline or before a body was
sent. `429` responses should set the `Retry-After` header in seconds; the
client honors it.

## 2. Authentication endpoints

### `POST /auth/register`

No auth. Creates an account.

Request:

```json
{ "email": "hiker@example.com", "password": "secret123" }
```

Response `200`:

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<opaque or jwt>",
  "expiresAt": "2026-09-25T12:00:00+08:00",
  "role": "hiker"
}
```

`role` is required on register and login responses. It is either `hiker` or
`organizer`.

A duplicate email should return `409`.

### `POST /auth/login`

No auth. Same request and response shape as register.

Bad credentials: `401`.

### `POST /auth/refresh`

No auth. Exchanges a refresh token for a new pair.

Request:

```json
{ "refreshToken": "<refresh token>" }
```

Response `200`:

```json
{
  "accessToken": "<new jwt>",
  "refreshToken": "<new refresh token>",
  "expiresAt": "2026-09-25T13:00:00+08:00"
}
```

Note: unlike register and login, refresh does **not** return `role`. The client
decodes this as a shape without `role`.

An invalid or expired refresh token: `401`.

The backend may rotate the refresh token (return a new one) or return the same
one. Either is fine, but if it rotates, the old refresh token must stop working.

### `GET /me`

Requires auth. Returns the signed-in account.

Response `200`:

```json
{ "email": "hiker@example.com", "role": "hiker" }
```

## 3. Events endpoints

### `GET /events`

Requires auth. Returns the published events list.

Response `200`:

```json
[
  {
    "id": "hike-for-pawssion",
    "title": "Hike for Pawssion Project",
    "cause": "Pawssion Project Cebu",
    "date": "2026-10-18T05:30:00+08:00",
    "meetingPoint": "Budlaan barangay hall",
    "meetingCoordinate": { "latitude": 10.398, "longitude": 123.887 },
    "feePHP": 250,
    "capacity": 25,
    "joinURL": "https://m.me/pawssionprojectcebu",
    "description": "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
    "photoURL": null,
    "gpxURL": "https://example.com/uploads/hike-for-pawssion.gpx",
    "distanceM": 4761,
    "ascentM": 386,
    "estimatedMinutes": 132,
    "status": "published"
  }
]
```

Only `published` events are returned here. `pending` events never appear in this
list.

### `GET /me/events`

Requires auth. Returns the events the signed-in account has joined, same `Event`
shape as `GET /events`.

Response `200`:

```json
[]
```

Used by the app's "My Events" tab.

### `POST /events`

Requires auth, **organizer role only** (return `403` for a hiker). Creates an
event in the `pending` state.

Request body (an `EventDraft`, no `id`, no `status`, no route fields):

```json
{
  "title": "Hike for Pawssion Project",
  "cause": "Pawssion Project Cebu",
  "date": "2026-10-18T05:30:00+08:00",
  "meetingPoint": "Budlaan barangay hall",
  "meetingCoordinate": { "latitude": 10.398, "longitude": 123.887 },
  "feePHP": 250,
  "capacity": 25,
  "joinURL": "https://m.me/pawssionprojectcebu",
  "description": "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
  "photoURL": null
}
```

Response `200`: the created `Event`, with `id` and `status` assigned by the
server. The created event has `status: "pending"`, and the four route fields
(`gpxURL`, `distanceM`, `ascentM`, `estimatedMinutes`) are `null` until a GPX is
uploaded.

The server assigns `id` and is free to use any string scheme. The client treats
`id` as an opaque string and interpolates it into paths, so an id should be URL
path-safe (no `/` or characters that need encoding).

### `POST /events/{id}/join`

Requires auth. Marks the event as joined for the signed-in account.

Response `204 No Content`.

Joining is idempotent: joining an already-joined event should still return
`204`. There is no un-join in this version.

### `GET /events/{id}/gpx`

Requires auth. Returns the raw GPX file for an event.

Response `200`, `Content-Type: application/gpx+xml`, body is the GPX XML bytes.

`404` if the event has no GPX (the four route fields are all null) or does not
exist.

The GPX bytes are whatever the organizer uploaded; the backend stores and
returns them verbatim.

### `POST /events/{id}/gpx`

Requires auth, **organizer role only**. Attaches a GPX route to an event.

`multipart/form-data` with these parts:

| Part | Type | Description |
|---|---|---|
| `distanceM` | field (string) | total distance in metres |
| `ascentM` | field (string, optional) | total climb in metres, absent if the file has no elevation |
| `estimatedMinutes` | field (string) | Naismith estimate in minutes |
| `gpx` | file | the GPX file, `application/gpx+xml` |

The filename is generated by the app as `{id}.gpx` and must not be trusted.

Response `200`: the updated `Event`, now with `gpxURL`, `distanceM`, `ascentM`
and `estimatedMinutes` populated. These four fields are all-or-nothing: they are
null until this endpoint succeeds, and all four are present afterwards.

## 4. Data models

### Account

```json
{ "email": "string", "role": "hiker" }
```

### AuthResult (register and login only)

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "expiresAt": "ISO8601",
  "role": "hiker"
}
```

### RefreshResponse (refresh only)

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "expiresAt": "ISO8601"
}
```

### Event

```json
{
  "id": "string",
  "title": "string",
  "cause": "string",
  "date": "ISO8601",
  "meetingPoint": "string",
  "meetingCoordinate": { "latitude": "number", "longitude": "number" },
  "feePHP": "int",
  "capacity": "int",
  "joinURL": "string",
  "description": "string",
  "photoURL": "string | null",
  "gpxURL": "string | null",
  "distanceM": "int | null",
  "ascentM": "int | null",
  "estimatedMinutes": "int | null",
  "status": "pending | published"
}
```

`meetingCoordinate` is an object with `latitude` and `longitude` as JSON
numbers (doubles are fine). `feePHP` is an integer peso amount. `capacity` is
the number of hiker spots.

`photoURL` and `joinURL` are strings the client opens with `openURL`; the client
validates them as absolute URLs but the server should store and return them
verbatim.

### EventDraft (create only)

Same as `Event` minus `id`, `status`, `gpxURL`, `distanceM`, `ascentM`,
`estimatedMinutes`.

## 5. Behavior rules

### Roles

Every account has exactly one role: `hiker` or `organizer`. Roles are set
server-side (out of band) after a shelter or cause partner is vetted. There is
no self-service path to organizer. The client hides the "Post a Hike" tab from
hikers, but the backend must not rely on that: `POST /events` and
`POST /events/{id}/gpx` return `403` for a hiker regardless of what the client
shows.

### Moderation

A created event starts `pending` and appears in the public `GET /events` list
only after a server-side action flips it to `published`. There is no endpoint
for this in the contract; moderation happens outside the app (a separate admin
surface or direct database change).

### Soft RSVP

`join` is a soft RSVP: it records intent and hands the hiker off to the
organizer's external payment/coordination link (`joinURL`). The app never moves
money. Reconciling payment is the organizer's job, off-app.

### Token lifecycle

- The access token should be short-lived (minutes to an hour). The client
  refreshes proactively when fewer than 60 seconds remain on `expiresAt`, and
  also refreshes and retries once on a `401`.
- The client single-flights concurrent refreshes (many simultaneous in-flight
  requests produce one refresh call). The backend should therefore tolerate
  refresh being called once even when several requests just failed with `401`.
- If the refresh token is invalid or expired, the backend returns `401`, and the
  client signs the user out.

### GPX upload

The backend does not parse or interpret the GPX. It stores the bytes and the
three numbers (`distanceM`, `ascentM`, `estimatedMinutes`) the organizer's phone
computed, and returns them on later `Event` payloads. The organizer's phone, not
the server, is the source of truth for those numbers.

### CORS / HTTPS

Mobile clients do not enforce CORS, so the backend need not set CORS headers.
Production and staging must be HTTPS; the client pins certificates (currently
disabled via config) so a stable, non-rotating TLS certificate is expected
eventually.

## 6. .NET 8 implementation notes (not part of the contract)

Guidance only; the contract above is what must hold.

- ASP.NET Core minimal APIs or controllers both fit. The surface is small:
  4 auth endpoints and 6 event endpoints.
- EF Core with SQL Server or PostgreSQL works. Suggested tables:

  - `Users`: `Id`, `Email` (unique index), `PasswordHash`, `Role`.
  - `Events`: `Id`, `Title`, `Cause`, `Date`, `MeetingPoint`, `Latitude`,
    `Longitude`, `FeePHP`, `Capacity`, `JoinURL`, `Description`, `PhotoURL`,
    `GpxURL`, `GpxStorageKey`, `DistanceM`, `AscentM`, `EstimatedMinutes`,
    `Status`.
  - `EventJoin` (many-to-many): `UserId`, `EventId`.

- Password hashing: `Microsoft.AspNetCore.Identity.PasswordHasher<TUser>` or
  ASP.NET Core Identity. Do not store plaintext.
- JWT: set `expiresAt` (the `exp` claim) to the absolute expiry and mirror it in
  the `expiresAt` response field. Include `sub` (user id) and `role` claims.
- Serialization: configure `System.Text.Json` with
  `PropertyNamingPolicy = JsonNamingPolicy.CamelCase`. Be careful with
  `feePHP`: a property named `FeePHP` serializes to `feePHP` under camelCase,
  but verify, because the client is exact.
- The GPX file can live on local disk, S3, or any blob store. `gpxURL` in the
  `Event` payload can be any string; the client fetches the bytes from
  `GET /events/{id}/gpx` (the authenticated route), not from `gpxURL`.

## 7. Open decisions

These are deliberate unknowns; the client does not depend on their answers.

- Refresh token rotation policy (rotate on every refresh vs. fixed until expiry).
- Access and refresh token lifetimes.
- Whether `join` should be reversed (an un-join endpoint). The client has none.
- Event id scheme (slug, GUID, integer-as-string). The client treats it as an
  opaque, path-safe string.
- Admin/moderation surface for flipping `pending` to `published`. Out of app
  scope.
