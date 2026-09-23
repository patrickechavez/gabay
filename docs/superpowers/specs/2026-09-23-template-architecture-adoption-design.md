# Adopting the ios-app-template architecture

## Why

Gabay's events platform (see
`2026-09-23-events-platform-design.md`) was built over fourteen tasks with a
hand-rolled networking layer and no repository layer. The ios-app-template at
`/Users/patrick/Projects/AppTemplate` already solves the same problems more
thoroughly, and Gabay is partly descended from it already: `LoadState`,
`LoadableViewModel`, `ErrorStateView`, `Theme`, `AppLogger`, `Breadcrumb` and
the `Observability` protocols are all the same lineage. What the events work
did was re-invent a thinner `APIClient` and `TokenStore` beside infrastructure
the template had already gotten right.

This spec re-seats Gabay on the template's conventions: its networking stack,
its Keychain and token-refresh handling, its form components, its
MVVM-with-repositories layering, and the supporting pieces (observability,
offline awareness, navigation).

A branch-wide architecture audit run against the events code returned one
Critical and eight Important findings. Some are fixed simply by adopting the
template. The rest are Gabay's own and are folded into this work, because the
app should not sit with a known crash path and a broken upload while a port
happens around it.

## Relationship to the events-platform spec

This spec amends, and does not replace, `2026-09-23-events-platform-design.md`.
The product decisions there (cause-hike events, external payment link, soft
RSVP, organizer roles, optional GPX route, pin-drop meeting point) all stand.

One part of that document is superseded: its **API contract** section, for the
auth endpoints only. See "API contract amendment" below. The events endpoints
are unchanged in shape.

## Verify the baseline first

Nothing on the `events-platform` branch has been compiled. Twenty-six commits,
fourteen tasks, zero builds: the review loop caught six real defects by
reading, but a compiler finds a different class of problem. The project owner
runs the build and test suite before this work starts, and anything it
surfaces is folded into Slice 4 rather than discovered underneath three ported
layers.

## Target structure

```
Gabay/
├── App/            AppDependencies (composition root, make*ViewModel factories)
├── Components/     ported form and chrome components
├── Core/
│   ├── Networking/ Endpoint, APIClient protocol + URLSessionAPIClient,
│   │               APIError, RetryPolicy, APIConfig, Interceptors/
│   ├── Storage/    KeychainTokenStore (actor), InMemoryTokenStore
│   ├── Auth/       TokenRefreshCoordinator, Session
│   ├── Navigation/ Router, AppRoute, DeepLink
│   ├── Route/      GPXParser, TrackPoint, RouteStats, RouteSummary
│   ├── UI/         LoadState, LoadableViewModel, ActionState, ErrorStateView
│   └── Observability/
├── Data/           EventRepository, AuthRepository (protocol + Live impl)
├── DesignSystem/   Theme
├── Features/       Auth, Events, Route (views plus view models)
└── Resources/
```

`EventClient` and `AuthClient` cease to exist as bespoke clients. Their calls
become `Endpoint` values, and repositories invoke them through the shared
`APIClient`.

## Collision hazards

Three separate name collisions have already broken this branch (`RouteMapView`
and `RouteCasing` against the legacy trail code, `UTType.gpx`, and a missing
`Hashable`). The port introduces more, because Gabay and the template share
ancestry and therefore share type names. Every one of these must be resolved
deliberately, by replacing Gabay's copy, never by letting both exist:

- `APIClient` - Gabay has `struct APIClient`, the template has
  `protocol APIClient` plus `URLSessionAPIClient`.
- `APIError` - both declare one; the template's is far richer.
- `JSONDecoder.api` / `JSONEncoder.api` - Gabay's `Core/Networking/APICoders.swift`
  and the template's coders both define these.
- `ErrorStateView` - same lineage, since diverged (Gabay's copy was rewritten
  for events in Task 9). Reconcile, do not copy both.
- `LoadState`, `LoadableViewModel` - present in both. Gabay's stays; the
  template's `ActionState` is additive and comes across.
- `Theme` - present in both. Gabay's stays unless a ported component needs a
  token it lacks, in which case the token is added, not the file replaced.
- `TokenStore` - Gabay's is a `struct` conforming to `TokenStoring`; the
  template's is an `actor`.

Because `APIClient`, `APIError` and the JSON coders cannot coexist even
briefly, Slice 2 cannot be a gradual migration. It lands as one commit that
deletes the old and adds the new together.

## Slice 1: Components into the screens

Independent of every other slice, and first because it is low risk and
immediately visible.

Ported from the template's `Components/`: `FieldContainer` (the shared
label/error/required chrome), `AppTextField`, `EmailField`, `PasswordField`,
`DateField`, `PickerField`, and `Alert/AlertState.swift`. `PhoneField`,
`UsernameField`, `SearchField`, `ImagePicker` and `PrivacyShieldView` are not
ported; nothing in Gabay needs them yet.

Applied to:

- `SignInView` and `SignUpView`: hand-rolled `TextField`/`SecureField` pairs,
  each repeating `.textContentType`, `.keyboardType` and
  `.textInputAutocapitalization`, become `EmailField` and `PasswordField`,
  which carry those settings themselves.
- `PostEventView`: nine hand-rolled fields become `AppTextField`, `DateField`
  and the numeric variants.

This closes a real gap rather than merely tidying. The events-platform spec
requires that organizer-form validation errors "surface inline, field by
field, rather than as a generic error banner." The current form shows a single
generic alert for everything. `FieldContainer`'s per-field error slot is what
makes the specified behavior possible, so Slice 1 also adds per-field error
state to `PostEventViewModel` and renders it.

## Slice 2: Networking and token storage

Ported from the template: `Endpoint`, the `APIClient` protocol and
`URLSessionAPIClient`, `APIError`, `RetryPolicy`, `APIConfig`, the
`RequestInterceptor` protocol with the auth and logging interceptors, the
`KeychainTokenStore` actor with `InMemoryTokenStore`, and
`TokenRefreshCoordinator`. Exact source paths are confirmed against the
template during planning.

What this brings that Gabay lacks: per-endpoint timeouts, exponential backoff
honoring `Retry-After` on idempotent requests, redacted request and response
logging behind a build flag, a typed error surface (`.offline`,
`.unauthorized`, `.validation`, `.rateLimited(retryAfter:)`, `.updateRequired`,
`.maintenance`) with localized messages, and Keychain storage that specifies
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which Gabay's current store
does not set at all.

Two consequences are load-bearing:

**The token store becomes an actor, so `load()` becomes async.** Gabay wires
`APIClient(tokenProvider: { tokenStore.load() })` as a synchronous closure in
`AppDependencies.live()`. That closure, `Session`'s three call sites and the
composition root all become async. This also resolves the audit's finding that
every request pays a synchronous Keychain hit on the main actor.

**401 handling moves into the interceptor.** Gabay currently signals expiry by
throwing `CancellationError` from `EventsViewModel`, which the audit found
strands the list in `.idle` behind a spinner that can never reload. The
interceptor refreshes and retries once instead, and only a failed refresh
reaches the session as a sign-out.

Certificate pinning is ported but stays inert, exactly as in the template:
`CERT_PINNING_ENABLED = NO` with empty hashes in all three xcconfigs, wired as
the session delegate and ready for real SPKI hashes when Gabay has a backend
to pin against.

## API contract amendment

Supersedes the auth endpoints in the events-platform spec. The events endpoints
are unchanged.

```
POST /auth/register  { email, password }
                     → { accessToken, refreshToken, expiresAt, role }
POST /auth/login     { email, password }
                     → { accessToken, refreshToken, expiresAt, role }
POST /auth/refresh   { refreshToken }
                     → { accessToken, refreshToken, expiresAt }
GET  /me             → { email, role }
```

`expiresAt` is an ISO8601 string. The interceptor refreshes proactively as
expiry approaches and single-flights concurrent refreshes, so simultaneous
in-flight requests produce one refresh, not several.

This is made now, while the C# backend is still unwritten, because changing a
contract before anything implements it costs nothing and changing it afterward
costs a backend revision plus a client migration.

## Slice 3: Repository layer

Gabay's view models currently call network clients directly. The template puts
protocol-based repositories between them, and this slice does the same:

- `Data/AuthRepository.swift`: `protocol AuthRepository` plus
  `LiveAuthRepository`, covering register, login, refresh and the current
  account.
- `Data/EventRepository.swift`: split along the lines the audit identified, so
  no consumer depends on methods it does not use. `EventBrowsingRepository`
  covers listing, joined events and joining; `EventPublishingRepository`
  covers creating an event and attaching a GPX. `LiveEventRepository` conforms
  to both.

The dead `event(id:)` method is dropped; it has no production caller, and its
only cost today is a force-unwrap in the test double that exists solely to
satisfy it.

View models take repositories, and `AppDependencies` builds them. Test doubles
move to the repository boundary, which is a smaller and more honest seam than
stubbing a six-method network protocol.

## Slice 4: Gabay-specific audit fixes

These survive the port and are fixed here. File references are from the audit.

**Critical.** `Core/Route/RouteStats.swift:31` traps on non-finite input:
`Int((seconds / 60).rounded())` crashes when distance is NaN or infinite.
`GPXParser.swift:100` accepts any string `Double.init` parses, and
`Double("nan")` succeeds, so a GPX with `lat="nan"` reaches it. This is
reachable from an organizer's picked file and from backend-supplied GPX on a
hiker's device. Fix: the parser rejects any point whose latitude is not finite
or falls outside -90 to 90, or whose longitude is not finite or falls outside
-180 to 180, and whose elevation, when present, is not finite; `RouteStats`
additionally guards against a non-finite total before converting to `Int`. The
same fix closes a non-finite `MKMapRect` path in `RoutePreviewMap`.

**Important.**

- `PostEventViewModel` reads a `fileImporter` URL without
  `startAccessingSecurityScopedResource()`, so GPX files in iCloud Drive or
  Files fail to read. It also stores the URL and re-reads it later during
  upload, by which point the scope is gone regardless. Fix: take
  security-scoped access and read the bytes at pick time, hold `Data`, and
  have the upload take `Data`. The legacy `TrailStore` did this correctly, so
  this is a regression against a lesson the codebase had already learned.
- `EventDetailView` fetches with `URLSession.shared`, bypassing the client
  entirely, and parses GPX on the main actor. Fix: an `EventDetailViewModel`
  conforming to `LoadableViewModel`, fetching through the repository and
  parsing off the main actor. Slice 2 and 3 provide the seam; this makes the
  screen testable, which it currently is not.
- `LocationPicker`'s `OneShotLocator` claims `@unchecked Sendable` on the
  grounds that only one request is ever in flight, which is untrue: on
  `.notDetermined` it calls `requestLocation()` once directly and again from
  the authorization callback. No double-resume occurs today only because
  CoreLocation happens to serialize its callbacks. It also leaks: if the
  permission dialog is never answered, no callback fires, the continuation is
  never resumed, and the `.task` hangs. Fix: guard the continuation, resume
  exactly once, handle cancellation, and hold the `CLLocationManager` in
  `@State` rather than reallocating it per body evaluation.
- `GabayTests/Support/StubURLProtocol.swift` is shared by four suites through
  global static state. Swift Testing runs suites in parallel, so one suite's
  `reset()` can wipe another's queued reply. Per-suite `.serialized` does not
  help across suites. Fix: nest the suites that share the stub under one
  serialized parent.
- `MyEventsView` decides emptiness from `viewModel.mine.isEmpty`, so it shows
  "No events joined yet" while loading and again when loading failed, with no
  retry. Fix: give joined events their own `LoadState` and route failures
  through `ErrorStateView`.
- `routeSummary` is duplicated between `EventDetailView` and `PostEventView`,
  and both copies render a 45 minute hike as "~0h 45m" and hardcode English
  "h" and "m" in files that otherwise localize everything. Fix: one
  `RouteSummary` formatter in `Core/Route`, using `Duration.UnitsFormatStyle`,
  with tests.

**Minor.** The multipart `filename` is interpolated into a
`Content-Disposition` header unescaped, so a GPX named `a".gpx` corrupts the
body; the template's upload path replaces this, and the replacement is checked
for the same flaw. Three stale prose comments and two orphaned
`Localizable.xcstrings` entries left by the cutover are removed.

## Slice 5: Supporting infrastructure

- **Observability.** Port `FirebaseObservability.swift` and add the Firebase
  SDK, wired to the existing `AnalyticsTracking` and `CrashReporting`
  protocols Gabay already has. It stays gated behind a `GoogleService-Info.plist`
  existence check with no-op fallbacks, so a checkout without that file
  behaves exactly as today. Scope is Analytics and Crashlytics only, matching
  the template.

  This is a deliberate, decided exception to a standing constraint. Both the
  events-platform spec and its implementation plan state "no third-party
  dependencies" as a global rule, and Firebase breaks it: the template pins
  `firebase-ios-sdk` 12.17.0 plus eight transitive packages. Firebase is
  adopted anyway, so that constraint is amended in both documents and in the
  README as part of this slice rather than quietly contradicted. The amended
  wording is "no third-party dependencies other than the Firebase SDK."

  The deciding reason is push notifications. Firebase Cloud Messaging is
  planned as a near-term follow-on so organizers can reach the hikers who
  joined an event, which makes the SDK a dependency this app was going to take
  regardless. Slice 5 adds the SDK and the Analytics and Crashlytics wiring
  only. FCM itself, the push entitlement, the `APNs` registration and the
  notification permission prompt are out of scope here and get their own spec;
  this slice just stops that work from having to introduce the dependency
  under time pressure.
- **Offline awareness.** Port `NetworkMonitor` and `OfflineBanner`. A hiker
  checking an event at a trailhead with no signal is a real case for this app.
- **Navigation.** Port `Router`, `AppRoute` and `DeepLink`, replacing the
  ad hoc `navigationDestination(item:)` and `@State` selection in
  `EventsListView`. This also removes the reason `Event` had to be `Hashable`.

Not ported: the jailbreak, debugger and screenshot detectors. They exist in the
template and work, but nothing there calls them, and Gabay has no threat model
that asks for them. Porting unused security theater would add code nobody
reads. Biometric authentication is not in the template at all.

## Error handling

`APIError` becomes the single classification point, replacing
`LoadFailure.classify`'s narrow `URLError` handling. `LoadState` and
`ActionState` funnel through it, so a rate-limited or maintenance response
produces a meaningful message instead of a generic failure. Sign-out happens
only when a refresh genuinely fails, not on the first 401.

## Testing

- Repositories are the stubbing seam; `StubEventFetching` is replaced by
  repository doubles.
- `InMemoryTokenStore` from the template replaces the hand-rolled
  `StubTokenStore`.
- New tests: `RouteSummary` formatting (including the sub-hour case that is
  currently wrong), GPX coordinate validation rejecting non-finite values,
  `RouteStats` clamping, and `OneShotLocator` resuming exactly once across
  success, failure, denial and cancellation.
- Existing suites that share `StubURLProtocol` are nested under one serialized
  parent.
- CI (`tests.yml`) needs no change.

## Sequencing

Slice 1 is independent and lands first. Slice 2 must precede Slice 3, since
repositories are written against the final client. Slice 4 is mostly
independent, except that the `EventDetailView` fix depends on Slices 2 and 3.
Slice 5 lands last. Each slice ships on its own and is separately reviewable.

The events-platform plan's remaining tasks (README rewrite, final
verification) run after all five slices, since both describe the finished
state.

## Out of scope

- The C# backend itself, still a separate project. This spec changes the
  contract it must implement.
- DSWD and local-government partnership, in-app payment: unchanged from the
  events-platform spec.
- Live route following. The route view remains look-before-you-go.
- Sign in with Apple.
- Push notifications. Slice 5 adds the Firebase SDK partly so the planned FCM
  work has it already, but no messaging, entitlement, device-token
  registration or permission prompt is built here.
- Extracting the template's networking into a shared package. The files are
  copied, which is how the template is meant to be used. Gabay may diverge.
