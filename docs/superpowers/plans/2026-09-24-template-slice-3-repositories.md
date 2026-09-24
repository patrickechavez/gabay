# Template Slice 3: Repository Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put protocol-based repositories between Gabay's view models and its API client, splitting the event protocol so no consumer depends on methods it does not use.

**Architecture:** Gabay already has the shape of a repository layer under different names: `Authenticating`/`AuthClient` and `EventFetching`/`EventClient` are `Sendable` protocols with struct implementations over `any APIClient`, and the view models already depend on the protocols. This slice is therefore mostly a rename plus one real change: `EventFetching` splits into `EventBrowsingRepository` and `EventPublishingRepository`, and the dead `event(id:)` method is dropped. Domain models move out of the client files into `Models/`, and the implementations move to `Data/`, matching the template's layout.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, `@Observable`, Swift Testing.

## Global Constraints

- **Do not write new test cases.** User instruction, 2026-09-24. Existing tests are migrated to the new type names only. One test case is deleted (`readsOneEvent`, see Task 3) because the method it covers is being removed. Nothing else in the suite changes in count or in what it asserts. The `@Test` count must go from 249 to 248 and no other number.
- **Do not run `xcodebuild` or `xcrun simctl`.** The user runs all builds and tests personally. `xcrun --show-sdk-path` and `xcrun --find` are permitted and are used by the verification script below.
- **Never edit `Gabay.xcodeproj/project.pbxproj`.** `Gabay/` and `GabayTests/` are `PBXFileSystemSynchronizedRootGroup`s, so new files and new folders are picked up automatically. Adding `Gabay/Models/` and `Gabay/Data/` needs no project edit.
- **Never edit or commit `Gabay/Resources/Localizable.xcstrings`.** It is dirty in the working tree and stays that way. Never `git add` it.
- **No em dashes** anywhere: code, comments, docs, commit messages.
- **No attribution trailers** in commit messages. No `Co-Authored-By`, no `Generated with`. Verify with `git log -1 --format=%B` after every commit, not by trusting your own intent.
- **Comments are one line where possible**, wrapped at or under 100 columns. The branch was swept for this in commits `36276af`, `b4cca3e`, `b7619a7`. Do not regress it.
- **Keep `AuthResult` and `LiveTokenRefresher.RefreshResponse` exactly as they are.** Do not merge them, do not adopt the template's `SupabaseAuthResponse`. Substituting one for the other was the Critical defect of Slice 2: `/auth/refresh` returns no `role`, `AuthResult.role` is non-optional, so decoding a refresh as `AuthResult` throws `keyNotFound`, which the coordinator reads as a failed refresh and signs the user out. Every refresh would have ended the session.
- **Two API clients exist and must stay separate.** `AppDependencies.live()` builds a bare `URLSessionAPIClient` used only by the token refresher, and an intercepted one used by everything else. Sharing them makes a failing refresh recurse into the `AuthInterceptor` that triggered it. See the deviation note below.
- Swift 6 strict concurrency. No data races, no crash paths.

## Deviation from the spec, recorded deliberately

The spec's Slice 3 section says `AuthRepository` covers "register, login, refresh and the current account". **This plan does not put `refresh` on `AuthRepository`.**

Reason: `LiveAuthRepository` is built on the intercepted client, because `me()` needs the `Authorization` header. `refresh` must run on the bare client. If one type carried both, it would have a method that is only safe to call on one of two instances of itself, and calling it on the wrong one recurses. The existing `TokenRefreshing` protocol with its own one-method `LiveTokenRefresher` is both safer and a stricter reading of the interface segregation principle that the rest of this slice is applying. `TokenRefreshCoordinator` and its tests are untouched by this slice.

The spec sentence describes the template, which has no such client split. Amend the spec's Slice 3 section to record this in Task 4.

---

### Task 1: Move the domain models into `Models/`

The domain types currently live inside the two client files. The template keeps models in `Models/` and implementations in `Data/`, and the next two tasks delete those client files, so the models move first on their own. This task is a pure move: no type, property, or conformance changes.

It also adds the verification script every later task depends on.

**Files:**
- Create: `Gabay/Models/Event.swift`
- Create: `Gabay/Models/Account.swift`
- Create: `scripts/typecheck.sh`
- Modify: `Gabay/Core/Events/EventClient.swift` (remove the three model types from the top)
- Modify: `Gabay/Core/Auth/AuthClient.swift` (remove the three model types from the top)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Coordinate`, `Event`, `Event.Status`, `EventDraft`, `AccountRole`, `Account`, `AuthResult` at their new paths, all with identical declarations. `scripts/typecheck.sh`, which exits 0 on a clean whole-module typecheck and prints any diagnostics.

- [ ] **Step 1: Create the verification script**

Agents cannot run the build, so the only mechanical check available is a whole-module typecheck of every source file under the project's real build flags. Write `scripts/typecheck.sh`:

```bash
#!/bin/bash
# Typechecks every Swift file in the app and test targets as one module, under the
# same flags the Xcode project uses. Agents cannot run xcodebuild, so this is the
# mechanical check that a change still compiles. It is not a substitute for the
# real build or for running the tests.
set -euo pipefail

cd "$(dirname "$0")/.."

SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
PLUGIN="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

find Gabay GabayTests -name '*.swift' -exec cp {} "$WORK"/ \;

# The two targets compile separately in Xcode, so the test files import the app
# module. Typechecking them as one module makes those imports self-references.
perl -pi -e 's/^\@testable import Gabay$//; s/^import Gabay$//' "$WORK"/*.swift

echo "Typechecking $(ls "$WORK"/*.swift | wc -l | tr -d ' ') files..."

swiftc -swift-version 6 -typecheck -module-name Gabay \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -F "$SDK/../../Library/Frameworks" \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -enable-upcoming-feature MemberImportVisibility \
  -load-plugin-library "$PLUGIN" \
  "$WORK"/*.swift

echo "Clean."
```

Then `chmod +x scripts/typecheck.sh`.

- [ ] **Step 2: Run it to record the baseline**

Run: `./scripts/typecheck.sh`
Expected: `Typechecking 85 files...` then `Clean.`, exit 0, no warnings.

If it reports anything else, stop and report BLOCKED. The branch was clean at `b7619a7` and nothing has changed since.

- [ ] **Step 3: Create `Gabay/Models/Event.swift`**

```swift
//
//  Event.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

// Hashable, not merely Equatable: `.navigationDestination(item:)` in the events list requires it
// (same reason the free-trail app's Trail was Hashable).
struct Event: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
    let gpxURL: URL?
    let distanceM: Int?
    let ascentM: Int?
    let estimatedMinutes: Int?
    let status: Status

    enum Status: String, Codable, Sendable {
        case pending
        case published
    }
}

// What the organizer form sends: no id, status, or route stats, the backend assigns the first two
// and a route is added afterward through a separate upload.
struct EventDraft: Encodable, Sendable {
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
}
```

- [ ] **Step 4: Create `Gabay/Models/Account.swift`**

```swift
//
//  Account.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

enum AccountRole: String, Codable, Sendable {
    case hiker
    case organizer
}

struct Account: Codable, Equatable, Sendable {
    let email: String
    let role: AccountRole
}

struct AuthResult: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let role: AccountRole

    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}
```

- [ ] **Step 5: Delete the moved types from the two client files**

In `Gabay/Core/Events/EventClient.swift`, delete everything from `struct Coordinate` through the closing brace of `struct EventDraft`, leaving the header comment, `import Foundation`, `protocol EventFetching`, and `struct EventClient`.

In `Gabay/Core/Auth/AuthClient.swift`, delete everything from `enum AccountRole` through the closing brace of `struct AuthResult`, leaving the header comment, `import Foundation`, `protocol Authenticating`, and `struct AuthClient`.

Do not change anything else in either file. This task must produce a diff where every deleted line reappears verbatim in a new file.

- [ ] **Step 6: Verify**

Run: `./scripts/typecheck.sh`
Expected: `Typechecking 87 files...` then `Clean.`, exit 0.

Then confirm the move was lossless:

Run: `git diff --stat`
Expected: two files with deletions only, two files created, and the sum of insertions in the new files equal to the deletions plus the two new file headers.

- [ ] **Step 7: Commit**

```bash
git add Gabay/Models scripts/typecheck.sh Gabay/Core/Events/EventClient.swift Gabay/Core/Auth/AuthClient.swift
git commit -m "Move the domain models into Models/"
git log -1 --format=%B
```

The `git log` output must contain no attribution trailer. If it does, amend before continuing.

---

### Task 2: `AuthRepository`

Renames `Authenticating`/`AuthClient` to `AuthRepository`/`LiveAuthRepository` and moves it to `Data/`. The protocol's methods and the implementation's bodies do not change. `TokenRefreshing` and `LiveTokenRefresher` are not touched, for the reason given in the deviation note above.

**Files:**
- Create: `Gabay/Data/AuthRepository.swift`
- Delete: `Gabay/Core/Auth/AuthClient.swift`
- Modify: `Gabay/Core/Auth/Session.swift:18,21` (property and init parameter types)
- Modify: `Gabay/App/AppDependencies.swift:70` (construction)
- Rename: `GabayTests/AuthClientTests.swift` to `GabayTests/AuthRepositoryTests.swift`
- Modify: `GabayTests/Support/TestDoubles.swift` (`StubAuthenticating` to `StubAuthRepository`)
- Modify: `GabayTests/SessionTests.swift`, `GabayTests/SignInViewModelTests.swift`, `GabayTests/SignUpViewModelTests.swift`, `GabayTests/AuthInterceptorTests.swift`, `GabayTests/TokenRefreshCoordinatorTests.swift` (stub name only)

**Interfaces:**
- Consumes: `Account`, `AuthResult` from `Gabay/Models/Account.swift` (Task 1).
- Produces: `protocol AuthRepository: Sendable` with `register(email:password:) -> AuthResult`, `login(email:password:) -> AuthResult`, `me() -> Account`; `struct LiveAuthRepository: AuthRepository` with `init(api: any APIClient)`; `final class StubAuthRepository: AuthRepository, @unchecked Sendable` in the test target.

- [ ] **Step 1: Create `Gabay/Data/AuthRepository.swift`**

```swift
//
//  AuthRepository.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

protocol AuthRepository: Sendable {

    func register(email: String, password: String) async throws -> AuthResult

    func login(email: String, password: String) async throws -> AuthResult

    func me() async throws -> Account
}

struct LiveAuthRepository: AuthRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func register(email: String, password: String) async throws -> AuthResult {
        try await api.post(
            APIRoute.Auth.register,
            body: Credentials(email: email, password: password),
            requiresAuth: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try await api.post(
            APIRoute.Auth.login,
            body: Credentials(email: email, password: password),
            requiresAuth: false
        )
    }

    func me() async throws -> Account {
        try await api.get(APIRoute.Auth.currentUser)
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }
}
```

- [ ] **Step 2: Delete the old file**

```bash
git rm Gabay/Core/Auth/AuthClient.swift
```

- [ ] **Step 3: Update `Session`**

In `Gabay/Core/Auth/Session.swift`, change the stored property and the init parameter:

```swift
    @ObservationIgnored private let auth: any AuthRepository
    @ObservationIgnored private let tokenStore: any TokenStore

    init(auth: any AuthRepository, tokenStore: any TokenStore) {
```

Nothing else in `Session` changes. In particular leave `restore()`'s `invalidatesSession` check exactly as it is: it is the fix for the Slice 2 regression that wiped tokens when the app launched offline.

- [ ] **Step 4: Update `AppDependencies`**

In `Gabay/App/AppDependencies.swift`, change the one construction:

```swift
        let session = Session(auth: LiveAuthRepository(api: api), tokenStore: tokenStore)
```

- [ ] **Step 5: Migrate the test double**

In `GabayTests/Support/TestDoubles.swift`, rename the type and its conformance. The body is unchanged:

```swift
final class StubAuthRepository: AuthRepository, @unchecked Sendable {
```

- [ ] **Step 6: Migrate the test files**

Rename the suite file and update every reference:

```bash
git mv GabayTests/AuthClientTests.swift GabayTests/AuthRepositoryTests.swift
```

Then, across the test target:

```bash
grep -rl 'StubAuthenticating' GabayTests | xargs perl -pi -e 's/\bStubAuthenticating\b/StubAuthRepository/g'
perl -pi -e 's/\bAuthClient\b/LiveAuthRepository/g; s/\bmakeClient\b/makeRepository/g' GabayTests/AuthRepositoryTests.swift
```

Then open `GabayTests/AuthRepositoryTests.swift` by hand and fix what the regex cannot: the suite's declared name if it is spelled out as a string, and any comment that still says "client". The suite is `@Suite(.serialized)` nested under the shared parent from Slice 2's R3 fix, so check the parent's name still describes it.

Do not add, remove, or change any `@Test`. The seven test cases in this file stay exactly as they are.

- [ ] **Step 7: Verify**

Run: `./scripts/typecheck.sh`
Expected: `Typechecking 87 files...` then `Clean.`, exit 0.

Run: `grep -rn 'Authenticating\|AuthClient' Gabay GabayTests`
Expected: no output. Any hit is a missed rename.

Run: `grep -rc '@Test' GabayTests/*.swift | awk -F: '{s+=$2} END {print s}'`
Expected: `249`. This task changes no test count.

- [ ] **Step 8: Commit**

```bash
git add -A Gabay/Data Gabay/Core/Auth Gabay/App GabayTests
git commit -m "Rename the auth client to AuthRepository and move it to Data/"
git log -1 --format=%B
```

Confirm no attribution trailer.

---

### Task 3: Split the event protocol into browsing and publishing repositories

The real change of the slice. `EventFetching` has six methods; `EventsViewModel` uses three of them and `PostEventViewModel` uses two. The dead `event(id:)` has no production caller at all, and its only current cost is a force-unwrap in the test double that exists purely to satisfy the protocol.

This task creates the two protocols, deletes the old client, rewires both view models and `AppDependencies`, and migrates the doubles and tests. It is one commit because deleting `EventClient` breaks the view models in the same breath.

**Files:**
- Create: `Gabay/Data/EventRepository.swift`
- Delete: `Gabay/Core/Events/EventClient.swift`
- Modify: `Gabay/Core/Events/EventsViewModel.swift:23,26` (property and init)
- Modify: `Gabay/Core/Events/PostEventViewModel.swift:91,94` (property and init)
- Modify: `Gabay/App/AppDependencies.swift` (stored properties, init, `live()`, `makePostEventViewModel()`)
- Rename: `GabayTests/EventClientTests.swift` to `GabayTests/EventRepositoryTests.swift`, deleting one test case
- Modify: `GabayTests/Support/TestDoubles.swift` (`StubEventFetching` to `StubEventRepository`, drop `event(id:)`)
- Modify: `GabayTests/EventsViewModelTests.swift`, `GabayTests/PostEventViewModelTests.swift` (stub name only)

**Interfaces:**
- Consumes: `Event`, `EventDraft` from `Gabay/Models/Event.swift` (Task 1). `MultipartFormData`, `APIRoute.Events`, `any APIClient` from Slice 2.
- Produces: `protocol EventBrowsingRepository: Sendable` with `events() -> [Event]`, `mine() -> [Event]`, `join(_ id: String)`; `protocol EventPublishingRepository: Sendable` with `create(_ draft: EventDraft) -> Event` and `uploadGPX(eventID:fileURL:distanceM:ascentM:estimatedMinutes:) -> Event`; `struct LiveEventRepository` conforming to both, `init(api: any APIClient)`; `final class StubEventRepository` conforming to both in the test target.

- [ ] **Step 1: Create `Gabay/Data/EventRepository.swift`**

```swift
//
//  EventRepository.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

// Split in two so neither consumer sees methods it cannot use: the browsing screens cannot
// publish an event, and the organizer form cannot list or join one.
protocol EventBrowsingRepository: Sendable {

    func events() async throws -> [Event]

    func mine() async throws -> [Event]

    func join(_ id: String) async throws
}

protocol EventPublishingRepository: Sendable {

    func create(_ draft: EventDraft) async throws -> Event

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event
}

// One backend, so one implementation conforms to both; the split is for the consumers.
struct LiveEventRepository: EventBrowsingRepository, EventPublishingRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func events() async throws -> [Event] {
        try await api.get(APIRoute.Events.list)
    }

    func mine() async throws -> [Event] {
        try await api.get(APIRoute.Events.mine)
    }

    func join(_ id: String) async throws {
        try await api.send(Endpoint(APIRoute.Events.join(id), method: .post))
    }

    func create(_ draft: EventDraft) async throws -> Event {
        try await api.post(APIRoute.Events.list, body: draft)
    }

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        var form = MultipartFormData()
        form.addField("distanceM", value: String(distanceM))
        if let ascentM { form.addField("ascentM", value: String(ascentM)) }
        form.addField("estimatedMinutes", value: String(estimatedMinutes))

        // The filename rides in the multipart Content-Disposition header unescaped, so it must be
        // one we control, not the user's raw file name.
        form.addFile(
            "gpx",
            filename: "\(eventID).gpx",
            mimeType: "application/gpx+xml",
            data: try Data(contentsOf: fileURL)
        )

        return try await api.upload(APIRoute.Events.gpx(eventID), form: form)
    }
}
```

Note what is absent: `event(id: String)`. It is deleted, not moved.

- [ ] **Step 2: Delete the old file**

```bash
git rm Gabay/Core/Events/EventClient.swift
```

- [ ] **Step 3: Rewire `EventsViewModel`**

In `Gabay/Core/Events/EventsViewModel.swift`, narrow the dependency and make it private. It is currently `let`, not `private let`, but nothing outside the class reads it:

```swift
    @ObservationIgnored private let events: any EventBrowsingRepository
    @ObservationIgnored private var hasLoaded = false

    init(events: any EventBrowsingRepository) {
        self.events = events
    }
```

Nothing else changes. `fetchEvents()`, `loadMine()`, and `join(_:)` call only `events()`, `mine()`, and `join(_:)`, all of which are on `EventBrowsingRepository`.

- [ ] **Step 4: Rewire `PostEventViewModel`**

In `Gabay/Core/Events/PostEventViewModel.swift`:

```swift
    @ObservationIgnored private let events: any EventPublishingRepository
    @ObservationIgnored private let parser: GPXParser

    init(events: any EventPublishingRepository, parser: GPXParser = GPXParser()) {
        self.events = events
        self.parser = parser
    }
```

Nothing else changes. `submit()` calls only `create(_:)` and `uploadGPX(...)`.

- [ ] **Step 5: Rewire `AppDependencies`**

`AppDependencies` hands one dependency to two different view models that now want different protocols, so it holds two properties. `live()` passes the same `LiveEventRepository` instance to both, which is what it was doing before under one name.

Change the stored property and init:

```swift
    private let browsing: any EventBrowsingRepository
    private let publishing: any EventPublishingRepository

    init(
        session: Session,
        browsing: any EventBrowsingRepository,
        publishing: any EventPublishingRepository,
        eventsViewModel: EventsViewModel,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.session = session
        self.browsing = browsing
        self.publishing = publishing
        self.eventsViewModel = eventsViewModel
        self.analytics = analytics
        self.crashes = crashes
    }
```

In `live()`, replace the `EventClient` line and the `return`:

```swift
        let events = LiveEventRepository(api: api)

        return AppDependencies(
            session: session,
            browsing: events,
            publishing: events,
            eventsViewModel: EventsViewModel(events: events),
            analytics: analytics,
            crashes: crashes
        )
```

And the factory:

```swift
    func makePostEventViewModel() -> PostEventViewModel {
        PostEventViewModel(events: publishing)
    }
```

`browsing` is stored but read only by `live()`'s construction of `eventsViewModel` today. Keep it: it is the seam a future screen takes, and dropping it would leave the init asymmetric. If the reviewer flags it as unused, that is a fair Minor to record, not a reason to delete the parameter.

- [ ] **Step 6: Migrate the test double**

In `GabayTests/Support/TestDoubles.swift`, rename the type, conform to both protocols, and delete the `event(id:)` method with its force-unwrap. Everything else is unchanged:

```swift
final class StubEventRepository: EventBrowsingRepository, EventPublishingRepository, @unchecked Sendable {
    var eventsResult: Result<[Event], any Error> = .success([])
    var mineResult: Result<[Event], any Error> = .success([])
    var createResult: Result<Event, any Error> = .failure(APIError.forbidden())
    var uploadGPXResult: Result<Event, any Error> = .failure(APIError.forbidden())
    var joinResult: Result<Void, any Error> = .success(())
    private(set) var joinedIds: [String] = []
    private(set) var uploadedGPXEventIds: [String] = []
    private(set) var eventsCallCount = 0

    func events() async throws -> [Event] {
        eventsCallCount += 1
        return try eventsResult.get()
    }

    func create(_ draft: EventDraft) async throws -> Event { try createResult.get() }

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        uploadedGPXEventIds.append(eventID)
        return try uploadGPXResult.get()
    }

    func join(_ id: String) async throws {
        joinedIds.append(id)
        try joinResult.get()
    }

    func mine() async throws -> [Event] { try mineResult.get() }
}
```

One stub conforming to both, not two stubs: both view model suites construct it identically, and splitting it would duplicate every result field without any suite gaining isolation. The segregation that matters is in the production code, where each view model can now only reach what it uses.

Also update the file's header comment if it says "the protocols view models depend on" in a way that no longer reads correctly.

- [ ] **Step 7: Migrate the test files**

```bash
git mv GabayTests/EventClientTests.swift GabayTests/EventRepositoryTests.swift
grep -rl 'StubEventFetching' GabayTests | xargs perl -pi -e 's/\bStubEventFetching\b/StubEventRepository/g'
perl -pi -e 's/\bEventClient\b/LiveEventRepository/g; s/\bmakeClient\b/makeRepository/g' GabayTests/EventRepositoryTests.swift
```

Then delete the `readsOneEvent` test case at `GabayTests/EventRepositoryTests.swift:82` by hand, including its `@Test` attribute and any stub response it queues. It covers `event(id:)`, which no longer exists. This is the one and only test case this slice deletes.

Open the file and fix what the regex cannot: comments that still say "client", and the suite name.

- [ ] **Step 8: Verify**

Run: `./scripts/typecheck.sh`
Expected: `Typechecking 87 files...` then `Clean.`, exit 0.

Run: `grep -rn 'EventFetching\|EventClient\|event(id:' Gabay GabayTests`
Expected: no output.

Run: `grep -rc '@Test' GabayTests/*.swift | awk -F: '{s+=$2} END {print s}'`
Expected: `248`. Exactly one fewer than the 249 at the start of the slice.

Run: `grep -rn 'try .*\.get()\.first' GabayTests`
Expected: no output. The force-unwrap the spec called out is gone.

- [ ] **Step 9: Commit**

```bash
git add -A Gabay GabayTests
git commit -m "Split the event client into browsing and publishing repositories"
git log -1 --format=%B
```

Confirm no attribution trailer. Confirm `Gabay/Resources/Localizable.xcstrings` is not in the commit:

```bash
git show --stat HEAD | grep -c xcstrings
```

Expected: `0`.

---

### Task 4: Amend the spec, sweep, and record the slice

Closes the slice: records the `refresh` deviation in the spec so the next reader does not treat it as an oversight, checks the whole branch for leftovers from the renames, and writes the ledger entry.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-23-template-architecture-adoption-design.md` (Slice 3 section)
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: the completed Tasks 1 to 3.
- Produces: nothing code-facing.

- [ ] **Step 1: Amend the spec's Slice 3 section**

In the Slice 3 section, replace the `Data/AuthRepository.swift` bullet with wording that records the decision rather than the template's shape. Keep the surrounding bullets as they are:

```markdown
- `Data/AuthRepository.swift`: `protocol AuthRepository` plus `LiveAuthRepository`,
  covering register, login and the current account. Refresh is deliberately NOT on
  this protocol, unlike the template's: `LiveAuthRepository` is built on the
  intercepted client because `me()` needs an Authorization header, while refresh must
  run on the bare client or a failing refresh recurses into the `AuthInterceptor` that
  triggered it. `TokenRefreshing` and `LiveTokenRefresher` stay as they are.
```

- [ ] **Step 2: Sweep the branch for leftovers**

Run each and expect no output:

```bash
grep -rn 'Authenticating\|AuthClient\|EventFetching\|EventClient' Gabay GabayTests docs/superpowers/specs
grep -rnP '\x{2014}' Gabay GabayTests scripts docs/superpowers/plans/2026-09-24-template-slice-3-repositories.md
awk 'length > 100 {print FILENAME":"FNR}' $(find Gabay GabayTests -name '*.swift')
```

The first catches missed renames including in prose, the second catches em dashes, the third catches comment lines that regressed past 100 columns.

Then confirm no commit on the branch carries an attribution trailer:

```bash
git log --format=%B origin/main..HEAD | grep -ci 'co-authored-by\|generated with'
```

Expected: `0`.

- [ ] **Step 3: Final typecheck**

Run: `./scripts/typecheck.sh`
Expected: `Typechecking 87 files...` then `Clean.`, exit 0, no warnings.

- [ ] **Step 4: Append the ledger entry**

Append to `.superpowers/sdd/progress.md`, filling in the real commit hashes:

```
SLICE 3 (repository layer) COMPLETE at <head7>. 3 commits <base7>..<head7>.
  Models moved to Models/, implementations to Data/.
  EventFetching split into EventBrowsingRepository (events, mine, join) and
  EventPublishingRepository (create, uploadGPX); LiveEventRepository conforms to
  both, AppDependencies hands the one instance to each view model as the
  protocol it needs.
  Dead event(id:) dropped, and with it the force-unwrap in the test double.
  DELIBERATE SPEC DEVIATION: refresh is NOT on AuthRepository. LiveAuthRepository
  runs on the intercepted client (me() needs auth); refresh must run on the bare
  one or it recurses into AuthInterceptor. TokenRefreshing/LiveTokenRefresher
  untouched. Spec amended to record this.
  No new test cases, per the user's 2026-09-24 instruction. One test deleted
  (readsOneEvent) because the method it covered is gone: 249 -> 248.
  Whole-module typecheck via scripts/typecheck.sh: 87 files, zero errors, zero
  warnings. THE BUILD AND THE TEST SUITE HAVE STILL NEVER BEEN RUN.
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-09-23-template-architecture-adoption-design.md
git commit -m "Record the Slice 3 refresh deviation in the spec"
git log -1 --format=%B
```

Note: `.superpowers/sdd/progress.md` is git-ignored by `.superpowers/sdd/.gitignore`, which is why it is absent from the `git add` above. Write it anyway. It stays untracked, which is its normal state.

---

## Open items this slice does not close

Recorded so the final review can triage them, not fixed here:

- `AuthResult.role` is decoded but never read. `RootView` reads `session.account?.role`, which comes from `me()`. Making it optional or dropping it would change what the register and login responses are required to contain, which is a backend contract question, not a refactor. Leave it.
- `AppDependencies.browsing` is stored but only read during construction. It is the seam a second browsing consumer would take.
- The four `PostEventViewModel` fields without inline error slots (`title`, `cause`, `meetingPoint`, `description`), carried from Slice 1. `submitErrorMessage` already falls through for them, so nothing is silently swallowed.
- Slice 4 owns the rest of the audit: `EventDetailView`'s `URLSession.shared` route fetch, the missing `startAccessingSecurityScopedResource()`, the `OneShotLocator` continuation, and the duplicated `routeSummary` between `EventDetailView` and `PostEventView`.
