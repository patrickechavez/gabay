# Gabay

[![Tests](https://github.com/patrickechavez/gabay/actions/workflows/tests.yml/badge.svg)](https://github.com/patrickechavez/gabay/actions/workflows/tests.yml)

An iPhone app for hiking for a cause. Organizers post a hike, hikers join for a small registration fee, and the fee goes to an animal shelter or someone who needs medical help.

Gabay is Filipino for guide.

- iOS 17+ · Swift 6 · Xcode 26 · no third-party runtime dependencies other than the Firebase SDK (SwiftLint is a build-time plugin)

## Why this exists

Hiking groups already organize cause-hikes on Facebook: pay a small fee, join a hike, the money goes to a shelter or someone in need. Gabay gives that its own app: a list of upcoming hikes, who they benefit, what they cost, where to meet, and a way to join.

## What it does

- Sign in or create an account
- Browse published cause-hike events: cause, date, fee, and a map of the meeting point, with directions
- See an organizer's optional GPX route: distance, climb, estimated time, and the path itself, view-only
- Join a hike, which opens the organizer's own payment/coordination link
- See the hikes joined so far, in one list
- Let organizer accounts post a new hike, with a pin-dropped meeting point and an optional GPX, reviewed before it goes public

No account, no analytics, and nothing is uploaded that a hiker did not choose to send. Where somebody walks is not information this app sends anywhere.

## Payment

Gabay never touches money. Joining a hike hands off to an external link the organizer controls (GCash, Messenger, a payment page, whatever they use). The app only remembers that a hiker tapped Join. This is a soft RSVP, not proof of payment: reconciling who actually paid is the organizer's job, off-app.

## Accounts

Every account is either a hiker or an organizer. Organizer accounts are set by hand after vetting a shelter or cause partner. There is no self-service way to become one inside the app.

## The API

The app is built against a REST contract for a C# backend that does not exist yet. The contract (auth, events, joining, GPX upload) is documented in [`docs/superpowers/specs/2026-09-23-events-platform-design.md`](docs/superpowers/specs/2026-09-23-events-platform-design.md). The only value that reaches code from the xcconfigs is `API_BASE_URL`, which points at a placeholder for a local server in Development.

## Building

Nothing to configure. Clone, open, run.

```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Three schemes, three configurations, one shared base in `Config/`. They install side by side, so a development build never replaces the one on a real phone.

| | Development | Staging | Production |
|---|---|---|---|
| Bundle ID | `.dev` | `.staging` | *(none)* |
| Logging | on | off | off |

The meeting-point picker needs a real device to mean anything; the simulator has no useful location.

## Structure

```
Gabay/
├── App/            entry point, composition root
├── Components/     form fields, alerts, the offline banner
├── Core/
│   ├── Auth/       session, token refresh, Keychain token storage
│   ├── Events/     event view models
│   ├── Navigation/ router, app routes, gabay:// deep links
│   ├── Networking/ shared API client, interceptors, retry, pinning
│   ├── Observability/ analytics and crash-reporting seams
│   ├── Route/      GPX parsing, distance/climb/time calculation
│   ├── UI/         LoadState, ActionState, error states
│   └── Validation/ email and input checks
├── Data/           repositories over the API client
├── DesignSystem/   theme
├── Features/
│   ├── Auth/       sign-in, sign-up
│   ├── Events/     the list, an event's detail, My Events, Post a Hike
│   └── Route/      the read-only route map, the meeting-point pin picker
├── Models/         Event, Account
└── Resources/      String Catalog
```

Views hold no logic. A view model owns the state, and everything below it sits behind a protocol, which is what lets the tests run without a network or a Keychain of their own.

```bash
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Every push and pull request runs the same suite on CI, against whichever Xcode and simulator the runner happens to carry.

## Firebase

Analytics and Crashlytics are wired but the SDK is not in the project yet, because adding a package means editing `Gabay.xcodeproj/project.pbxproj`. `Gabay/Core/Observability/FirebaseObservability.swift` is guarded by `#if canImport(FirebaseCore)`, so it compiles to no-ops today and the real implementation takes over once the package is there, with no other code change.

To turn it on:

1. Xcode, File > Add Package Dependencies, `https://github.com/firebase/firebase-ios-sdk`.
2. Add `FirebaseAnalytics` and `FirebaseCrashlytics` to the Gabay target.
3. Drop `GoogleService-Info.plist` into the target. Without it the code still no-ops, so a checkout without the file behaves exactly as it does now.
4. For readable crash reports, add a run script build phase that uploads dSYMs (`${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`), with `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}` and `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` as input files.

Note that until step 1 is done, nothing compiles the Firebase branch of that file, so mistakes in it will only surface then.

To remove Firebase instead, delete `FirebaseObservability.swift`; `AppDependencies` already falls back to the no-op trackers.

## Not built yet

- The events/auth backend itself: a separate project, built in C#.
- In-app payment.
- Partnership with local government and DSWD for solicitation permits, deliberately deferred since payment never moves through the app.
- Actually following a route live (a walking GPS overlay). The route view is look-before-you-go, not navigation.
- Sign in with Apple.
- Push notifications. The Firebase SDK is present partly so this has a place to land, but no messaging, entitlement, or permission prompt exists yet.
