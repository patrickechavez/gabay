# Events Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gabay's free GPX-trail feature with a cause-hike events platform: sign in, browse and join events (soft RSVP, external payment link), let organizer-flagged accounts post a new event (with a pin-dropped meeting point and an optional GPX route), built against a REST contract for a C# backend that does not exist yet.

**Architecture:** Mirror the existing protocol-behind-view-model pattern (client -> store/view model -> view, views hold no logic) for two new domains, Auth and Events, sharing one small networking core. The free-trail code's catalog/list-browsing half (Core/Trails, Features/Trail) is deleted; its GPX-parsing and map-drawing half is kept and repurposed for the new optional route feature, moved to Core/Route and Features/Route.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, Swift Testing (`import Testing`, `@Test`), `URLSession` with a stub `URLProtocol` for network tests, Keychain (`Security` framework) for token storage, MapKit + a one-shot `CLLocationManager` read for the meeting-point picker. No third-party dependencies other than the Firebase SDK.

## Global Constraints

- iOS 17+, Swift 6, Xcode 26 (matches the existing scheme/target settings; do not change deployment target or Swift version).
- No third-party dependencies other than the Firebase SDK. Everything here uses only Foundation, SwiftUI, MapKit, CoreLocation, and Security.
- No em dashes anywhere: not in code comments, not in this plan, not in commit messages. Use a comma, period, or a hyphen surrounded by spaces (` - `) instead.
- Views hold no logic. State and side effects live in an `@Observable` `@MainActor` view model; the view model depends on protocols (`Authenticating`, `TokenStoring`, `EventFetching`), never concrete network types, so tests can substitute stubs.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for both the `Gabay` and `GabayTests` targets: any file created, moved, or deleted under `Gabay/` or `GabayTests/` on disk is automatically added to or removed from the build. **Never edit `Gabay.xcodeproj/project.pbxproj` to add or remove a source file** - only `git mv`/`git rm`/`Write` the file itself. The one exception in this plan is removing three build-setting lines (`INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription`) in Task 12, which are build settings, not file references.
- Location use is a one-shot "where am I right now" read for centering the meeting-point picker, never background tracking. Only `NSLocationWhenInUseUsageDescription` belongs in Info.plist; the free-trail app's `NSLocationAlwaysAndWhenInUseUsageDescription` does not come back.
- Test command for any single suite:
  `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/<SuiteName>`
- Test command for the whole suite: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Per the user's standing instruction for this plan, implementer and fix subagents write and self-review code but do not run `xcodebuild` or `xcrun simctl` themselves.** The user runs all builds and tests personally. Every task's steps that say "Run to verify" are instructions for the user, not something the implementer executes; the implementer's report lists the exact commands and expected output instead of RED/GREEN evidence from its own run.
- All work happens on the `events-platform` branch in `/Users/patrick/Projects/Gabay` (do not switch branches). Task 1 is already implemented and review-approved (commits `ada2afc..d705711`). Tasks 2-4 are unimplemented but unaffected by the route/pin-drop amendment below; do not change their scope.

---

### Task 1: Shared networking core

**Status: DONE.** Implemented and review-approved as commits `ada2afc..d705711` on `events-platform`. `Gabay/Core/Networking/APIClient.swift`, `Gabay/Core/Networking/APICoders.swift` (the free-trail `Gabay/Core/Trails/JSONCoders.swift` was left in place, not renamed), `GabayTests/Support/StubURLProtocol.swift`, `GabayTests/APIClientTests.swift`, `GabayTests/APICodersTests.swift` all exist. Do not re-dispatch this task. Task 5 below adds one more method to `APIClient.swift` (multipart upload), it does not redo this task.

---

### Task 2: Auth networking (TokenStore, AuthClient)

**Files:**
- Create: `Gabay/Core/Auth/TokenStore.swift`
- Create: `Gabay/Core/Auth/AuthClient.swift`
- Create: `GabayTests/Support/TestDoubles.swift`
- Test: `GabayTests/TokenStoreTests.swift`
- Test: `GabayTests/AuthClientTests.swift`

**Interfaces:**
- Consumes: `APIClient` from Task 1 (`get`/`post` methods, `APIError`).
- Produces: `protocol TokenStoring: Sendable { func save(_ token: String) throws; func load() -> String?; func clear() }`, `struct TokenStore: TokenStoring`.
- Produces: `enum AccountRole: String, Codable, Sendable { case hiker, organizer }`, `struct Account: Codable, Equatable, Sendable { let email: String; let role: AccountRole }`, `struct AuthResult: Codable, Equatable, Sendable { let token: String; let role: AccountRole }`.
- Produces: `protocol Authenticating: Sendable { func register(email:password:) async throws -> AuthResult; func login(email:password:) async throws -> AuthResult; func me() async throws -> Account }`, `struct AuthClient: Authenticating`.
- Produces (test support): `final class StubAuthenticating: Authenticating`, `final class StubTokenStore: TokenStoring`, reused by every later Session/Auth-dependent test.

- [ ] **Step 1: Write the failing TokenStore tests**

`GabayTests/TokenStoreTests.swift`:

```swift
//
//  TokenStoreTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct TokenStoreTests {

    // A service per test, so one test's token never reaches another.
    private func makeStore() -> TokenStore {
        TokenStore(service: "com.patrick.Gabay.tests.\(UUID().uuidString)")
    }

    @Test func startsWithNothing() {
        let store = makeStore()
        #expect(store.load() == nil)
    }

    @Test func givesBackWhatItWasGiven() throws {
        let store = makeStore()
        try store.save("abc123")
        #expect(store.load() == "abc123")
    }

    @Test func replacesWhatWasThereBefore() throws {
        let store = makeStore()
        try store.save("first")
        try store.save("second")
        #expect(store.load() == "second")
    }

    @Test func forgetsAfterClear() throws {
        let store = makeStore()
        try store.save("abc123")
        store.clear()
        #expect(store.load() == nil)
    }
}
```

- [ ] **Step 2: List the command for the user to verify it fails**

Since the implementer does not run tests, note in the report: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/TokenStoreTests` should currently fail to build (`TokenStore` does not exist yet).

- [ ] **Step 3: Implement TokenStore**

`Gabay/Core/Auth/TokenStore.swift`:

```swift
//
//  TokenStore.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation
import Security

// Where the signed-in hiker's session token lives. The Keychain survives
// reinstalls and app updates, unlike UserDefaults, which is where a token
// belongs.
protocol TokenStoring: Sendable {

    func save(_ token: String) throws

    func load() -> String?

    func clear()
}

struct TokenStore: TokenStoring {

    private let service: String
    private let account = "session-token"

    // The service is a parameter so a test can use its own, and never
    // collide with the token a real sign-in left behind.
    init(service: String = "com.patrick.Gabay.session") {
        self.service = service
    }

    func save(_ token: String) throws {
        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw TokenStoreError.saveFailed(status) }
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum TokenStoreError: Error, Equatable {
    case saveFailed(OSStatus)
}
```

- [ ] **Step 4: Write the failing AuthClient tests**

`GabayTests/AuthClientTests.swift`:

```swift
//
//  AuthClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct AuthClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient() -> AuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return AuthClient(api: APIClient(base: base, configuration: configuration))
    }

    @Test func registersAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"token\":\"abc123\",\"role\":\"hiker\"}".utf8)
        ))

        let result = try await client.register(email: "hiker@example.test", password: "secret123")

        #expect(result == AuthResult(token: "abc123", role: .hiker))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/auth/register")
    }

    @Test func logsInAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"token\":\"abc123\",\"role\":\"organizer\"}".utf8)
        ))

        let result = try await client.login(email: "organizer@example.test", password: "secret123")

        #expect(result == AuthResult(token: "abc123", role: .organizer))
    }

    @Test func readsTheSignedInAccount() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"email\":\"hiker@example.test\",\"role\":\"hiker\"}".utf8)
        ))

        let account = try await client.me()

        #expect(account == Account(email: "hiker@example.test", role: .hiker))
    }

    @Test func refusesBadCredentials() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        await #expect(throws: APIError.unauthorized) {
            try await client.login(email: "hiker@example.test", password: "wrong")
        }
    }
}
```

- [ ] **Step 5: Implement AuthClient**

`Gabay/Core/Auth/AuthClient.swift`:

```swift
//
//  AuthClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
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
    let token: String
    let role: AccountRole
}

// Registers, signs in, and reads the signed-in account.
protocol Authenticating: Sendable {

    func register(email: String, password: String) async throws -> AuthResult

    func login(email: String, password: String) async throws -> AuthResult

    func me() async throws -> Account
}

struct AuthClient: Authenticating {

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func register(email: String, password: String) async throws -> AuthResult {
        try await api.post("auth/register", body: Credentials(email: email, password: password))
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try await api.post("auth/login", body: Credentials(email: email, password: password))
    }

    func me() async throws -> Account {
        try await api.get("me")
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }
}
```

- [ ] **Step 6: List the command for the user to verify AuthClient tests pass**

Note in the report: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/AuthClientTests` should show 4/4 passing.

- [ ] **Step 7: Create the shared test doubles file, for Session tests (Task 3) and later tasks to build on**

`GabayTests/Support/TestDoubles.swift`:

```swift
//
//  TestDoubles.swift
//  GabayTests
//

import Foundation
@testable import Gabay

// Shared stand-ins for the protocols view models depend on, so tests don't
// need a network or a Keychain to drive them.

final class StubAuthenticating: Authenticating, @unchecked Sendable {
    var registerResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized)
    var loginResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized)
    var meResult: Result<Account, any Error> = .failure(APIError.unauthorized)

    func register(email: String, password: String) async throws -> AuthResult {
        try registerResult.get()
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try loginResult.get()
    }

    func me() async throws -> Account {
        try meResult.get()
    }
}

final class StubTokenStore: TokenStoring, @unchecked Sendable {
    private(set) var saved: String?

    func save(_ token: String) throws { saved = token }
    func load() -> String? { saved }
    func clear() { saved = nil }
}
```

- [ ] **Step 8: List the command for the user to run the whole suite once more before committing**

Note in the report: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (full suite, not just this task's tests).

- [ ] **Step 9: Commit**

```bash
git add Gabay/Core/Auth/TokenStore.swift Gabay/Core/Auth/AuthClient.swift GabayTests/Support/TestDoubles.swift GabayTests/TokenStoreTests.swift GabayTests/AuthClientTests.swift
git commit -m "Add TokenStore and AuthClient for the events backend"
```

---

### Task 3: Session

**Files:**
- Create: `Gabay/Core/Auth/Session.swift`
- Test: `GabayTests/SessionTests.swift`

**Interfaces:**
- Consumes: `Authenticating`, `TokenStoring` (Task 2), `StubAuthenticating`, `StubTokenStore` (Task 2 test doubles).
- Produces: `@Observable @MainActor final class Session` with `private(set) var account: Account?`, `var isSignedIn: Bool`, `func restore() async`, `func register(email:password:) async throws`, `func login(email:password:) async throws`, `func signOut()`. Every later view model that needs to know who is signed in, or force a sign-out on a `401`, takes a `Session`.

- [ ] **Step 1: Write the failing Session tests**

`GabayTests/SessionTests.swift`:

```swift
//
//  SessionTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct SessionTests {

    private let hiker = Account(email: "hiker@example.test", role: .hiker)

    @Test func startsSignedOut() {
        let session = Session(auth: StubAuthenticating(), tokenStore: StubTokenStore())
        #expect(session.isSignedIn == false)
    }

    @Test func restoreDoesNothingWithoutAStoredToken() async {
        let session = Session(auth: StubAuthenticating(), tokenStore: StubTokenStore())
        await session.restore()
        #expect(session.isSignedIn == false)
    }

    @Test func restoreSignsInWhenATokenIsAlreadyStored() async throws {
        let auth = StubAuthenticating()
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()
        try tokenStore.save("abc123")

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.account == hiker)
    }

    @Test func restoreClearsAStaleToken() async {
        let auth = StubAuthenticating()
        auth.meResult = .failure(APIError.unauthorized)
        let tokenStore = StubTokenStore()
        try? tokenStore.save("stale")

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.isSignedIn == false)
        #expect(tokenStore.load() == nil)
    }

    @Test func loginSavesTheTokenAndLoadsTheAccount() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        #expect(session.account == hiker)
        #expect(tokenStore.load() == "abc123")
    }

    @Test func signOutClearsEverything() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        session.signOut()

        #expect(session.isSignedIn == false)
        #expect(tokenStore.load() == nil)
    }
}
```

- [ ] **Step 2: List the command for the user to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/SessionTests` should currently fail to build (`Session` does not exist yet).

- [ ] **Step 3: Implement Session**

`Gabay/Core/Auth/Session.swift`:

```swift
//
//  Session.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// The signed-in hiker, or the lack of one. Every screen that needs to know
// who's signed in, or what they're allowed to do, reads this.
@Observable
@MainActor
final class Session {

    private(set) var account: Account?

    var isSignedIn: Bool { account != nil }

    @ObservationIgnored private let auth: any Authenticating
    @ObservationIgnored private let tokenStore: any TokenStoring

    init(auth: any Authenticating, tokenStore: any TokenStoring) {
        self.auth = auth
        self.tokenStore = tokenStore
    }

    // Called once at launch. Picks up a token already in the Keychain, or
    // does nothing if there isn't one.
    func restore() async {
        guard tokenStore.load() != nil else { return }

        do {
            account = try await auth.me()
        } catch {
            // A stale or revoked token: back to signed out.
            tokenStore.clear()
        }
    }

    func register(email: String, password: String) async throws {
        let result = try await auth.register(email: email, password: password)
        try tokenStore.save(result.token)
        account = try await auth.me()
    }

    func login(email: String, password: String) async throws {
        let result = try await auth.login(email: email, password: password)
        try tokenStore.save(result.token)
        account = try await auth.me()
    }

    // Called by any view model after a 401, not just from within Session,
    // so a session always reflects a rejected token no matter where it was
    // rejected.
    func signOut() {
        tokenStore.clear()
        account = nil
    }
}
```

- [ ] **Step 4: List the command for the user to verify it passes**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/SessionTests` should show 6/6 passing.

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Auth/Session.swift GabayTests/SessionTests.swift
git commit -m "Add Session to track the signed-in hiker"
```

---

### Task 4: Sign-in and sign-up screens

**Files:**
- Create: `Gabay/Features/Auth/SignInView.swift`
- Create: `Gabay/Features/Auth/SignUpView.swift`

**Interfaces:**
- Consumes: `Session` (Task 3), `LoadFailure` (existing `Core/UI/LoadFailure.swift`).
- Produces: `@Observable @MainActor final class SignInViewModel` (`email`, `password`, `canSubmit`, `func signIn() async`), `struct SignInView: View`. `@Observable @MainActor final class SignUpViewModel` (`email`, `password`, `canSubmit`, `func register() async -> Bool`), `struct SignUpView: View`. Task 12's `RootView`/`AppDependencies` wire these in.

This task is UI only, with no logic beyond what the view models already cover (view models are the testable unit; views are not unit-tested anywhere in this codebase, matching how `TrailsView` had no view test of its own, only `TrailsViewModelTests`). There is no TDD cycle for a view with no logic of its own, so this task's deliverable is verified by the user building successfully; Task 14 verifies the full flow by running the app.

- [ ] **Step 1: Implement SignInView and its view model**

`Gabay/Features/Auth/SignInView.swift`:

```swift
//
//  SignInView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignInViewModel {

    var email = ""
    var password = ""

    private(set) var isSigningIn = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    init(session: Session) {
        self.session = session
    }

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isSigningIn
    }

    func signIn() async {
        guard canSubmit else { return }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.login(email: email, password: password)
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

struct SignInView: View {

    @State private var viewModel: SignInViewModel
    @State private var isShowingSignUp = false

    let makeSignUpViewModel: () -> SignUpViewModel

    init(viewModel: SignInViewModel, makeSignUpViewModel: @escaping () -> SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeSignUpViewModel = makeSignUpViewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Email",
                        text: $viewModel.email,
                        prompt: Text("Email", comment: "Placeholder for the sign-in email field")
                    )
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                    SecureField(
                        "Password",
                        text: $viewModel.password,
                        prompt: Text("Password", comment: "Placeholder for the sign-in password field")
                    )
                    .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isSigningIn {
                            ProgressView()
                        } else {
                            Text("Sign In", comment: "Button that submits the sign-in form")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle(Text("Gabay", comment: "Title of the sign-in screen"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSignUp = true
                    } label: {
                        Text("Sign Up", comment: "Opens the account creation screen")
                    }
                }
            }
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView(viewModel: makeSignUpViewModel())
            }
            .alert(
                Text("Couldn't sign in", comment: "Title when sign-in fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the sign-in failure alert")
                }
            } message: {
                Text("Check your email and password, then try again.",
                     comment: "Shown when sign-in fails")
            }
        }
    }
}
```

- [ ] **Step 2: Implement SignUpView and its view model**

`Gabay/Features/Auth/SignUpView.swift`:

```swift
//
//  SignUpView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignUpViewModel {

    var email = ""
    var password = ""

    private(set) var isRegistering = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    init(session: Session) {
        self.session = session
    }

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    // A backend-defined minimum; the form just avoids an obviously-too-short
    // password making a wasted round trip.
    var canSubmit: Bool {
        !email.isEmpty && password.count >= 8 && !isRegistering
    }

    func register() async -> Bool {
        guard canSubmit else { return false }

        isRegistering = true
        defer { isRegistering = false }

        do {
            try await session.register(email: email, password: password)
            return true
        } catch {
            failure = LoadFailure.classify(error)
            return false
        }
    }
}

struct SignUpView: View {

    @State private var viewModel: SignUpViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Email",
                        text: $viewModel.email,
                        prompt: Text("Email", comment: "Placeholder for the sign-up email field")
                    )
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                    SecureField(
                        "Password",
                        text: $viewModel.password,
                        prompt: Text("Password", comment: "Placeholder for the sign-up password field")
                    )
                    .textContentType(.newPassword)
                } footer: {
                    Text("At least 8 characters.", comment: "Password requirement shown under the field")
                }

                Section {
                    Button {
                        Task {
                            if await viewModel.register() { dismiss() }
                        }
                    } label: {
                        if viewModel.isRegistering {
                            ProgressView()
                        } else {
                            Text("Create Account", comment: "Button that submits the sign-up form")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle(Text("Sign Up", comment: "Title of the account creation screen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the sign-up screen without creating an account")
                    }
                }
            }
            .alert(
                Text("Couldn't create account", comment: "Title when sign-up fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the sign-up failure alert")
                }
            } message: {
                Text("Try again in a moment.", comment: "Shown when sign-up fails")
            }
        }
    }
}
```

- [ ] **Step 3: List the command for the user to verify both screens compile**

`xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` should succeed (these views are not referenced by `RootView` until Task 12, so a successful build is the only signal at this point).

- [ ] **Step 4: Commit**

```bash
git add Gabay/Features/Auth
git commit -m "Add sign-in and sign-up screens"
```

---

### Task 5: Event model, EventClient, and GPX upload

**Files:**
- Create: `Gabay/Core/Events/EventClient.swift`
- Modify: `Gabay/Core/Networking/APIClient.swift` (add a multipart upload method)
- Test: `GabayTests/EventClientTests.swift`
- Test: `GabayTests/APIClientTests.swift` (add one multipart test)

**Interfaces:**
- Consumes: `APIClient`, `APIError` (Task 1).
- Produces: `struct Coordinate: Codable, Hashable, Sendable { let latitude: Double; let longitude: Double }`.
- Produces: `struct Event: Codable, Identifiable, Hashable, Sendable` with `id, title, cause, date, meetingPoint, meetingCoordinate, feePHP, capacity, joinURL, description, photoURL, gpxURL, distanceM, ascentM, estimatedMinutes, status` (`status: Event.Status`, `enum Status: String, Codable, Sendable { case pending, published }`). `Hashable`, not just `Equatable`, because Task 9's `EventsListView` drives navigation with `.navigationDestination(item:)`, whose only overload requires `D: Hashable`. The free-trail app's `Trail` model is declared `Identifiable, Hashable, Sendable` for exactly the same reason. `Coordinate` must be `Hashable` too, or `Event`'s synthesis fails. `struct EventDraft: Encodable, Sendable` with the same fields except `id, status, gpxURL, distanceM, ascentM, estimatedMinutes` (those four are server-assigned by the GPX upload, never sent at creation).
- Produces: `protocol EventFetching: Sendable { func events() async throws -> [Event]; func event(id: String) async throws -> Event; func create(_ draft: EventDraft) async throws -> Event; func uploadGPX(eventID: String, fileURL: URL, distanceM: Int, ascentM: Int?, estimatedMinutes: Int) async throws -> Event; func join(_ id: String) async throws; func mine() async throws -> [Event] }`, `struct EventClient: EventFetching`.
- Produces (APIClient addition): `func postMultipart<Response: Decodable>(_ path: String, fileURL: URL, fieldName: String, filename: String, mimeType: String, fields: [String: String] = [:]) async throws -> Response`.

- [ ] **Step 1: Write the failing APIClient multipart test**

Append to `GabayTests/APIClientTests.swift`, inside the `APIClientTests` struct (add this test alongside the existing ones):

```swift

    @Test func sendsAMultipartUploadAndDecodesTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":3}".utf8)))

        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try Data("<gpx></gpx>".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let payload: Payload = try await client.postMultipart(
            "thing",
            fileURL: fileURL,
            fieldName: "gpx",
            filename: "route.gpx",
            mimeType: "application/gpx+xml",
            fields: ["distanceM": "500"]
        )

        #expect(payload == Payload(value: 3))
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Content-Type")?
            .hasPrefix("multipart/form-data; boundary=") == true)
    }
```

- [ ] **Step 2: List the command for the user to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/APIClientTests` should fail to build (`postMultipart` does not exist yet).

- [ ] **Step 3: Implement postMultipart on APIClient**

Modify `Gabay/Core/Networking/APIClient.swift`. Add this method inside the `APIClient` struct, after the existing `post(_:)` (the one with no body):

```swift

    // For a file plus a handful of plain fields, like an organizer's GPX
    // upload alongside its computed stats. Everything else in this client
    // is JSON, this is the one exception, since a file cannot ride in a
    // JSON body without base64 bloat.
    func postMultipart<Response: Decodable>(
        _ path: String,
        fileURL: URL,
        fieldName: String,
        filename: String,
        mimeType: String,
        fields: [String: String] = [:]
    ) async throws -> Response {
        let boundary = UUID().uuidString
        var request = makeRequest(path: path, method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (name, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await send(request)
    }
```

- [ ] **Step 4: List the command for the user to verify it passes**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/APIClientTests` should show 10/10 passing.

- [ ] **Step 5: Write the failing EventClient tests**

`GabayTests/EventClientTests.swift`:

```swift
//
//  EventClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct EventClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient() -> EventClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return EventClient(api: APIClient(base: base, configuration: configuration))
    }

    private var eventJSON: Data {
        Data("""
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
          "gpxURL": null,
          "distanceM": null,
          "ascentM": null,
          "estimatedMinutes": null,
          "status": "published"
        }
        """.utf8)
    }

    @Test func listsPublishedEvents() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("[\(String(data: eventJSON, encoding: .utf8)!)]".utf8)))

        let events = try await client.events()

        #expect(events.count == 1)
        #expect(events.first?.title == "Hike for Pawssion Project")
        #expect(events.first?.meetingCoordinate == Coordinate(latitude: 10.398, longitude: 123.887))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/events")
    }

    @Test func readsOneEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: eventJSON))

        let event = try await client.event(id: "hike-for-pawssion")

        #expect(event.feePHP == 250)
        #expect(event.gpxURL == nil)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion")
    }

    @Test func createsAnEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: eventJSON))

        let draft = EventDraft(
            title: "Hike for Pawssion Project",
            cause: "Pawssion Project Cebu",
            date: Date(),
            meetingPoint: "Budlaan barangay hall",
            meetingCoordinate: Coordinate(latitude: 10.398, longitude: 123.887),
            feePHP: 250,
            capacity: 25,
            joinURL: URL(string: "https://m.me/pawssionprojectcebu")!,
            description: "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
            photoURL: nil
        )

        let event = try await client.create(draft)

        #expect(event.status == .published)
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    // A hiker-role account hitting the endpoint anyway: the server refuses it.
    @Test func refusesCreatingAnEventWithoutTheOrganizerRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 403, body: Data()))

        let draft = EventDraft(
            title: "x", cause: "x", date: Date(), meetingPoint: "x",
            meetingCoordinate: Coordinate(latitude: 0, longitude: 0),
            feePHP: 0, capacity: 1, joinURL: URL(string: "https://example.test")!,
            description: "x", photoURL: nil
        )

        await #expect(throws: APIError.forbidden) {
            try await client.create(draft)
        }
    }

    @Test func uploadsAGPXAndReturnsTheUpdatedEvent() async throws {
        let client = makeClient()
        let withRoute = Data("""
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
          "gpxURL": "https://example.test/uploads/hike-for-pawssion.gpx",
          "distanceM": 4761,
          "ascentM": 386,
          "estimatedMinutes": 132,
          "status": "published"
        }
        """.utf8)
        StubURLProtocol.queue(.init(status: 200, body: withRoute))

        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try Data("<gpx></gpx>".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let event = try await client.uploadGPX(
            eventID: "hike-for-pawssion",
            fileURL: fileURL,
            distanceM: 4761,
            ascentM: 386,
            estimatedMinutes: 132
        )

        #expect(event.gpxURL?.absoluteString == "https://example.test/uploads/hike-for-pawssion.gpx")
        #expect(event.distanceM == 4761)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion/gpx")
    }

    @Test func joinsAnEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 204, body: Data()))

        try await client.join("hike-for-pawssion")

        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion/join")
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func listsJoinedEvents() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("[\(String(data: eventJSON, encoding: .utf8)!)]".utf8)))

        let mine = try await client.mine()

        #expect(mine.count == 1)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/me/events")
    }
}
```

- [ ] **Step 6: Run to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventClientTests` should fail to build (`Event`, `EventDraft`, `EventClient`, `Coordinate` do not exist yet).

- [ ] **Step 7: Implement Coordinate, Event, EventDraft, and EventClient**

`Gabay/Core/Events/EventClient.swift`:

```swift
//
//  EventClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

// Hashable, not merely Equatable: `.navigationDestination(item:)` in the
// events list requires it, the same reason the free-trail app's Trail was
// declared Hashable.
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

// What the organizer form sends to create an event. No id, status, or route
// stats, the backend assigns the first two, and a route (if any) is added
// afterward through a separate upload.
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

// Lists published events, lets an organizer post one and attach a route,
// and tracks joins.
protocol EventFetching: Sendable {

    func events() async throws -> [Event]

    func event(id: String) async throws -> Event

    func create(_ draft: EventDraft) async throws -> Event

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event

    func join(_ id: String) async throws

    func mine() async throws -> [Event]
}

struct EventClient: EventFetching {

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func events() async throws -> [Event] {
        try await api.get("events")
    }

    func event(id: String) async throws -> Event {
        try await api.get("events/\(id)")
    }

    func create(_ draft: EventDraft) async throws -> Event {
        try await api.post("events", body: draft)
    }

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        var fields = [
            "distanceM": String(distanceM),
            "estimatedMinutes": String(estimatedMinutes)
        ]
        if let ascentM { fields["ascentM"] = String(ascentM) }

        return try await api.postMultipart(
            "events/\(eventID)/gpx",
            fileURL: fileURL,
            fieldName: "gpx",
            filename: fileURL.lastPathComponent,
            mimeType: "application/gpx+xml",
            fields: fields
        )
    }

    func join(_ id: String) async throws {
        try await api.post("events/\(id)/join")
    }

    func mine() async throws -> [Event] {
        try await api.get("me/events")
    }
}
```

- [ ] **Step 8: List the command for the user to verify it passes**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventClientTests` should show 7/7 passing.

- [ ] **Step 9: Commit**

```bash
git add Gabay/Core/Networking/APIClient.swift GabayTests/APIClientTests.swift Gabay/Core/Events/EventClient.swift GabayTests/EventClientTests.swift
git commit -m "Add the Event model, EventClient, and GPX upload"
```

---

### Task 6: EventsViewModel

**Files:**
- Create: `Gabay/Core/Events/EventsViewModel.swift`
- Modify: `GabayTests/Support/TestDoubles.swift`
- Test: `GabayTests/EventsViewModelTests.swift`

**Interfaces:**
- Consumes: `EventFetching`, `Event` (Task 5), `Session` (Task 3), `LoadableViewModel`/`LoadState` (existing `Core/UI/LoadState.swift`).
- Produces: `@Observable @MainActor final class EventsViewModel: LoadableViewModel` with `var state: LoadState<[Event]>`, `private(set) var mine: [Event]`, `private(set) var joined: Set<String>`, `let events: any EventFetching`, `func load() async`, `func refresh() async`, `func join(_ event: Event) async`. Task 9's list/detail/My Events views and Task 12's `AppDependencies` consume this.
- Produces (test support, appended to `TestDoubles.swift`): `final class StubEventFetching: EventFetching` (implements all 6 `EventFetching` methods, including `uploadGPX`, since Task 10's `PostEventViewModelTests` needs it too), `extension Event { static func fixture(...) -> Event }`, reused by Task 10's `PostEventViewModelTests`.

- [ ] **Step 1: Append shared Event/EventFetching test doubles**

Append to `GabayTests/Support/TestDoubles.swift`:

```swift

final class StubEventFetching: EventFetching, @unchecked Sendable {
    var eventsResult: Result<[Event], any Error> = .success([])
    var mineResult: Result<[Event], any Error> = .success([])
    var createResult: Result<Event, any Error> = .failure(APIError.forbidden)
    var uploadGPXResult: Result<Event, any Error> = .failure(APIError.forbidden)
    var joinResult: Result<Void, any Error> = .success(())
    private(set) var joinedIds: [String] = []
    private(set) var uploadedGPXEventIds: [String] = []

    func events() async throws -> [Event] { try eventsResult.get() }
    func event(id: String) async throws -> Event { try eventsResult.get().first { $0.id == id }! }
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

extension Event {

    static func fixture(
        id: String = "hike-for-pawssion",
        title: String = "Hike for Pawssion Project",
        gpxURL: URL? = nil,
        distanceM: Int? = nil,
        ascentM: Int? = nil,
        estimatedMinutes: Int? = nil,
        status: Status = .published
    ) -> Event {
        Event(
            id: id,
            title: title,
            cause: "Pawssion Project Cebu",
            date: Date(timeIntervalSince1970: 1_760_000_000),
            meetingPoint: "Budlaan barangay hall",
            meetingCoordinate: Coordinate(latitude: 10.398, longitude: 123.887),
            feePHP: 250,
            capacity: 25,
            joinURL: URL(string: "https://m.me/pawssionprojectcebu")!,
            description: "A hike up Budlaan to Kang-Irag.",
            photoURL: nil,
            gpxURL: gpxURL,
            distanceM: distanceM,
            ascentM: ascentM,
            estimatedMinutes: estimatedMinutes,
            status: status
        )
    }
}
```

- [ ] **Step 2: Write the failing EventsViewModel tests**

`GabayTests/EventsViewModelTests.swift`:

```swift
//
//  EventsViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct EventsViewModelTests {

    private func makeViewModel(
        events: StubEventFetching = StubEventFetching(),
        auth: StubAuthenticating = StubAuthenticating()
    ) -> (EventsViewModel, Session) {
        let session = Session(auth: auth, tokenStore: StubTokenStore())
        return (EventsViewModel(events: events, session: session), session)
    }

    @Test func startsIdle() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.state == .idle)
    }

    @Test func loadPopulatesTheList() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.value?.first?.title == "Hike for Pawssion Project")
    }

    @Test func loadAlsoPopulatesMine() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        events.mineResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.mine.count == 1)
        #expect(viewModel.joined.contains("hike-for-pawssion"))
    }

    @Test func loadOnlyFetchesOnce() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.state.value?.count == 1)
    }

    @Test func joinMarksTheEventAsJoined() async {
        let events = StubEventFetching()
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.join(.fixture())

        #expect(viewModel.joined.contains("hike-for-pawssion"))
        #expect(events.joinedIds == ["hike-for-pawssion"])
    }

    @Test func aFailedLoadReportsTheFailure() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.server)
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
    }

    @Test func anUnauthorizedLoadSignsOut() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.unauthorized)
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let (viewModel, session) = makeViewModel(events: events, auth: auth)
        try? await session.login(email: "hiker@example.test", password: "secret123")

        await viewModel.load()

        #expect(session.isSignedIn == false)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventsViewModelTests` should fail to build (`EventsViewModel` does not exist yet).

- [ ] **Step 4: Implement EventsViewModel**

`Gabay/Core/Events/EventsViewModel.swift`:

```swift
//
//  EventsViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class EventsViewModel: LoadableViewModel {

    var state: LoadState<[Event]> = .idle

    private(set) var mine: [Event] = []

    // Ids the hiker has joined, kept alongside `mine` so a row's button
    // updates the moment Join is tapped, without waiting on a refresh.
    private(set) var joined: Set<String> = []

    @ObservationIgnored let events: any EventFetching
    @ObservationIgnored private let session: Session
    @ObservationIgnored private var hasLoaded = false

    init(events: any EventFetching, session: Session) {
        self.events = events
        self.session = session
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        await perform { try await self.fetchEvents() }
        await loadMine()
    }

    func refresh() async {
        await perform(isRefresh: true) { try await self.fetchEvents() }
        await loadMine()
    }

    func join(_ event: Event) async {
        do {
            try await events.join(event.id)
            joined.insert(event.id)
        } catch APIError.unauthorized {
            session.signOut()
        } catch {
            // A soft RSVP; a failure here isn't worth blocking the hiker,
            // who is about to leave the app for the payment link anyway.
        }
    }

    private func fetchEvents() async throws -> [Event] {
        do {
            return try await events.events()
        } catch APIError.unauthorized {
            session.signOut()
            throw CancellationError()
        }
    }

    private func loadMine() async {
        do {
            mine = try await events.mine()
            joined = Set(mine.map(\.id))
        } catch APIError.unauthorized {
            session.signOut()
        } catch {
            // Left as-is; `state` already reports the list's own failure.
        }
    }
}
```

- [ ] **Step 5: Run the EventsViewModel tests and verify they pass**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventsViewModelTests` should show 7/7 passing.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Events/EventsViewModel.swift GabayTests/Support/TestDoubles.swift GabayTests/EventsViewModelTests.swift
git commit -m "Add EventsViewModel for listing, refreshing, and joining events"
```

---

### Task 7: Core/Route (kept and repurposed GPX parsing, plus route stats)

**Files:**
- Move (unchanged content): `Gabay/Core/Trails/GPXParser.swift` → `Gabay/Core/Route/GPXParser.swift`
- Move (unchanged content): `Gabay/Core/Trails/TrackPoint.swift` → `Gabay/Core/Route/TrackPoint.swift`
- Move (unchanged content): `GabayTests/GPXParserTests.swift` → `GabayTests/GPXParserTests.swift` (stays in place, no rename needed)
- Keep in place (do not delete): `GabayTests/Fixtures/` (all 5 `.gpx` files, still used by the moved `GPXParserTests.swift`)
- Create: `Gabay/Core/Route/RouteStats.swift`
- Test: `GabayTests/RouteStatsTests.swift`

**Interfaces:**
- Consumes: nothing new, `GPXParser`/`TrackPoint`/`Track` are moved unchanged.
- Produces: `struct GPXDocument`, `enum GPXError`, `struct GPXParser` (all unchanged, just relocated), `struct TrackPoint`, `struct Track`, and the `Array where Element == TrackPoint` extension (`distance`, `ascent(ignoringRisesUnder:)`, `distanceFromStart(to:)`, `duration`), all unchanged, just relocated.
- Produces (new): `struct RouteStats: Equatable, Sendable { let distanceM: Double; let ascentM: Double?; let estimatedMinutes: Int; init(points: [TrackPoint]) }`. Task 10's `PostEventViewModel` and Task 9's `EventDetailView` both use this.

The move itself has no test cycle (the content is unchanged, its existing test simply moves with it). `RouteStats` is new and gets its own TDD cycle.

- [ ] **Step 1: Move GPXParser.swift, TrackPoint.swift, and their fixtures**

```bash
cd /Users/patrick/Projects/Gabay
mkdir -p Gabay/Core/Route
git mv Gabay/Core/Trails/GPXParser.swift Gabay/Core/Route/GPXParser.swift
git mv Gabay/Core/Trails/TrackPoint.swift Gabay/Core/Route/TrackPoint.swift
```

`GabayTests/GPXParserTests.swift` and `GabayTests/Fixtures/` already exist at their current paths and need no move, only to survive Task 12's cutover (noted there).

- [ ] **Step 2: List the command for the user to verify the moved code and its existing tests still build and pass**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/GPXParserTests -only-testing:GabayTests/TrackMathTests` should show all tests passing unchanged (the code did not change, only its location).

- [ ] **Step 3: Write the failing RouteStats tests**

`GabayTests/RouteStatsTests.swift`:

```swift
//
//  RouteStatsTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct RouteStatsTests {

    private func points(_ elevations: [Double?]) -> [TrackPoint] {
        elevations.enumerated().map { index, elevation in
            // Roughly 111 metres of latitude per 0.001 degrees.
            TrackPoint(
                latitude: 9.8127 + Double(index) * 0.001,
                longitude: 123.3878,
                elevation: elevation,
                time: nil
            )
        }
    }

    @Test func computesDistanceAndAscent() {
        let stats = RouteStats(points: points([100, 150, 200]))

        #expect(stats.distanceM > 0)
        #expect(stats.ascentM == 100)
    }

    @Test func leavesAscentNilWithoutElevation() {
        let stats = RouteStats(points: points([nil, nil, nil]))

        #expect(stats.ascentM == nil)
    }

    @Test func estimatesMoreTimeForAClimbingRouteThanAFlatOne() {
        let flat = RouteStats(points: points([100, 100, 100]))
        let climbing = RouteStats(points: points([100, 400, 700]))

        #expect(climbing.estimatedMinutes > flat.estimatedMinutes)
    }

    // 4000m flat at 4 km/h (Naismith's baseline pace) is exactly 60 minutes.
    @Test func matchesNaismithsBaselinePaceOnAFlatRoute() {
        let stats = RouteStats(points: [
            TrackPoint(latitude: 0, longitude: 0, elevation: 100, time: nil),
            TrackPoint(latitude: 0.036, longitude: 0, elevation: 100, time: nil)
        ])

        #expect(stats.estimatedMinutes >= 55 && stats.estimatedMinutes <= 65)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/RouteStatsTests` should fail to build (`RouteStats` does not exist yet).

- [ ] **Step 5: Implement RouteStats**

`Gabay/Core/Route/RouteStats.swift`:

```swift
//
//  RouteStats.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// Distance, climb, and an estimated time, computed once from a parsed
// route. The same numbers this app used to compute per free trail, now
// computed once by the organizer's phone and carried on the Event instead
// of recomputed by every viewer.
struct RouteStats: Equatable, Sendable {

    let distanceM: Double

    // Absent when the file carries no elevation, which is different from flat.
    let ascentM: Double?

    let estimatedMinutes: Int

    init(points: [TrackPoint]) {
        distanceM = points.distance

        let hasElevation = points.contains { $0.elevation != nil }
        let ascent = hasElevation ? points.ascent() : nil
        ascentM = ascent

        // Naismith's rule: 4 km an hour, plus an hour per 600 m climbed.
        let seconds = distanceM / 4000 * 3600 + (ascent ?? 0) / 600 * 3600
        estimatedMinutes = Int((seconds / 60).rounded())
    }
}
```

- [ ] **Step 6: Run the RouteStats tests and verify they pass**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/RouteStatsTests` should show 4/4 passing.

- [ ] **Step 7: Commit**

```bash
git add Gabay/Core/Route GabayTests/RouteStatsTests.swift
git commit -m "Move GPXParser and TrackPoint into Core/Route, add RouteStats"
```

---

### Task 8: Features/Route (RoutePreviewMap and LocationPicker)

**Files:**
- Create: `Gabay/Features/Route/RoutePreviewMap.swift`
- Create: `Gabay/Features/Route/LocationPicker.swift`

**Interfaces:**
- Consumes: `TrackPoint` (Task 7), `Coordinate` (Task 5).
- Produces: `struct RoutePreviewMap: UIViewRepresentable` (takes `let points: [TrackPoint]`, draws a static route, no live position, no following). `struct LocationPicker: View` (takes `@Binding var coordinate: Coordinate?`, a pin-drop map that opens on the organizer's current location). Task 9's `EventDetailView` uses `RoutePreviewMap`; Task 11's `PostEventView` uses `LocationPicker`.

This is UI-only, like Tasks 4 and 9, no test cycle of its own.

This is a deliberate simplification of the free-trail app's `TrailMapView`, not a straight move: the old view tracked a live walker's position, heading, and a "follow me" mode (`WalkerAnnotationView`, `CLLocationManager.startUpdatingHeading()`, `MKUserTrackingMode`). None of that applies here, this is a static, view-only drawing of a route already walked or planned. `WalkerAnnotationView.swift` is not kept, it has no role without live tracking.

**Naming note:** the free-trail app's still-present, untouched `Gabay/Features/Trail/TrailMapView.swift` (deleted only in Task 12) already declares `final class RouteMapView: MKMapView` and `final class RouteCasing: MKPolyline {}` at file scope. Since both files compile into the same target, this task's new types must not reuse either name, or the build fails with "invalid redeclaration" until Task 12 runs. This task names its SwiftUI wrapper `RoutePreviewMap` (not `RouteMapView`) and its casing type `RouteLineCasing` (not `RouteCasing`) specifically to avoid that collision. Its `MKMapView` subclass is named `FramedMapView`, which does not collide with anything.

- [ ] **Step 1: Implement RoutePreviewMap**

`Gabay/Features/Route/RoutePreviewMap.swift`:

```swift
//
//  RoutePreviewMap.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import MapKit
import SwiftUI

// A read-only drawing of a route: no live position, no following, no
// compass. Used both for an organizer confirming an upload and for a
// hiker deciding whether to show up. Named apart from the free-trail
// app's still-present TrailMapView/RouteMapView/RouteCasing, which share
// this target until Task 12 removes them.
struct RoutePreviewMap: UIViewRepresentable {

    let points: [TrackPoint]

    func makeUIView(context: Context) -> FramedMapView {
        let view = FramedMapView()
        view.delegate = context.coordinator

        // Blue would suggest a live position, which this view never has.
        view.tintColor = .systemGray
        view.showsCompass = false
        view.pointOfInterestFilter = .excludingAll

        draw(on: view)
        return view
    }

    func updateUIView(_ view: FramedMapView, context: Context) {
        // The route a screen shows never changes after it is first drawn.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func draw(on view: FramedMapView) {
        guard points.count > 1 else { return }

        let coordinates = points.map(\.coordinate)
        let route = MKPolyline(coordinates: coordinates, count: coordinates.count)

        // A white casing, so the line reads against forest and rock alike.
        view.addOverlay(RouteLineCasing(coordinates: coordinates, count: coordinates.count))
        view.addOverlay(route)
        view.frame(route: route.boundingMapRect)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }

            let renderer = MKPolylineRenderer(polyline: line)
            let isCasing = overlay is RouteLineCasing

            // Named: converting Color.accentColor gives the system accent instead.
            renderer.strokeColor = isCasing ? .white : UIColor(named: "AccentColor")
            renderer.lineWidth = isCasing ? 9 : 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

// The wider line drawn underneath the route.
final class RouteLineCasing: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect
// on a zero sized view does nothing, and that is the state at make time.
final class FramedMapView: MKMapView {

    private static let padding = UIEdgeInsets(top: 40, left: 24, bottom: 40, right: 24)

    private var pending: MKMapRect?

    func frame(route rect: MKMapRect) {
        pending = rect
        applyPendingFrame()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPendingFrame()
    }

    private func applyPendingFrame() {
        guard let rect = pending, bounds.width > 0 else { return }
        pending = nil

        setVisibleMapRect(rect, edgePadding: Self.padding, animated: false)
    }
}
```

- [ ] **Step 2: Implement LocationPicker**

`Gabay/Features/Route/LocationPicker.swift`:

```swift
//
//  LocationPicker.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import CoreLocation
import MapKit
import SwiftUI

// Pin-drop for a meeting point: opens on the organizer's current location
// if they allow it, otherwise a fixed region around Cebu, tap anywhere to
// move the pin.
struct LocationPicker: View {

    @Binding var coordinate: Coordinate?

    @Environment(\.dismiss) private var dismiss

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.3157, longitude: 123.8854),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pin: CLLocationCoordinate2D?
    private let locator = OneShotLocator()

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin {
                        Marker(
                            "Meeting point",
                            coordinate: pin
                        )
                    }
                }
                .onTapGesture { point in
                    guard let tapped = proxy.convert(point, from: .local) else { return }
                    pin = tapped
                }
            }
            .navigationTitle(Text("Drop a pin", comment: "Title of the meeting-point picker"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the picker without setting a pin")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let pin {
                            coordinate = Coordinate(latitude: pin.latitude, longitude: pin.longitude)
                        }
                        dismiss()
                    } label: {
                        Text("Set", comment: "Confirms the dropped pin as the meeting point")
                    }
                    .disabled(pin == nil)
                }
            }
            .task {
                if let here = await locator.currentLocation() {
                    position = .region(
                        MKCoordinateRegion(center: here, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    )
                    pin = here
                }
            }
        }
    }
}

// A single current-location read, nothing held past that. No background
// mode, no continuous updates, just "where am I right now."
//
// Not @MainActor: CLLocationManagerDelegate is a plain, non-isolated
// protocol, and Swift 6 refuses a main-actor-isolated conformance to it
// (the delegate callbacks are not guaranteed to land on the main actor).
// @unchecked Sendable is the same escape hatch StubURLProtocol already
// uses elsewhere in this codebase for the same kind of delegate bridging,
// there is never more than one in-flight request per instance.
final class OneShotLocator: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // A permission decision made while a request is pending: ask again
        // now that we know the answer, or give up if it was denied.
        guard continuation != nil else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(returning: nil)
            continuation = nil
        default:
            break
        }
    }
}
```

- [ ] **Step 3: List the command for the user to verify it compiles**

`xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` should succeed (neither view is referenced anywhere yet, Tasks 9 and 11 wire them in).

- [ ] **Step 4: Commit**

```bash
git add Gabay/Features/Route
git commit -m "Add RoutePreviewMap and LocationPicker"
```

---

### Task 9: Events list, detail, and My Events screens

**Files:**
- Create: `Gabay/Features/Events/EventsListView.swift`
- Create: `Gabay/Features/Events/EventDetailView.swift`
- Create: `Gabay/Features/Events/MyEventsView.swift`
- Modify: `Gabay/Core/UI/ErrorStateView.swift`

**Interfaces:**
- Consumes: `EventsViewModel`, `Event` (Task 6/5), `Theme` (existing `DesignSystem/Theme.swift`), `ErrorStateView`/`LoadState` (existing `Core/UI`), `RoutePreviewMap` (Task 8), `GPXParser`, `TrackPoint` (Task 7).
- Produces: `struct EventsListView: View`, `struct EventDetailView: View`, `struct MyEventsView: View`. Task 12's `SignedInView` wires these into a `TabView`.

UI only, same rationale as Task 4. `EventDetailView` fetches and parses `event.gpxURL` itself when present (a small `.task` with a local `LoadState<[TrackPoint]>`, matching the existing `LoadState` pattern rather than inventing a new one), this is view glue around already-tested pieces (`GPXParser`, `RoutePreviewMap`), not new business logic, so it stays untested like the rest of this task's views.

- [ ] **Step 1: Generalize ErrorStateView's copy away from trails**

`ErrorStateView.swift`'s messages currently describe a trail download, the only thing that used it before. Modify `Gabay/Core/UI/ErrorStateView.swift`, replacing the `message` computed property:

```swift
    private var message: LocalizedStringKey {
        switch error {
        case .offline: "Check your connection and try again."
        case .timedOut: "The request did not finish in time."
        case .unavailable: "That's not available right now."
        default: "Try again in a moment."
        }
    }
```

(The `title` and `icon` properties are already generic; leave them unchanged.)

- [ ] **Step 2: Implement EventsListView**

`Gabay/Features/Events/EventsListView.swift`:

```swift
//
//  EventsListView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct EventsListView: View {

    @State var viewModel: EventsViewModel
    @State private var selected: Event?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                case .empty:
                    ContentUnavailableView {
                        Label {
                            Text("No events yet", comment: "Shown when no cause-hikes are published")
                        } icon: {
                            Image(systemName: "figure.hiking")
                        }
                    } description: {
                        Text("Check back soon for the next hike for a cause.",
                             comment: "Shown when the events list is empty")
                    }
                case let .failed(error):
                    ErrorStateView(error: error) { await viewModel.refresh() }
                case let .loaded(events):
                    list(events)
                }
            }
            .navigationTitle(Text("Events", comment: "Title of the cause-hike events list"))
            .navigationDestination(item: $selected) { event in
                EventDetailView(event: event, viewModel: viewModel)
            }
            .task { await viewModel.load() }
        }
    }

    private func list(_ events: [Event]) -> some View {
        List(events) { event in
            Button {
                selected = event
            } label: {
                row(event)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    private func row(_ event: Event) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(Theme.Font.body)

                Text(event.cause)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)

                Text(event.date, style: .date)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            Spacer(minLength: 0)

            if viewModel.joined.contains(event.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Color.success)
                    .accessibilityLabel(Text("Joined", comment: "Marks an event the hiker has already joined"))
            } else {
                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.tertiaryText)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}
```

- [ ] **Step 3: Implement EventDetailView, with the meeting-point mini-map and optional route**

`Gabay/Features/Events/EventDetailView.swift`:

```swift
//
//  EventDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import CoreLocation
import MapKit
import SwiftUI

struct EventDetailView: View {

    let event: Event
    let viewModel: EventsViewModel

    @Environment(\.openURL) private var openURL
    @State private var route: LoadState<[TrackPoint]> = .idle

    private var hasJoined: Bool { viewModel.joined.contains(event.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(event.title)
                    .font(Theme.Font.screenTitle)

                Text(event.cause)
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)

                details
                meetingMap

                if event.gpxURL != nil {
                    routeSection
                }

                Text(event.description)
                    .font(Theme.Font.body)

                joinButton
            }
            .screenPadding()
            .padding(.vertical, Theme.Spacing.lg)
        }
        .navigationTitle(Text("Hike Details", comment: "Title of an event's detail screen"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRoute() }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            row(icon: "calendar", text: event.date.formatted(date: .long, time: .shortened))
            row(icon: "mappin.and.ellipse", text: event.meetingPoint)
            row(icon: "pesosign.circle", text: "\u{20B1}\(event.feePHP) registration fee")
            row(icon: "person.2", text: "\(event.capacity) spots")
        }
        .font(Theme.Font.body)
    }

    private func row(icon: String, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
    }

    private var meetingMap: some View {
        let coordinate = CLLocationCoordinate2D(
            latitude: event.meetingCoordinate.latitude,
            longitude: event.meetingCoordinate.longitude
        )

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Map(initialPosition: .region(
                MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )) {
                Marker(event.meetingPoint, coordinate: coordinate)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .allowsHitTesting(false)

            Button {
                openURL(directionsURL(to: coordinate))
            } label: {
                Text("Get Directions", comment: "Opens the meeting point in Maps")
            }
        }
    }

    @ViewBuilder
    private var routeSection: some View {
        switch route {
        case .idle, .loading:
            ProgressView()
        case .empty, .failed:
            EmptyView()
        case let .loaded(points):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                RoutePreviewMap(points: points)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

                if let distanceM = event.distanceM {
                    Text(routeSummary(distanceM: distanceM, ascentM: event.ascentM, minutes: event.estimatedMinutes))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }
        }
    }

    private var joinButton: some View {
        Button {
            openURL(event.joinURL)
            Task { await viewModel.join(event) }
        } label: {
            if hasJoined {
                Text("Joined. Open Link Again", comment: "Button shown after the hiker has already joined")
            } else {
                Text("Join This Hike", comment: "Button that opens the external payment/coordination link")
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }

    private func loadRoute() async {
        guard let gpxURL = event.gpxURL, route.needsLoad else { return }

        route = .loading
        do {
            let (data, _) = try await URLSession.shared.data(from: gpxURL)
            let points = try GPXParser().parse(data).points
            route = .from(points)
        } catch {
            route = .failed(.classify(error))
        }
    }

    private func directionsURL(to coordinate: CLLocationCoordinate2D) -> URL {
        URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)")!
    }

    private func routeSummary(distanceM: Int, ascentM: Int?, minutes: Int?) -> String {
        let distanceText = Measurement(value: Double(distanceM), unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))

        var parts = [distanceText]
        if let ascentM {
            parts.append(Measurement(value: Double(ascentM), unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        if let minutes {
            parts.append("~\(minutes / 60)h \(minutes % 60)m")
        }
        return parts.joined(separator: " - ")
    }
}
```

- [ ] **Step 4: Implement MyEventsView**

`Gabay/Features/Events/MyEventsView.swift`:

```swift
//
//  MyEventsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct MyEventsView: View {

    @State var viewModel: EventsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.mine.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No events joined yet", comment: "Shown when the hiker hasn't joined any event")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                    } description: {
                        Text("Events you join show up here.",
                             comment: "Shown when My Events is empty")
                    }
                } else {
                    list
                }
            }
            .navigationTitle(Text("My Events", comment: "Title of the joined-events list"))
            .task { await viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.mine) { event in
            NavigationLink {
                EventDetailView(event: event, viewModel: viewModel)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(Theme.Font.body)
                    Text(event.date, style: .date)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                .padding(.vertical, 3)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }
}
```

- [ ] **Step 5: List the command for the user to verify everything compiles**

`xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` should succeed.

- [ ] **Step 6: List the command for the user to run the full suite, confirming the ErrorStateView change broke nothing**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (no test targets `ErrorStateView` directly, so this is a regression check on everything else).

- [ ] **Step 7: Commit**

```bash
git add Gabay/Features/Events Gabay/Core/UI/ErrorStateView.swift
git commit -m "Add the events list, detail, and My Events screens"
```

---

### Task 10: PostEventViewModel

**Files:**
- Create: `Gabay/Core/Events/PostEventViewModel.swift`
- Test: `GabayTests/PostEventViewModelTests.swift`

**Interfaces:**
- Consumes: `EventFetching`, `EventDraft`, `Coordinate` (Task 5), `StubEventFetching`, `Event.fixture` (Task 6 test doubles), `LoadFailure` (existing), `GPXParser`, `TrackPoint` (Task 7), `RouteStats` (Task 7).
- Produces: `@Observable @MainActor final class PostEventViewModel` with string-backed form fields (`title, cause, date: Date, meetingPoint, meetingCoordinate: Coordinate?, feePHP: String, capacity: String, joinURLText: String, eventDescription: String, photoURLText: String`), route state (`private(set) var route: RouteStats?`, `private(set) var gpxError: LoadFailure?`, `func pickGPX(at url: URL)`, `func removeGPX()`), `var canSubmit: Bool`, `func submit() async`, `private(set) var didSubmit: Bool`. Task 11's `PostEventView` and Task 12's `AppDependencies.makePostEventViewModel()` consume this.

- [ ] **Step 1: Write the failing PostEventViewModel tests**

`GabayTests/PostEventViewModelTests.swift`:

```swift
//
//  PostEventViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct PostEventViewModelTests {

    private func makeValidViewModel(events: StubEventFetching = StubEventFetching()) -> PostEventViewModel {
        let viewModel = PostEventViewModel(events: events)
        viewModel.title = "Hike for Pawssion Project"
        viewModel.cause = "Pawssion Project Cebu"
        viewModel.meetingPoint = "Budlaan barangay hall"
        viewModel.meetingCoordinate = Coordinate(latitude: 10.398, longitude: 123.887)
        viewModel.feePHP = "250"
        viewModel.capacity = "25"
        viewModel.joinURLText = "https://m.me/pawssionprojectcebu"
        viewModel.eventDescription = "A hike up Budlaan to Kang-Irag."
        return viewModel
    }

    private func gpxFixture(_ xml: String = "<gpx><trk><trkseg><trkpt lat=\"9.8\" lon=\"123.3\"/><trkpt lat=\"9.9\" lon=\"123.3\"/></trkseg></trk></gpx>") -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try! Data(xml.utf8).write(to: url)
        return url
    }

    @Test func cannotSubmitAnEmptyForm() {
        let viewModel = PostEventViewModel(events: StubEventFetching())
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceEveryFieldIsFilledCorrectly() {
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func cannotSubmitWithoutAMeetingCoordinate() {
        let viewModel = makeValidViewModel()
        viewModel.meetingCoordinate = nil
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsANonNumericFee() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "free"
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsAZeroCapacity() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "0"
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsAJoinLinkWithNoScheme() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "m.me/pawssionprojectcebu"
        #expect(viewModel.canSubmit == false)
    }

    @Test func aBlankPhotoLinkIsFine() {
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func rejectsAPhotoLinkWithNoScheme() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = "example.test/photo.jpg"
        #expect(viewModel.canSubmit == false)
    }

    @Test func pickingAValidGPXComputesRouteStats() throws {
        let viewModel = makeValidViewModel()
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }

        viewModel.pickGPX(at: file)

        #expect(viewModel.route != nil)
        #expect(viewModel.gpxError == nil)
    }

    @Test func aGPXIsOptionalAndDoesNotBlockSubmission() {
        // No GPX picked at all, canSubmit is still true from the other fields.
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func pickingAnUnreadableGPXReportsAnErrorAndClearsAnyRoute() throws {
        let viewModel = makeValidViewModel()
        let badFile = gpxFixture("not gpx at all")
        defer { try? FileManager.default.removeItem(at: badFile) }

        viewModel.pickGPX(at: badFile)

        #expect(viewModel.route == nil)
        #expect(viewModel.gpxError != nil)
    }

    @Test func removeGPXClearsTheRoute() throws {
        let viewModel = makeValidViewModel()
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        viewModel.pickGPX(at: file)

        viewModel.removeGPX()

        #expect(viewModel.route == nil)
    }

    @Test func submitCreatesTheEventAndMarksItSubmitted() async {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == true)
    }

    @Test func submitWithAPickedGPXAlsoUploadsIt() async throws {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        events.uploadGPXResult = .success(.fixture(gpxURL: URL(string: "https://example.test/r.gpx"), status: .pending))
        let viewModel = makeValidViewModel(events: events)
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        viewModel.pickGPX(at: file)

        await viewModel.submit()

        #expect(viewModel.didSubmit == true)
        #expect(events.uploadedGPXEventIds == ["hike-for-pawssion"])
    }

    @Test func aFailedSubmitReportsTheFailureAndDoesNotMarkSubmitted() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validationFailed)
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == false)
        #expect(viewModel.failure != nil)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/PostEventViewModelTests` should fail to build (`PostEventViewModel` does not exist yet).

- [ ] **Step 3: Implement PostEventViewModel**

`Gabay/Core/Events/PostEventViewModel.swift`:

```swift
//
//  PostEventViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class PostEventViewModel {

    var title = ""
    var cause = ""
    var date = Date()
    var meetingPoint = ""
    var meetingCoordinate: Coordinate?
    var feePHP = ""
    var capacity = ""
    var joinURLText = ""
    var eventDescription = ""
    var photoURLText = ""

    private(set) var isSubmitting = false
    private(set) var failure: LoadFailure?
    private(set) var didSubmit = false

    // A GPX is optional. Once picked, it must parse, a bad file blocks
    // only itself, with its own inline error, not the rest of the form.
    private(set) var route: RouteStats?
    private(set) var gpxError: LoadFailure?
    @ObservationIgnored private var gpxFileURL: URL?

    @ObservationIgnored private let events: any EventFetching
    @ObservationIgnored private let parser: GPXParser

    init(events: any EventFetching, parser: GPXParser = GPXParser()) {
        self.events = events
        self.parser = parser
    }

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    var isShowingConfirmation: Bool {
        get { didSubmit }
        set { if !newValue { didSubmit = false } }
    }

    var isShowingGPXFailure: Bool {
        get { gpxError != nil }
        set { if !newValue { gpxError = nil } }
    }

    // No image upload endpoint exists yet, so a photo is an already-hosted
    // link (the organizer's own upload elsewhere) rather than a picked
    // file, unlike the GPX, which does upload.
    var canSubmit: Bool {
        !isSubmitting
            && !title.trimmed.isEmpty
            && !cause.trimmed.isEmpty
            && !meetingPoint.trimmed.isEmpty
            && meetingCoordinate != nil
            && !eventDescription.trimmed.isEmpty
            && Int(feePHP) != nil
            && (Int(capacity) ?? 0) > 0
            && URL(string: joinURLText)?.scheme != nil
            && (photoURLText.trimmed.isEmpty || URL(string: photoURLText.trimmed)?.scheme != nil)
    }

    func pickGPX(at url: URL) {
        gpxError = nil

        do {
            let data = try Data(contentsOf: url)
            let points = try parser.parse(data).points
            route = RouteStats(points: points)
            gpxFileURL = url
        } catch {
            route = nil
            gpxFileURL = nil
            gpxError = .unavailable
        }
    }

    func removeGPX() {
        route = nil
        gpxFileURL = nil
        gpxError = nil
    }

    func submit() async {
        guard canSubmit,
              let fee = Int(feePHP),
              let capacity = Int(capacity),
              let joinURL = URL(string: joinURLText),
              let meetingCoordinate else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let draft = EventDraft(
            title: title.trimmed,
            cause: cause.trimmed,
            date: date,
            meetingPoint: meetingPoint.trimmed,
            meetingCoordinate: meetingCoordinate,
            feePHP: fee,
            capacity: capacity,
            joinURL: joinURL,
            description: eventDescription.trimmed,
            photoURL: photoURLText.trimmed.isEmpty ? nil : URL(string: photoURLText.trimmed)
        )

        do {
            let created = try await events.create(draft)

            if let route, let gpxFileURL {
                _ = try await events.uploadGPX(
                    eventID: created.id,
                    fileURL: gpxFileURL,
                    distanceM: Int(route.distanceM),
                    ascentM: route.ascentM.map(Int.init),
                    estimatedMinutes: route.estimatedMinutes
                )
            }

            didSubmit = true
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

- [ ] **Step 4: Run the PostEventViewModel tests and verify they pass**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/PostEventViewModelTests` should show 14/14 passing.

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Events/PostEventViewModel.swift GabayTests/PostEventViewModelTests.swift
git commit -m "Add PostEventViewModel, with optional GPX parsing and upload"
```

---

### Task 11: Post a Hike screen

**Files:**
- Create: `Gabay/Features/Events/PostEventView.swift`

**Interfaces:**
- Consumes: `PostEventViewModel` (Task 10), `LocationPicker` (Task 8), `Theme` (existing).
- Produces: `struct PostEventView: View`. Task 12's `SignedInView` shows this tab only when `Session.account?.role == .organizer`.

UI only, same rationale as Tasks 4 and 9.

- [ ] **Step 1: Implement PostEventView**

`Gabay/Features/Events/PostEventView.swift`:

```swift
//
//  PostEventView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct PostEventView: View {

    @State var viewModel: PostEventViewModel
    @State private var isPickingLocation = false
    @State private var isPickingGPX = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Title",
                        text: $viewModel.title,
                        prompt: Text("Title", comment: "Placeholder for the event title field")
                    )
                    TextField(
                        "Cause",
                        text: $viewModel.cause,
                        prompt: Text("Cause", comment: "Placeholder for the beneficiary/cause field")
                    )
                    DatePicker(selection: $viewModel.date) {
                        Text("Date", comment: "Label for the event date and time picker")
                    }
                } header: {
                    Text("Basics", comment: "Section header for an event's core details")
                }

                Section {
                    TextField(
                        "Meeting point",
                        text: $viewModel.meetingPoint,
                        prompt: Text("Meeting point", comment: "Placeholder for the meeting point label field")
                    )

                    Button {
                        isPickingLocation = true
                    } label: {
                        if viewModel.meetingCoordinate != nil {
                            Label {
                                Text("Pin set", comment: "Shown once a meeting point pin has been dropped")
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        } else {
                            Text("Choose on Map", comment: "Opens the meeting point pin-drop picker")
                        }
                    }
                } header: {
                    Text("Meeting Point", comment: "Section header for the meeting point label and pin")
                }

                Section {
                    TextField(
                        "Fee",
                        text: $viewModel.feePHP,
                        prompt: Text("Fee in pesos", comment: "Placeholder for the registration fee field")
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Capacity",
                        text: $viewModel.capacity,
                        prompt: Text("Capacity", comment: "Placeholder for the hiker capacity field")
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Join link",
                        text: $viewModel.joinURLText,
                        prompt: Text("https://", comment: "Placeholder for the external join/payment link field")
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Registration", comment: "Section header for fee, capacity, and join link")
                }

                gpxSection

                Section {
                    TextField(
                        "Photo link",
                        text: $viewModel.photoURLText,
                        prompt: Text("https:// (optional)",
                                     comment: "Placeholder for the optional event photo link field")
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Photo", comment: "Section header for the optional event photo")
                } footer: {
                    Text("Link to a photo already hosted somewhere, such as one you've posted elsewhere.",
                         comment: "Explains the photo link field, since there's no photo upload yet")
                }

                Section {
                    TextField(
                        "Description",
                        text: $viewModel.eventDescription,
                        prompt: Text("Description", comment: "Placeholder for the event description field"),
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                } header: {
                    Text("Description", comment: "Section header for the event description")
                }

                Section {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit for Review", comment: "Button that submits a new event for moderation")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle(Text("Post a Hike", comment: "Title of the organizer event-creation form"))
            .sheet(isPresented: $isPickingLocation) {
                LocationPicker(coordinate: $viewModel.meetingCoordinate)
            }
            .fileImporter(isPresented: $isPickingGPX, allowedContentTypes: [.gpxFile, .xml, .data]) { result in
                if case let .success(url) = result {
                    viewModel.pickGPX(at: url)
                }
            }
            .alert(
                Text("Submitted", comment: "Title confirming an event was submitted"),
                isPresented: $viewModel.isShowingConfirmation
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the submission confirmation")
                }
            } message: {
                Text("Your event is pending review before it appears publicly.",
                     comment: "Shown after an organizer submits a new event")
            }
            .alert(
                Text("Couldn't submit", comment: "Title when posting an event fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the submission failure alert")
                }
            } message: {
                Text("Check the form and try again.", comment: "Shown when posting an event fails")
            }
            .alert(
                Text("Couldn't read that file", comment: "Title when an attached GPX fails to parse"),
                isPresented: $viewModel.isShowingGPXFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the GPX read failure alert")
                }
            } message: {
                Text("Try a different GPX file, or leave the route out, it's optional.",
                     comment: "Shown when an attached GPX cannot be parsed")
            }
        }
    }

    @ViewBuilder
    private var gpxSection: some View {
        Section {
            if let route = viewModel.route {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label {
                        Text("Route attached", comment: "Shown once a GPX has been parsed successfully")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }

                    Text(routeSummary(route))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }

                Button(role: .destructive) {
                    viewModel.removeGPX()
                } label: {
                    Text("Remove Route", comment: "Removes the attached GPX from the form")
                }
            } else {
                Button {
                    isPickingGPX = true
                } label: {
                    Text("Attach a GPX (Optional)", comment: "Opens the file picker for an optional route")
                }
            }
        } header: {
            Text("Route", comment: "Section header for the optional GPX route")
        }
    }

    private func routeSummary(_ route: RouteStats) -> String {
        let distanceText = Measurement(value: route.distanceM, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))

        var parts = [distanceText]
        if let ascentM = route.ascentM {
            parts.append(Measurement(value: ascentM, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        parts.append("~\(route.estimatedMinutes / 60)h \(route.estimatedMinutes % 60)m")
        return parts.joined(separator: " - ")
    }
}

private extension UTType {

    // GPX is not one of Apple's declared types, so the app names it itself.
    // Named `gpxFile`, not `gpx`: the free-trail app's still-present
    // TrailsView.swift declares an internal `UTType.gpx` (deleted only in
    // Task 12), and a same-named member visible in this file would be
    // ambiguous at best.
    static let gpxFile = UTType(filenameExtension: "gpx") ?? .xml
}
```

- [ ] **Step 2: List the command for the user to verify it compiles**

`xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` should succeed.

- [ ] **Step 3: Commit**

```bash
git add Gabay/Features/Events/PostEventView.swift
git commit -m "Add the Post a Hike screen with pin-drop and GPX attach"
```

---

### Task 12: Cutover: wire the new app, remove the free-trail catalog subsystem

**Files:**
- Modify: `Gabay/App/RootView.swift`
- Modify: `Gabay/App/AppDependencies.swift`
- Modify: `Gabay/Core/AppConfig.swift`
- Modify: `Config/Development.xcconfig`, `Config/Staging.xcconfig`, `Config/Production.xcconfig`
- Modify: `Config/Info.plist`
- Modify: `Gabay.xcodeproj/project.pbxproj` (build settings only, not file references)
- Delete: `Gabay/Core/Trails/TrailCatalogClient.swift`, `Gabay/Core/Trails/CatalogCache.swift`, `Gabay/Core/Trails/TrailStore.swift`, `Gabay/Core/Trails/Trail.swift`
- Delete: `Gabay/Core/Trails/JSONCoders.swift` and `GabayTests/JSONCodersTests.swift`. `TrailCatalogClient` and `CatalogCache` were the only two consumers of the `.trails` `JSONEncoder`/`JSONDecoder` coder (used to read/cache `catalog.json`); once both are gone, `.trails` has no caller anywhere in the app (`GPXParser` parses XML, not JSON; `EventClient` uses the unrelated `.api` coder from Task 1). Deleting both leaves `Gabay/Core/Trails/` empty, remove the directory too.
- Delete: `Gabay/Features/Trail/` (all 4 files: `TrailsView.swift`, `TrailDetailView.swift`, `TrailMapView.swift`, `WalkerAnnotationView.swift`, the route-drawing logic was already extracted, under different names to avoid a redeclaration clash with this directory, into `Features/Route/RoutePreviewMap.swift` in Task 8)
- Delete: `trails/` (repo root)
- Delete: `GabayTests/TrailsViewModelTests.swift`, `GabayTests/TrailStoreTests.swift`, `GabayTests/CatalogCacheTests.swift`, `GabayTests/TrailCatalogClientTests.swift`
- Keep, do not delete: `GabayTests/GPXParserTests.swift` (moved to test `Core/Route/GPXParser.swift` in Task 7), `GabayTests/Fixtures/` (still used by it)

**Interfaces:**
- Consumes: `Session` (Task 3), `EventsViewModel` (Task 6), `SignInView`/`SignUpView` (Task 4), `EventsListView`/`MyEventsView` (Task 9), `PostEventView` (Task 11).
- Produces: the app's real launch flow. Nothing later depends on this task; it is the end of new code, and the deletion of the catalog/list-browsing code the new code replaces.

- [ ] **Step 1: Rewrite RootView**

Replace the full contents of `Gabay/App/RootView.swift`:

```swift
//
//  RootView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        Group {
            if dependencies.session.isSignedIn {
                SignedInView(dependencies: dependencies)
            } else {
                SignInView(
                    viewModel: dependencies.makeSignInViewModel(),
                    makeSignUpViewModel: dependencies.makeSignUpViewModel
                )
            }
        }
        .task { await dependencies.session.restore() }
    }
}

struct SignedInView: View {

    let dependencies: AppDependencies

    var body: some View {
        TabView {
            EventsListView(viewModel: dependencies.eventsViewModel)
                .tabItem {
                    Label {
                        Text("Events", comment: "Tab title for the list of cause-hike events")
                    } icon: {
                        Image(systemName: "figure.hiking")
                    }
                }

            MyEventsView(viewModel: dependencies.eventsViewModel)
                .tabItem {
                    Label {
                        Text("My Events", comment: "Tab title for events the hiker has joined")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }

            if dependencies.session.account?.role == .organizer {
                PostEventView(viewModel: dependencies.makePostEventViewModel())
                    .tabItem {
                        Label {
                            Text("Post a Hike", comment: "Tab title for the organizer event-creation form")
                        } icon: {
                            Image(systemName: "plus.circle")
                        }
                    }
            }
        }
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Starting up", comment: "Accessibility label for the launch screen"))
    }
}
```

- [ ] **Step 2: Rewrite AppDependencies**

Replace the full contents of `Gabay/App/AppDependencies.swift`:

```swift
//
//  AppDependencies.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting

    let session: Session
    let eventsViewModel: EventsViewModel

    private let events: any EventFetching

    init(
        session: Session,
        events: any EventFetching,
        eventsViewModel: EventsViewModel,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.session = session
        self.events = events
        self.eventsViewModel = eventsViewModel
        self.analytics = analytics
        self.crashes = crashes
    }

    static func live() -> AppDependencies {
        // Nothing is reported anywhere, but the seams stay.
        let analytics = NoopAnalyticsTracker()
        let crashes = NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        let tokenStore = TokenStore()
        let api = APIClient(base: AppConfig.apiBaseURL, tokenProvider: { tokenStore.load() })
        let session = Session(auth: AuthClient(api: api), tokenStore: tokenStore)
        let events = EventClient(api: api)

        return AppDependencies(
            session: session,
            events: events,
            eventsViewModel: EventsViewModel(events: events, session: session),
            analytics: analytics,
            crashes: crashes
        )
    }

    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(session: session)
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel(session: session)
    }

    func makePostEventViewModel() -> PostEventViewModel {
        PostEventViewModel(events: events)
    }
}
```

- [ ] **Step 3: Remove `catalogURL` from AppConfig**

Replace the full contents of `Gabay/Core/AppConfig.swift`:

```swift
//
//  AppConfig.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Values the xcconfigs set, read back through the generated Info.plist.
enum AppConfig {

    // Where the events/auth API lives.
    static let apiBaseURL: URL = {
        guard let value = string("API_BASE_URL"), let url = URL(string: value) else {
            fatalError("API_BASE_URL is missing. Set it in Config/<Environment>.xcconfig.")
        }
        return url
    }()

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }
}
```

- [ ] **Step 4: Remove `CATALOG_URL` from the xcconfigs**

In each of `Config/Development.xcconfig`, `Config/Staging.xcconfig`, and `Config/Production.xcconfig`, delete the `CATALOG_URL` line and its surrounding "Trail catalog" comment block (keep the "Events/auth API" / `API_BASE_URL` block from Task 1). For example, in `Config/Development.xcconfig`, delete these lines:

```
// Trail catalog

// "//" is a comment here, so escape the double slash as /$()/
CATALOG_URL = https:/$()/patrickechavez.github.io/gabay/trails
```

Do the equivalent removal in `Config/Staging.xcconfig` and `Config/Production.xcconfig`.

- [ ] **Step 5: Update Info.plist: remove `CATALOG_URL` and the background location mode, keep `NSLocationWhenInUseUsageDescription` out of it (that's a build setting, handled in Step 6)**

Replace the full contents of `Config/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Values come from Config/<Environment>.xcconfig via $(...) substitution.
	     Every value must be a string. AppConfig reads them as String first,
	     then parses. An <integer> or <true/> here would read back as nil.

	     Xcode rewrites this file whenever target settings change in the UI,
	     and strips these comments when it does. Check the diff afterwards. -->

	<key>API_BASE_URL</key>
	<string>$(API_BASE_URL)</string>
</dict>
</plist>
```

(`UIBackgroundModes: [location]` is removed since nothing tracks position in the background anymore, the meeting-point picker is a one-shot foreground read.)

- [ ] **Step 6: Replace the location usage-description build setting**

The app no longer tracks position in the background, so `NSLocationAlwaysAndWhenInUseUsageDescription` (repeated across the project's build configurations) is no longer accurate, but `NSLocationWhenInUseUsageDescription` is still needed for the meeting-point picker's one-shot read. Run:

```bash
cd /Users/patrick/Projects/Gabay
sed -i '' '/INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription/d' Gabay.xcodeproj/project.pbxproj
sed -i '' 's/INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Gabay shows where you are on the trail.";/INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Gabay centers the map on you when you drop a pin for a meeting point.";/' Gabay.xcodeproj/project.pbxproj
grep -c "INFOPLIST_KEY_NSLocation" Gabay.xcodeproj/project.pbxproj
```

Expected: the final `grep -c` prints `3` (one `NSLocationWhenInUseUsageDescription` per build configuration, the `Always` variant is gone).

- [ ] **Step 7: Delete the free-trail catalog/list-browsing subsystem**

```bash
cd /Users/patrick/Projects/Gabay
git rm -r Gabay/Core/Trails Gabay/Features/Trail trails
git rm GabayTests/TrailsViewModelTests.swift GabayTests/TrailStoreTests.swift \
  GabayTests/CatalogCacheTests.swift GabayTests/TrailCatalogClientTests.swift \
  GabayTests/JSONCodersTests.swift
```

`GPXParser.swift` and `TrackPoint.swift` were already moved out of `Gabay/Core/Trails/` in Task 7, so `git rm -r Gabay/Core/Trails` only removes `TrailCatalogClient.swift`, `CatalogCache.swift`, `TrailStore.swift`, `Trail.swift`, and `JSONCoders.swift`, the directory is empty afterward. Do not remove `GabayTests/GPXParserTests.swift` or `GabayTests/Fixtures/`.

- [ ] **Step 8: List the command for the user to verify the build**

`xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` should succeed (no references to `Trail`, `TrailsView`, `CatalogTrail`, `TrailMapView`, `WalkerAnnotationView`, or `AppConfig.catalogURL` remain anywhere).

- [ ] **Step 9: List the command for the user to run the full test suite**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` should show all tests passing. `AppEnvironmentTests`, `BreadcrumbTests`, and `GPXParserTests`/`TrackMathTests` are untouched by this task's deletions and should still pass unchanged.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Wire the events app and remove the free-trail catalog subsystem"
```

---

### Task 13: Rewrite the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- None; documentation only.

- [ ] **Step 1: Replace the README**

Replace the full contents of `README.md`:

```markdown
# Gabay

[![Tests](https://github.com/patrickechavez/gabay/actions/workflows/tests.yml/badge.svg)](https://github.com/patrickechavez/gabay/actions/workflows/tests.yml)

An iPhone app for hiking for a cause. Organizers post a hike, hikers join
for a small registration fee, and the fee goes to an animal shelter or
someone who needs medical help.

Gabay is Filipino for guide.

- iOS 17+ - Swift 6 - Xcode 26 - no third-party dependencies other than the Firebase SDK

## Why this exists

Hiking groups already organize cause-hikes on Facebook: pay a small fee,
join a hike, the money goes to a shelter or someone in need. Gabay gives
that its own app: a list of upcoming hikes, who they benefit, what they
cost, where to meet, and a way to join.

## What it does

- Sign in or create an account
- Browse published cause-hike events: cause, date, fee, and a map of the
  meeting point, with directions
- See an organizer's optional GPX route: distance, climb, estimated time,
  and the path itself, view-only
- Join a hike, which opens the organizer's own payment/coordination link
- See the hikes joined so far, in one list
- Let organizer accounts post a new hike, with a pin-dropped meeting point
  and an optional GPX, reviewed before it goes public

## Payment

Gabay never touches money. Joining a hike hands off to an external link the
organizer controls (GCash, Messenger, a payment page, whatever they use).
The app only remembers that a hiker tapped Join.

## Accounts

Every account is either a hiker or an organizer. Organizer accounts are set
by hand after vetting a shelter or cause partner. There is no self-service
way to become one inside the app.

## Building

Nothing to configure. Clone, open, run.

```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Three schemes, three configurations, one shared base in `Config/`. They
install side by side, so a development build never replaces the one on a
real phone.

| | Development | Staging | Production |
|---|---|---|---|
| Bundle ID | `.dev` | `.staging` | *(none)* |
| Logging | on | off | off |

The only value that reaches code from the xcconfigs is `API_BASE_URL`,
pointing at the events/auth backend. That backend does not exist yet: the
development value is a placeholder for a local server.

## Structure

```
Gabay/
├── App/            entry point, composition root
├── Core/
│   ├── Networking/ shared API client, JSON coding
│   ├── Auth/       sign-in, session, Keychain token storage
│   ├── Events/     event listing, joining, organizer submission
│   ├── Route/      GPX parsing, distance/climb/time calculation
│   ├── UI/         LoadState, error states
│   └── Observability/
├── DesignSystem/   theme
├── Features/
│   ├── Auth/       sign-in, sign-up
│   ├── Events/     the list, an event's detail, My Events, Post a Hike
│   └── Route/      the read-only route map, the meeting-point pin picker
└── Resources/      String Catalog
```

Views hold no logic. A view model owns the state, and everything below it
sits behind a protocol, which is what lets the tests run without a network
or a Keychain of their own.

```bash
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Every push and pull request runs the same suite on CI, against whichever
Xcode and simulator the runner happens to carry.

## Not built yet

- The events/auth backend itself: a separate project, built in C#.
- In-app payment.
- Partnership with local government and DSWD for solicitation permits,
  deliberately deferred since payment never moves through the app.
- Actually following a route live (a walking GPS overlay). The route view
  is look-before-you-go, not navigation.
- Sign in with Apple.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/patrick/Projects/Gabay
git add README.md
git commit -m "Rewrite the README for the events platform"
```

---

### Task 14: Final verification

**Files:** none (verification only).

- [ ] **Step 1: List the command for the user to run the full test suite one more time**

`xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` should show all tests passing.

- [ ] **Step 2: List the commands for the user to build all three schemes**

```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Staging -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Production -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

All three should succeed (this catches any config value only one scheme reads correctly).

- [ ] **Step 3: Confirm the working tree is clean**

`git status` should show `nothing to commit, working tree clean`, on branch `events-platform`.

- [ ] **Step 4: Manually run the app and verify the golden path**

Since the C# backend does not exist yet, this step confirms the UI itself, not a real sign-in. Launch the Development build in the simulator and confirm: the sign-in screen appears at launch (no crash from `AppConfig.apiBaseURL` failing to resolve, since `Config/Development.xcconfig` sets `API_BASE_URL`), the Sign Up sheet opens and closes, and the Post a Hike tab is absent when there is no signed-in account. A full join/post round trip, including a real GPX upload, needs the real backend and is out of scope until it exists.
