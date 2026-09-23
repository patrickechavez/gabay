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

The free-trail *catalog and browsing* feature, since there is no longer a
free trail list and recording was explicitly dropped too:

- `Gabay/Core/Trails/` - `TrailCatalogClient`, `CatalogCache`, `TrailStore`,
  `Trail.swift`
- `Gabay/Features/Trail/` - `TrailsView`, the list-browsing parts of
  `TrailDetailView`
- `trails/` at the repo root (catalog.json, the GPX files, its README) and
  its GitHub Pages hosting
- `GabayTests/CatalogCacheTests.swift`, `GabayTests/TrailCatalogClientTests.swift`
- The `recording` branch is abandoned, not merged.

`Gabay/Core/Trails/JSONCoders.swift` is kept, moved to
`Gabay/Core/Networking/APICoders.swift`, and renamed from `.trails` to
`.api` - its flexible ISO8601 date decoding (plain and fractional-second) is
generic JSON-coding behavior, not trail-specific, and `Event.date` needs the
same handling. `GabayTests/JSONCodersTests.swift` stays paired with the
original `Gabay/Core/Trails/JSONCoders.swift`, which is untouched.

**Revised, see "Route (optional GPX)" and "Meeting point" below:**
`GPXParser.swift` and `TrackPoint.swift` are *not* deleted. Nor is
`TrailMapView`'s route-drawing logic. What an organizer's uploaded GPX needs
(parse a file, compute distance and climb, draw a route on a map) is
functionally identical to what these already do for a free trail, so they
move to `Core/Route/` and `Features/Route/`, generalized off "Trail" naming,
rather than being deleted and rebuilt. MapKit and CoreLocation stay in the
app for this reason and for the meeting-point pin-drop picker (a one-shot
current-location read, no background tracking, so only
`NSLocationWhenInUseUsageDescription` is needed, not the "Always" variant
the free-trail app used for background recording).

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

### Meeting point

The organizer picks the meeting point on a map (a pin-drop picker, like a
ride-hailing app) rather than typing coordinates. It opens centered on the
organizer's current location (a one-shot location read) and they tap to
place the pin. The event keeps both the pin (`meetingCoordinate`) and a
short text label (`meetingPoint`, e.g. "Budlaan barangay hall") the
organizer also types, since raw coordinates mean nothing to a hiker
skimming a list. Hikers see the label in the list, and a small map with the
pin plus a "Get Directions" button (opens it in Maps) on the event detail
screen.

### Route (optional GPX)

An organizer can optionally attach a GPX file when posting a hike. It is
view-only for everyone (organizer and hikers): the drawn route, total
distance, total climb, and an estimated hiking time (Naismith's rule:
roughly 12 minutes per km plus 10 minutes per 100 m of climb). The
organizer's phone parses the file on-device (reusing the kept parser) and
uploads both the file and the computed numbers, so a hiker's phone shows
the headline stats without needing to reparse the file itself; it only
reparses if it renders the drawn route. There is no route-following, no
live position, and no relation to the account-free recording feature that
was dropped, this is strictly "look at where it goes before you show up."

### Event fields (organizer form / API payload)

`title, cause, date, meetingPoint, meetingCoordinate, feePHP, capacity,
joinURL, description, photoURL?`, plus `gpxURL?, distanceM?, ascentM?,
estimatedMinutes?` set by the app after a GPX upload (never typed by the
organizer directly).

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
POST /events/{id}/gpx    organizer only, multipart file upload
                                                → Event (now with gpxURL/stats set)
POST /events/{id}/join                         → 204       (marks joined)
GET  /me/events                                → [Event]   ("My Events")
```

`Event`: `id` (string), `title` (string), `cause` (string), `date` (ISO8601
string), `meetingPoint` (string), `meetingCoordinate` (object: `latitude`,
`longitude`, both numbers), `feePHP` (integer), `capacity` (integer),
`joinURL` (string), `description` (string), `photoURL` (string, optional),
`gpxURL` (string, optional), `distanceM` (integer, optional), `ascentM`
(integer, optional), `estimatedMinutes` (integer, optional), `status`
(string enum: `pending` | `published`). The four GPX-derived fields are
all-or-nothing, present only once `POST /events/{id}/gpx` has been called.

Every call after login carries a Bearer token. A `401` anywhere is treated
uniformly: clear the session, show sign-in.

## iOS architecture

Mirrors the pattern the free-trail code already used - protocol-based
client → store → view model → view, views holding no logic - applied to the
new domain instead of inventing a new one.

```
Core/
├── Networking/   APIClient (shared URLSession + JSON coding + auth header +
│                 error mapping), APICoders (moved/renamed, see above)
├── Auth/         AuthClient (protocol), TokenStore (Keychain-backed),
│                 Session (@Observable - signed-in state, role)
├── Events/       EventClient (protocol: list, detail, create, join, mine,
│                 upload a GPX), EventStore (@Observable)
└── Route/        GPXParser, TrackPoint (kept from Core/Trails, generalized),
                  distance/ascent/estimated-time calculation

Features/
├── Auth/         SignInView, SignUpView
├── Events/       EventsListView, EventDetailView,
│                 PostEventView (visible only when Session.role == .organizer),
│                 MyEventsView
└── Route/        RouteMapView (kept from Features/Trail, generalized,
                  draws a parsed route), LocationPicker (new, pin-drop for
                  the meeting point)
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
- A GPX file that fails to parse (truncated, not GPX at all) is refused
  before upload, same as the free-trail app already refused an unreadable
  file on import, the organizer sees an inline error and the rest of the
  form is unaffected since the GPX is optional. A successful parse but a
  failed upload (network) is retryable without re-picking the file.

## Testing

- `AuthClientTests`, `EventClientTests`: same `StubURLProtocol` pattern as
  the removed `TrailCatalogClientTests`, one stub reused for both.
- `TokenStore` tested against a real Keychain item under a test-only service
  name, cleaned up per test.
- `Session` and `EventStore` state-transition tests (signed out → signed in
  → role-gated UI, list loading → loaded/error).
- The kept `GPXParser`/`TrackPoint` code brings its existing tests with it
  (renamed off "Trail" the same way the source is); the distance/ascent/
  estimated-time calculation is a pure function and gets its own unit
  tests. `RouteMapView` and `LocationPicker` are map-rendering UI with no
  logic of their own, so, like the other views in this app, they have no
  direct test of their own, only manual verification.
- CI (`tests.yml`, already in place on `main`) runs the same suite
  unchanged - no workflow changes needed for this pivot.

## Out of scope (phase 2 or later)

- The C# backend itself - separate project, separate spec (now including a
  file-upload endpoint for GPX, per "Route (optional GPX)" above).
- DSWD / local-government partnership and solicitation permits.
- In-app payment.
- Actually following an event's route live (a walking GPS overlay, "you are
  here" on the trail). The route view is look-before-you-go, not
  navigation.
- Linking a recorded walk to a joined event (moot in phase 1 - recording
  itself is removed).
- Sign in with Apple.
