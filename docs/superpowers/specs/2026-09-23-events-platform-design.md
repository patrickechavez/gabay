# Events platform: pivot from free trails to cause-hikes

## Why

Gabay was a free GPX trail viewer: no accounts, no server, no payments. The
new goal is different in kind, not degree - a platform where hikers pay a
small registration fee (₱200-300) to join an organized hike, with the fee
going to an animal shelter or a person needing medical help. That requires
accounts, organizers, and money changing hands, none of which the free-trail
app needed.

Phase 1 deliberately avoids government/DSWD solicitation-permit territory by
never moving money through the app: joining hands off to an external link the
organizer controls. Formal partnership with local government is a phase 2
concern, out of scope here.

## Scope

This spec covers the **Gabay iOS app only**. It assumes a C# backend that
does not exist yet and will be specced and built separately; the contract in
this document is what the iOS app is built against so it can point at that
backend the moment it exists.

Two pieces of work, both on the `events-platform` branch (created from
`main` at `b9810a6`, which is where the free-trail app's CI/test setup was
committed before this pivot began):

1. Remove the free-trail subsystem.
2. Build the events subsystem: sign-in, browse events, join, and (for
   organizer-flagged accounts) post a new event.

## What gets removed

The entire free-trail feature, since there is no longer a free trail list
and recording was explicitly dropped too:

- `Gabay/Core/Trails/` - `TrailCatalogClient`, `CatalogCache`, `TrailStore`,
  `GPXParser`, `Trail.swift`, `TrackPoint.swift`
- `Gabay/Features/Trail/` - `TrailsView`, `TrailDetailView`, `TrailMapView`,
  `WalkerAnnotationView`
- `trails/` at the repo root (catalog.json, the GPX files, its README) and
  its GitHub Pages hosting
- `GabayTests/CatalogCacheTests.swift`, `GabayTests/TrailCatalogClientTests.swift`,
  and any GPX-parsing tests
- The `recording` branch is abandoned, not merged.
- No MapKit, no CoreLocation, no offline-map handling remain anywhere in the
  app after this change.

`Gabay/Core/Trails/JSONCoders.swift` is kept, moved to
`Gabay/Core/Networking/JSONCoders.swift`, and renamed from `.trails` to
`.api` - its flexible ISO8601 date decoding (plain and fractional-second) is
generic JSON-coding behavior, not trail-specific, and `Event.date` needs the
same handling. `GabayTests/JSONCodersTests.swift` moves and renames with it.

## What gets built

### Accounts

- Email/password against the C# backend. No Sign in with Apple in phase 1
  (noted as an App Store 4.8 compliance gap to revisit before submission,
  since offering third-party sign-in later would require adding it).
- Every account has a role: `hiker` or `organizer`. Roles are set outside
  the app (directly by whoever administers the backend) after vetting a
  shelter/cause partner - there is no self-service way to become an
  organizer inside the app.
- Session token lives in the Keychain. A `401` from any endpoint clears the
  session and returns to sign-in.

### Events

- Hikers see a list of published events: title, cause, date, meeting point,
  fee, capacity.
- "Join" opens an external link (the organizer's payment/coordination
  channel - GCash, Messenger, a payment page, whatever the organizer
  controls) and marks the event as joined on the account. This is a soft
  RSVP, not proof of payment; reconciling who actually paid is the
  organizer's job, off-app.
- "My Events" shows what the signed-in hiker has joined.
- Events are informational only in phase 1 - no route, no GPX, no map.
  Following an event's actual route on the day is coordinated by the
  organizer, not the app.
- Organizer-flagged accounts additionally see "Post a hike": a form
  submitting a new event, which starts in a `pending` state and does not
  appear in the public list until approved server-side. Moderation is how
  legitimacy is enforced, not account type.

### Event fields (organizer form / API payload)

`title, cause, date, meetingPoint, feePHP, capacity, joinURL, description,
photoURL?`

## API contract

The iOS app is built against this REST contract; the C# backend implements
it separately.

```
POST /auth/register     { email, password }   → { token, role }
POST /auth/login        { email, password }   → { token, role }
GET  /me                                       → { email, role }

GET  /events                                   → [Event]   (published only)
GET  /events/{id}                              → Event
POST /events             organizer only        → Event (status: pending)
POST /events/{id}/join                         → 204       (marks joined)
GET  /me/events                                → [Event]   ("My Events")
```

`Event`: `id` (string), `title` (string), `cause` (string), `date` (ISO8601
string), `meetingPoint` (string), `feePHP` (integer), `capacity` (integer),
`joinURL` (string), `description` (string), `photoURL` (string, optional),
`status` (string enum: `pending` | `published`).

Every call after login carries a Bearer token. A `401` anywhere is treated
uniformly: clear the session, show sign-in.

## iOS architecture

Mirrors the pattern the free-trail code already used - protocol-based
client → store → view model → view, views holding no logic - applied to the
new domain instead of inventing a new one.

```
Core/
├── Networking/   APIClient (shared URLSession + JSON coding + auth header +
│                 error mapping), JSONCoders (moved/renamed, see above)
├── Auth/         AuthClient (protocol), TokenStore (Keychain-backed),
│                 Session (@Observable - signed-in state, role)
└── Events/       EventClient (protocol: list, detail, create, join, mine),
                  EventStore (@Observable)

Features/
├── Auth/         SignInView, SignUpView
└── Events/       EventsListView, EventDetailView,
                  PostEventView (visible only when Session.role == .organizer),
                  MyEventsView
```

`AuthClient` and `EventClient` both build on the shared `APIClient` rather
than each rolling their own URLSession/error-handling - one place for
timeout, status-code, and decode-error behavior, reused by both.

The composition root shows `SignInView` or the events tab view based on
`Session.isSignedIn`, the same role `TrailStore`/`TrailsView` played before
for the free-trail list. `Core/UI/LoadState` (already in the codebase, not
trail-specific) is reused for every loading/error state instead of writing
new ones.

## Error handling

- Network/decode failures surface through the existing `LoadState` pattern:
  a retry-able error state, never a silent failure.
- `401` → session cleared, sign-in shown. No token-refresh flow in phase 1;
  the backend defines expiry and the app just requires a fresh login.
- `403` on `POST /events` (a hiker-role account hitting the endpoint,
  e.g. through a stale UI state) → treated as a generic error state; the UI
  is not expected to reach this path since the form is role-gated, but the
  client does not assume the server trusts the client's role check.
- Validation errors (`400`/`422`) on the post-a-hike form surface inline,
  field by field, rather than as a generic error banner.

## Testing

- `AuthClientTests`, `EventClientTests`: same `StubURLProtocol` pattern as
  the removed `TrailCatalogClientTests`, one stub reused for both.
- `TokenStore` tested against a real Keychain item under a test-only service
  name, cleaned up per test.
- `Session` and `EventStore` state-transition tests (signed out → signed in
  → role-gated UI, list loading → loaded/error).
- CI (`tests.yml`, already in place on `main`) runs the same suite
  unchanged - no workflow changes needed for this pivot.

## Out of scope (phase 2 or later)

- The C# backend itself - separate project, separate spec.
- DSWD / local-government partnership and solicitation permits.
- In-app payment.
- Event route/GPX/map following.
- Linking a recorded walk to a joined event (moot in phase 1 - recording
  itself is removed).
- Sign in with Apple.
