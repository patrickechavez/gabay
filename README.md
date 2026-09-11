# Gabay

A production-ready SwiftUI app template. MVVM + Repository, Swift 6 strict concurrency, a complete auth lifecycle, and one third-party dependency — Firebase, kept behind protocol seams so the rest of the app never touches it.

- iOS 17+ · Swift 6 · Xcode 26

## Getting started

Clone, rename, and you have a running app in under ten minutes.

### 1. Clone and rename

Three commands. Substitute your own values.

```bash
git clone <this-repo> MyApp
cd MyApp
Scripts/rename.sh MyApp com.acmecorp "My App"
```

The three arguments to the script:

| | | |
|---|---|---|
| `MyApp` | required | The app name. Becomes the target, the source folder, and a Swift type, so it takes letters and digits only, starting with a letter — no spaces or hyphens. |
| `com.acmecorp` | required | Your bundle prefix. Lowercase reverse-DNS, at least two components. |
| `"My App"` | optional | The home screen name, quoted because it can contain spaces. Leave it off when it matches the app name — `Scripts/rename.sh Runly com.acmecorp` gives an app called Runly. |

This renames the project, target, schemes, source folder, app entry point, and every file header, and rewrites the bundle IDs, display names, and deep link scheme. It needs a clean working tree, so `git checkout . && git clean -fd` undoes any run.

### 2. Start your own history

```bash
rm -rf .git && git init && git add -A && git commit -m "Initial commit"
```

### 3. Finish the setup

The app builds and runs as-is. Three things the script can't do for you.

- **Your API** — set `API_BASE_URL` in each of the three `Config/*.xcconfig`
- **App icon and colours** — all ship empty. See [Branding](#branding)
- **Firebase** — *optional*. Without a `GoogleService-Info.plist` the app builds fine and analytics and crash reporting are off. See [Firebase](#firebase) to turn it on, or to remove it.

```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Removing the sample

`Item` is a worked example, not something to build on. Keep it while you write your first real feature — it's the only place pagination, `LoadState`, and the repository pattern are shown working end to end — then delete it.

```
Features/Dashboard/HomeView/          the list screen
Features/Dashboard/ItemDetailView/    the detail screen
Data/ItemRepository.swift
Models/Models.swift                   the Item and ItemDraft types
Core/Testing/Mocks.swift              SampleData.items and MockItemRepository
```

Then remove `makeHomeViewModel`, `makeItemDetailViewModel` (both overloads), and the `items` property from `AppDependencies`, and drop `.itemDetail` from `HomeRoute`. The compiler finds anything you miss.

## What's inside

- **Networking** — one send path with verb helpers, typed errors, server-message parsing, interceptors, retry with backoff
- **Auth** — access + refresh tokens, single-flight refresh, 401 to refresh to retry to sign-out, Keychain storage
- **Navigation** — typed routes, deep links, universal links, deferred links, force-update and maintenance gates
- **UI** — design system, unified `LoadState`, empty / error / skeleton states, accessibility identifiers, localization via String Catalog
- **Images** — bounded two-tier cache with LRU eviction and in-flight de-duplication
- **Connectivity** — `NWPathMonitor` behind an offline banner, so a failing screen reads as a connection problem
- **Observability** — analytics and crash reporting behind protocols, with Firebase adapters; non-fatals recorded with no per-feature wiring
- **Build** — three environments, privacy manifest, one-command rename

The service gates are driven by HTTP status, not by a version endpoint. A `426` blocks the app behind "Update Required" and a `503` behind "Back Soon", both routed through `SessionEventBus`. `APIConfig.isForceUpdateEnabled` and the `VersionCheck` model belong to a client-side version-comparison approach that isn't built — delete them, or wire them to a version endpoint if you prefer that shape.

Scaffolded but **not** wired — push notifications, see below.

## Architecture

```
View (SwiftUI, no logic)
  ↕ @Observable
ViewModel (@MainActor, owns LoadState)
  ↕ protocol
Repository (maps API to models)
  ↕ protocol
APIClient (one send path + interceptors)
```

Each layer depends on the protocol below it. `AppDependencies` is the one place concrete types meet, which is what makes it testable and swappable.

## Branding

Everything you replace per project lives in `Gabay/Assets.xcassets`. All three ship empty.

### App icon

Open `Assets.xcassets` -> `AppIcon` and drag a PNG onto each well. There are three 1024x1024 slots:

| Slot | Used when |
|---|---|
| **Any Appearance** | Always. The only one that is required. |
| **Dark** | Home screen in dark mode |
| **Tinted** | Home screen with a tint applied |

Fill the first and iOS derives the other two. Fill all three when you want control over each.

**Rules Apple enforces:**

- **1024 x 1024**, square
- **No alpha channel.** Transparency is rejected at upload with `ITMS-90717`, and iOS composites it against black. Check yours with `sips -g hasAlpha icon.png`
- **Edge to edge**, no padding of your own. iOS applies a rounded mask that crops the corners, so keep important detail inside the middle 80%
- **No rounded corners, no shadows.** iOS adds those

The icon renders at 60 x 60 pt on the home screen, about 17x smaller than the file. A small mark floating in empty space disappears at that size.

### Accent colour

`AccentColor` has no value set, so SwiftUI falls back to system blue. Give it **Any** and **Dark** appearances in the asset catalog.

Everything that reads `Theme.Color.accent` picks it up - buttons, links, control tints.

### Launch background

`LaunchBackground` is used by `RootView` while the session is bootstrapping, and by `PrivacyShieldView` in the app switcher.

It does **not** set the system launch screen, which is currently the default background. To match them and remove the flash on launch, add this to `Config/Shared.xcconfig`:

```
INFOPLIST_KEY_UILaunchScreen_BackgroundColor = LaunchBackground
```

## Environments

Three configs, one shared base. All install side by side on one device.

| | Development | Staging | Production |
|---|---|---|---|
| Bundle ID | `.dev` | `.staging` | *(none)* |
| Request logging | on | off | off |

Values live in `Config/*.xcconfig` and reach code through `APIConfig`. Never hardcode a URL.

## Secrets

Client SDK keys you'd rather not publish go in `Config/Secrets.xcconfig`, which is gitignored. Copy `Secrets.example.xcconfig`, drop the `.example`, fill it in — all three environments already `#include?` it, and the `?` means a clone without the file still builds.

Everything there is substituted into Info.plist and ships inside the IPA. It keeps values out of git, not off a device. Server-side keys belong on your server.

## Hardening

Four opt-in protections. Two of them — jailbreak and anti-debug — are heuristic and report-only by design, so they flag rather than block.

> **Pinning is optional.** The app is fully safe and behaves like a normal HTTPS app while `PINNED_PUBLIC_KEY_HASHES` is left blank — an empty list means default TLS trust, no extra rules. You only need to fill it in once you have a real production backend and want the extra protection.

### Certificate pinning

Pins the server's **public key** (SPKI), not the certificate, so a certificate renewal with the same key doesn't break the app.

`CERT_PINNING_ENABLED = NO` in all three configs, because there is no backend to pin against yet. Keep it off in Development and Staging even after you have one, so local proxies (Charles, Proxyman) and self-signed certs still work. Turn it on in Production only once `PINNED_PUBLIC_KEY_HASHES` has real values — enabling it with an empty list claims pinning while performing none.

1. Generate the base64 SPKI hash for each endpoint's leaf certificate:

   ```bash
   openssl s_client -connect api.example.com:443 -showcerts </dev/null 2>/dev/null \
     | openssl x509 -pubkey -noout \
     | openssl pkey -pubin -outform der \
     | openssl dgst -sha256 -binary \
     | base64
   ```

2. Paste the output into `PINNED_PUBLIC_KEY_HASHES` in `Config/Production.xcconfig`, comma-separated for multiple keys.

The pinner compares that to the hash the running app computes from the server's presented certificate. Leave the list empty and it falls back to default TLS trust — a safe no-op until you add real hashes. A failed match surfaces as a `.serverTrustFailed` error.

### Screen-capture / app-switcher privacy

A `PrivacyShieldView` covers the UI whenever the app is not active, so the task-switcher snapshot is blank. iOS can't prevent screenshots, so instead the app detects them (`ScreenshotDetector`) and records a `screenshot_captured` analytics event — capture is observable, not blockable.

### Jailbreak detection

`JailbreakDetector` checks for the usual filesystem indicators (Cydia, Sileo, sshd, …). It is **report-only**: jailbreak checks are trivially bypassable and can false-positive, so the app flags the device in analytics rather than refusing to run.

### Anti-debug

`DebuggerDetector` reads the `P_TRACED` process flag via `sysctl` and reports an attached debugger. Deliberately no `ptrace(PT_DENY_ATTACH)` — that reads as anti-tampering to App Review and can get a submission rejected. Obfuscation beyond the existing Release symbol-stripping is intentionally not attempted.

## Firebase

Analytics and Crashlytics via SPM, behind protocols — only `FirebaseObservability.swift` imports Firebase.

**It is optional.** With no `GoogleService-Info.plist` the app builds and runs; analytics and crash reporting fall back to no-ops and the build prints:

```
warning: No Firebase plist at ... - building without Firebase.
```

That is the normal state of a fresh clone, not a broken checkout.

### Turning it on

1. Create a Firebase project per environment.
2. Register an iOS app in each, using that environment's bundle ID.
3. Drop each `GoogleService-Info.plist` into its folder, creating folders as needed.

```
Gabay/Firebase/
├── Development/GoogleService-Info.plist
├── Staging/GoogleService-Info.plist
└── Production/GoogleService-Info.plist
```

Nothing else — `FirebaseBootstrap.start()` finds the plist at launch and installs the Firebase adapters. Add only the environments you need; the others keep building without it.

The folders are absent from git because the plists are gitignored.

Leave **Target Membership unchecked** on every plist. The `Copy GoogleService-Info.plist` phase picks the right one from `$CONFIGURATION` and fails the build if its `BUNDLE_ID` doesn't match the target's. Checking membership makes Xcode copy it too, and the build stops with `Multiple commands produce`.

Crashlytics symbols upload automatically. `Upload Crashlytics dSYM` skips Development, which keeps its symbols in the binary, and skips any configuration with no plist.

### Removing it

For a project that doesn't use Firebase:

1. Delete `Gabay/Core/Observability/FirebaseObservability.swift`
2. Remove the `firebase-ios-sdk` package in Xcode
3. Delete `Gabay/Firebase/` and both build phases — `Copy GoogleService-Info.plist` and `Upload Crashlytics dSYM`

Nothing else changes. Every `Observability.analytics.track(...)` and `Observability.crashes.record(...)` call keeps compiling and does nothing.

### Using something else

Write one file conforming to `AnalyticsTracking` and `CrashReporting`:

```swift
struct SentryCrashReporter: CrashReporting {
    func record(_ error: any Error) { SentrySDK.capture(error: error) }
    func log(_ message: String) { SentrySDK.addBreadcrumb(.init(message: message)) }
    func setUser(id: String?) { SentrySDK.setUser(id.map { User(userId: $0) }) }
}
```

Then change the one line in `AppDependencies.live()` that calls `FirebaseBootstrap.start()`. No view, view model, or call site changes.

### Push is not wired

`UserRepository` declares `registerForPushNotifications(token:)` and `unregisterForPushNotifications(token:)`. **Nothing calls them**, and `FirebaseMessaging` is no longer configured — the `MessagingDelegate` conformance was removed to keep Firebase out of the app's entry point.

To finish it:

- Add `import FirebaseMessaging` and the `MessagingDelegate` conformance back to `AppDelegate`, and set `Messaging.messaging().delegate` after `FirebaseBootstrap.start()` has run
- Ask for permission and call `registerForRemoteNotifications()`
- Set `Messaging.messaging().apnsToken` in `didRegisterForRemoteNotificationsWithDeviceToken`
- Send the FCM token to your backend, and clear it on sign-out
- Route taps through `AppNavigator`, which already handles deep links
- Add the **Push Notifications** capability, and upload an APNs `.p8` to each Firebase project

The last one needs a paid Apple Developer membership. FCM does not replace APNs on iOS — it forwards through it, and the `.p8` authorises Firebase to do that on your behalf.

## Structure

```
Gabay/
├── App/              entry point, composition root
├── Components/       reusable inputs, buttons, picker
├── Core/
│   ├── Images/       two-tier image cache
│   ├── Navigation/   typed routes, deep links
│   ├── Networking/   client, endpoints, errors, interceptors
│   ├── Session/      tokens, refresh, session state
│   └── UI/           LoadState, AsyncContentView
├── Data/             repositories
├── Firebase/         one GoogleService-Info.plist per environment
├── DesignSystem/     theme, accessibility identifiers
├── Features/         one folder per screen
├── Models/           models, pagination
└── Resources/        String Catalog
```

## Apple Developer account

Not needed to build, run, or develop against this template. The simulator needs nothing, and a free Apple ID signs builds onto your own device.

A paid membership is required for exactly two things.

- **Push notifications** — the capability and the APNs `.p8` are both members-only
- **Distribution** — TestFlight and the App Store

Everything else works without one, which is why push stays scaffolded rather than half-implemented.

## Before you ship

- Real API URLs in all three xcconfigs
- All three `GoogleService-Info.plist` files in place
- The `Item` sample removed
- Review `PrivacyInfo.xcprivacy` against what your backend stores
- App icon and accent color
