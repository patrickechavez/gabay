# Events Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gabay's free GPX-trail feature with a cause-hike events platform: sign in, browse and join events (soft RSVP, external payment link), and let organizer-flagged accounts post a new event for moderation, built against a REST contract for a C# backend that does not exist yet.

**Architecture:** Mirror the existing protocol-behind-view-model pattern (client -> store/view model -> view, views hold no logic) for two new domains, Auth and Events, sharing one small networking core. The free-trail code (Core/Trails, Features/Trail, trails/) is deleted once the new code fully replaces what it did.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, Swift Testing (`import Testing`, `@Test`), `URLSession` with a stub `URLProtocol` for network tests, Keychain (`Security` framework) for token storage. No third-party dependencies.

## Global Constraints

- iOS 17+, Swift 6, Xcode 26 (matches the existing scheme/target settings; do not change deployment target or Swift version).
- No third-party dependencies. Everything here uses only Foundation, SwiftUI, and Security.
- No em dashes anywhere: not in code comments, not in this plan, not in commit messages. Use a comma, period, or a hyphen surrounded by spaces (` - `) instead.
- Views hold no logic. State and side effects live in an `@Observable` `@MainActor` view model; the view model depends on protocols (`Authenticating`, `TokenStoring`, `EventFetching`), never concrete network types, so tests can substitute stubs.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for both the `Gabay` and `GabayTests` targets: any file created or deleted under `Gabay/` or `GabayTests/` on disk is automatically added to or removed from the build. **Never edit `Gabay.xcodeproj/project.pbxproj` to add or remove a source file** - only `git mv`/`git rm`/`Write` the file itself. The one exception in this plan is removing three build-setting lines (`INFOPLIST_KEY_NSLocation*`) in Task 10, which are build settings, not file references.
- Every commit message ends with:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```
- Test command for any single suite:
  `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/<SuiteName>`
- Test command for the whole suite: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- All work happens on the `events-platform` branch (already created from `main` at commit `b9810a6`; current head is `68cfba3`). Do not switch branches during this plan.

---

### Task 1: Shared networking core

**Files:**
- Create: `Gabay/Core/Networking/APIClient.swift`
- Create: `Gabay/Core/Networking/JSONCoders.swift`
- Modify: `Gabay/Core/AppConfig.swift`
- Modify: `Config/Development.xcconfig`, `Config/Staging.xcconfig`, `Config/Production.xcconfig`
- Modify: `Config/Info.plist`
- Create: `GabayTests/Support/StubURLProtocol.swift`
- Test: `GabayTests/APIClientTests.swift`
- Test: `GabayTests/APICodersTests.swift`

**Interfaces:**
- Produces: `struct APIClient: Sendable`, with `init(base: URL, configuration: URLSessionConfiguration = .default, tokenProvider: @escaping @Sendable () -> String? = { nil })`, `func get<Response: Decodable>(_ path: String) async throws -> Response`, `func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response`, `func post(_ path: String) async throws`.
- Produces: `enum APIError: Error, Equatable { case badResponse, unauthorized, forbidden, validationFailed, server }`.
- Produces: `JSONEncoder.api`, `JSONDecoder.api` (static computed properties).
- Produces: `AppConfig.apiBaseURL: URL`.
- Produces (test support): `final class StubURLProtocol: URLProtocol` with `Reply`, `reset()`, `queue(_:)`, `asked`. Every later networking test reuses this.

- [ ] **Step 1: Create the shared stub URLProtocol test helper**

`GabayTests/Support/StubURLProtocol.swift`:

```swift
//
//  StubURLProtocol.swift
//  GabayTests
//

import Foundation

// Answers requests from a queue, and keeps what it was asked. Shared by
// every test that stubs a network call instead of talking to a server.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    struct Reply {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    nonisolated(unsafe) private static var replies: [Reply] = []

    nonisolated(unsafe) private(set) static var asked: [URLRequest] = []

    static func reset() {
        replies = []
        asked = []
    }

    static func queue(_ reply: Reply) {
        replies.append(reply)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.asked.append(request)

        guard !Self.replies.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let reply = Self.replies.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Write the failing APIClient tests**

`GabayTests/APIClientTests.swift`:

```swift
//
//  APIClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct APIClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient(token: String? = nil) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return APIClient(base: base, configuration: configuration, tokenProvider: { token })
    }

    private struct Payload: Codable, Equatable {
        let value: Int
    }

    @Test func decodesAGetResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let payload: Payload = try await client.get("thing")

        #expect(payload == Payload(value: 1))
    }

    @Test func sendsAPostBodyAndDecodesTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":2}".utf8)))

        let payload: Payload = try await client.post("thing", body: Payload(value: 2))

        #expect(payload == Payload(value: 2))
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func postWithoutABodyIgnoresTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 204, body: Data()))

        try await client.post("thing/join")

        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func attachesTheTokenWhenThereIsOne() async throws {
        let client = makeClient(token: "abc123")
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let _: Payload = try await client.get("thing")

        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
    }

    @Test func sendsNoAuthorizationHeaderWithoutAToken() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let _: Payload = try await client.get("thing")

        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func mapsA401ToUnauthorized() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        await #expect(throws: APIError.unauthorized) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsA403ToForbidden() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 403, body: Data()))

        await #expect(throws: APIError.forbidden) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsA422ToValidationFailed() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 422, body: Data()))

        await #expect(throws: APIError.validationFailed) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsAnythingElseToServer() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 500, body: Data()))

        await #expect(throws: APIError.server) {
            let _: Payload = try await client.get("thing")
        }
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/APIClientTests`
Expected: BUILD FAILED (`APIClient`, `APIError`, and `JSONDecoder.api` do not exist yet)

- [ ] **Step 4: Implement the JSON coders**

`Gabay/Core/Networking/JSONCoders.swift`:

```swift
//
//  JSONCoders.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

extension JSONEncoder {

    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {

    // No snake_case conversion: the backend's JSON already matches Swift's
    // camelCase property names one to one. Converting would mangle a field
    // like `feePHP` into `fee_p_h_p`.
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601Tolerant
        return decoder
    }
}

private extension JSONDecoder.DateDecodingStrategy {

    static var iso8601Tolerant: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]

            if let date = withFractional.date(from: string) ?? standard.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO 8601 date, got \"\(string)\""
            )
        }
    }
}
```

- [ ] **Step 5: Implement APIClient**

`Gabay/Core/Networking/APIClient.swift`:

```swift
//
//  APIClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// Talks to the events/auth backend. AuthClient and EventClient both build
// on this rather than each rolling their own URLSession and status-code
// handling.
struct APIClient: Sendable {

    // A request that has not answered in this long is not worth waiting for.
    private static let timeout: TimeInterval = 20

    let base: URL

    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    // The configuration is a parameter so a test can hand it a stub
    // protocol. The token provider reads the current session token on every
    // call, so one client instance works before and after sign-in.
    init(
        base: URL,
        configuration: URLSessionConfiguration = .default,
        tokenProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        self.base = base
        self.tokenProvider = tokenProvider

        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        try await send(makeRequest(path: path, method: "GET"))
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = makeRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder.api.encode(body)
        return try await send(request)
    }

    // For calls whose success carries nothing worth decoding, like joining an event.
    func post(_ path: String) async throws {
        _ = try await sendRaw(makeRequest(path: path, method: "POST"))
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: base.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        try JSONDecoder.api.decode(Response.self, from: try await sendRaw(request))
    }

    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }

        switch http.statusCode {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 400, 422: throw APIError.validationFailed
        default: throw APIError.server
        }
    }
}

enum APIError: Error, Equatable {
    case badResponse
    case unauthorized
    case forbidden
    case validationFailed
    case server
}
```

- [ ] **Step 6: Add `AppConfig.apiBaseURL`**

Modify `Gabay/Core/AppConfig.swift`, adding this property alongside the existing `catalogURL` (which Task 10 removes later):

```swift
    // Where the events/auth API lives.
    static let apiBaseURL: URL = {
        guard let value = string("API_BASE_URL"), let url = URL(string: value) else {
            fatalError("API_BASE_URL is missing. Set it in Config/<Environment>.xcconfig.")
        }
        return url
    }()
```

- [ ] **Step 7: Add `API_BASE_URL` to the xcconfigs**

In `Config/Development.xcconfig`, add a new section (there is no real backend yet, so this points at a local one):

```
// Events/auth API

// No backend yet; point at a local one while developing
API_BASE_URL = http:/$()/localhost:5000
```

In `Config/Staging.xcconfig`, add:

```
// Events/auth API

// Placeholder until the C# backend has a staging URL
API_BASE_URL = https:/$()/staging-api.example.com
```

In `Config/Production.xcconfig`, add:

```
// Events/auth API

// Placeholder until the C# backend is deployed
API_BASE_URL = https:/$()/api.example.com
```

- [ ] **Step 8: Expose `API_BASE_URL` through Info.plist**

Modify `Config/Info.plist`, adding this key inside `<dict>` alongside the existing `CATALOG_URL` entry (which Task 10 removes later):

```xml
	<key>API_BASE_URL</key>
	<string>$(API_BASE_URL)</string>
```

- [ ] **Step 9: Run the APIClient tests and verify they pass**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/APIClientTests`
Expected: all 9 tests PASS

- [ ] **Step 10: Write and run the JSON coder tests**

`GabayTests/APICodersTests.swift`:

```swift
//
//  APICodersTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct APICodersTests {

    private struct Stamped: Codable, Equatable {
        var recordedAt: Date
    }

    private func decode(_ stamp: String) throws -> Date {
        let data = Data("{\"recordedAt\":\"\(stamp)\"}".utf8)
        return try JSONDecoder.api.decode(Stamped.self, from: data).recordedAt
    }

    private var noon: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 11
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")

        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func readsAPlainISO8601Stamp() throws {
        #expect(try decode("2026-09-11T12:00:00Z") == noon)
    }

    @Test func readsAStampWithFractionalSeconds() throws {
        #expect(try decode("2026-09-11T12:00:00.000Z") == noon)
    }

    @Test func readsAStampWithAnOffsetRatherThanZulu() throws {
        #expect(try decode("2026-09-11T20:00:00+08:00") == noon)
    }

    @Test func refusesSomethingThatIsNotADate() {
        #expect(throws: (any Error).self) {
            try decode("11 September 2026")
        }
    }

    // A field with consecutive capitals must round-trip exactly, proving
    // the coders do not apply snake_case conversion.
    @Test func leavesAConsecutiveCapitalKeyAlone() throws {
        struct Fee: Codable, Equatable {
            var feePHP: Int
        }

        let data = try JSONEncoder.api.encode(Fee(feePHP: 250))
        let decoded = try JSONDecoder.api.decode(Fee.self, from: data)

        #expect(String(data: data, encoding: .utf8)?.contains("\"feePHP\"") == true)
        #expect(decoded == Fee(feePHP: 250))
    }

    @Test func roundTripsThroughBothCoders() throws {
        let written = Stamped(recordedAt: noon)

        let data = try JSONEncoder.api.encode(written)
        let read = try JSONDecoder.api.decode(Stamped.self, from: data)

        #expect(read == written)
    }
}
```

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/APICodersTests`
Expected: all 6 tests PASS

- [ ] **Step 11: Commit**

```bash
git add Gabay/Core/Networking Gabay/Core/AppConfig.swift Config/Development.xcconfig Config/Staging.xcconfig Config/Production.xcconfig Config/Info.plist GabayTests/Support/StubURLProtocol.swift GabayTests/APIClientTests.swift GabayTests/APICodersTests.swift
git commit -m "$(cat <<'EOF'
Add a shared API client for the events/auth backend

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

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

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/TokenStoreTests`
Expected: BUILD FAILED (`TokenStore` does not exist yet)

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

- [ ] **Step 4: Run the TokenStore tests and verify they pass**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/TokenStoreTests`
Expected: all 4 tests PASS

- [ ] **Step 5: Write the failing AuthClient tests**

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

- [ ] **Step 6: Run to verify it fails**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/AuthClientTests`
Expected: BUILD FAILED (`AuthClient`, `Account`, `AuthResult`, `AccountRole` do not exist yet)

- [ ] **Step 7: Implement AuthClient**

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

- [ ] **Step 8: Run the AuthClient tests and verify they pass**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/AuthClientTests`
Expected: all 4 tests PASS

- [ ] **Step 9: Create the shared test doubles file, for Session tests (Task 3) and later tasks to build on**

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

- [ ] **Step 10: Commit**

```bash
git add Gabay/Core/Auth/TokenStore.swift Gabay/Core/Auth/AuthClient.swift GabayTests/Support/TestDoubles.swift GabayTests/TokenStoreTests.swift GabayTests/AuthClientTests.swift
git commit -m "$(cat <<'EOF'
Add TokenStore and AuthClient for the events backend

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
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

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/SessionTests`
Expected: BUILD FAILED (`Session` does not exist yet)

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

- [ ] **Step 4: Run the Session tests and verify they pass**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/SessionTests`
Expected: all 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Auth/Session.swift GabayTests/SessionTests.swift
git commit -m "$(cat <<'EOF'
Add Session to track the signed-in hiker

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Sign-in and sign-up screens

**Files:**
- Create: `Gabay/Features/Auth/SignInView.swift`
- Create: `Gabay/Features/Auth/SignUpView.swift`

**Interfaces:**
- Consumes: `Session` (Task 3), `LoadFailure` (existing `Core/UI/LoadFailure.swift`).
- Produces: `@Observable @MainActor final class SignInViewModel` (`email`, `password`, `canSubmit`, `func signIn() async`), `struct SignInView: View`. `@Observable @MainActor final class SignUpViewModel` (`email`, `password`, `canSubmit`, `func register() async -> Bool`), `struct SignUpView: View`. Task 10's `RootView`/`AppDependencies` wire these in.

This task is UI only, with no logic beyond what the view models already cover (view models are the testable unit; views are not unit-tested anywhere in this codebase, matching how `TrailsView` had no view test of its own, only `TrailsViewModelTests`). There is no TDD cycle for a view with no logic of its own, so this task's deliverable is verified by building successfully; Task 12 verifies the full flow by running the app.

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

- [ ] **Step 3: Build to verify both screens compile**

Run: `xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED (these views are not referenced by `RootView` until Task 10, so a successful build is the only signal at this point)

- [ ] **Step 4: Commit**

```bash
git add Gabay/Features/Auth
git commit -m "$(cat <<'EOF'
Add sign-in and sign-up screens

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Event model and EventClient

**Files:**
- Create: `Gabay/Core/Events/EventClient.swift`
- Test: `GabayTests/EventClientTests.swift`

**Interfaces:**
- Consumes: `APIClient`, `APIError` (Task 1).
- Produces: `struct Event: Codable, Identifiable, Equatable, Sendable` with `id, title, cause, date, meetingPoint, feePHP, capacity, joinURL, description, photoURL, status` (`status: Event.Status`, `enum Status: String, Codable, Sendable { case pending, published }`). `struct EventDraft: Encodable, Sendable` with the same fields except `id`/`status`. `protocol EventFetching: Sendable { func events() async throws -> [Event]; func event(id: String) async throws -> Event; func create(_ draft: EventDraft) async throws -> Event; func join(_ id: String) async throws; func mine() async throws -> [Event] }`, `struct EventClient: EventFetching`.

- [ ] **Step 1: Write the failing EventClient tests**

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
          "feePHP": 250,
          "capacity": 25,
          "joinURL": "https://m.me/pawssionprojectcebu",
          "description": "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
          "photoURL": null,
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
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/events")
    }

    @Test func readsOneEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: eventJSON))

        let event = try await client.event(id: "hike-for-pawssion")

        #expect(event.feePHP == 250)
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
            feePHP: 0, capacity: 1, joinURL: URL(string: "https://example.test")!,
            description: "x", photoURL: nil
        )

        await #expect(throws: APIError.forbidden) {
            try await client.create(draft)
        }
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

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventClientTests`
Expected: BUILD FAILED (`Event`, `EventDraft`, `EventClient` do not exist yet)

- [ ] **Step 3: Implement Event, EventDraft, and EventClient**

`Gabay/Core/Events/EventClient.swift`:

```swift
//
//  EventClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

struct Event: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
    let status: Status

    enum Status: String, Codable, Sendable {
        case pending
        case published
    }
}

// What the organizer form sends to create an event. No id or status: the
// backend assigns those.
struct EventDraft: Encodable, Sendable {
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
}

// Lists published events, lets an organizer post one, and tracks joins.
protocol EventFetching: Sendable {

    func events() async throws -> [Event]

    func event(id: String) async throws -> Event

    func create(_ draft: EventDraft) async throws -> Event

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

    func join(_ id: String) async throws {
        try await api.post("events/\(id)/join")
    }

    func mine() async throws -> [Event] {
        try await api.get("me/events")
    }
}
```

- [ ] **Step 4: Run the EventClient tests and verify they pass**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventClientTests`
Expected: all 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Events/EventClient.swift GabayTests/EventClientTests.swift
git commit -m "$(cat <<'EOF'
Add the Event model and EventClient

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: EventsViewModel

**Files:**
- Create: `Gabay/Core/Events/EventsViewModel.swift`
- Modify: `GabayTests/Support/TestDoubles.swift`
- Test: `GabayTests/EventsViewModelTests.swift`

**Interfaces:**
- Consumes: `EventFetching`, `Event` (Task 5), `Session` (Task 3), `LoadableViewModel`/`LoadState` (existing `Core/UI/LoadState.swift`).
- Produces: `@Observable @MainActor final class EventsViewModel: LoadableViewModel` with `var state: LoadState<[Event]>`, `private(set) var mine: [Event]`, `private(set) var joined: Set<String>`, `let events: any EventFetching`, `func load() async`, `func refresh() async`, `func join(_ event: Event) async`. Task 7's list/detail/My Events views and Task 10's `AppDependencies` consume this.
- Produces (test support, appended to `TestDoubles.swift`): `final class StubEventFetching: EventFetching`, `extension Event { static func fixture(...) -> Event }`, reused by Task 8's `PostEventViewModelTests`.

- [ ] **Step 1: Append shared Event/EventFetching test doubles**

Append to `GabayTests/Support/TestDoubles.swift`:

```swift

final class StubEventFetching: EventFetching, @unchecked Sendable {
    var eventsResult: Result<[Event], any Error> = .success([])
    var mineResult: Result<[Event], any Error> = .success([])
    var createResult: Result<Event, any Error> = .failure(APIError.forbidden)
    var joinResult: Result<Void, any Error> = .success(())
    private(set) var joinedIds: [String] = []

    func events() async throws -> [Event] { try eventsResult.get() }
    func event(id: String) async throws -> Event { try eventsResult.get().first { $0.id == id }! }
    func create(_ draft: EventDraft) async throws -> Event { try createResult.get() }

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
        status: Status = .published
    ) -> Event {
        Event(
            id: id,
            title: title,
            cause: "Pawssion Project Cebu",
            date: Date(timeIntervalSince1970: 1_760_000_000),
            meetingPoint: "Budlaan barangay hall",
            feePHP: 250,
            capacity: 25,
            joinURL: URL(string: "https://m.me/pawssionprojectcebu")!,
            description: "A hike up Budlaan to Kang-Irag.",
            photoURL: nil,
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

        #expect(events.joinedIds.isEmpty)
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

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventsViewModelTests`
Expected: BUILD FAILED (`EventsViewModel` does not exist yet)

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

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/EventsViewModelTests`
Expected: all 7 tests PASS

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Events/EventsViewModel.swift GabayTests/Support/TestDoubles.swift GabayTests/EventsViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add EventsViewModel for listing, refreshing, and joining events

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Events list, detail, and My Events screens

**Files:**
- Create: `Gabay/Features/Events/EventsListView.swift`
- Create: `Gabay/Features/Events/EventDetailView.swift`
- Create: `Gabay/Features/Events/MyEventsView.swift`
- Modify: `Gabay/Core/UI/ErrorStateView.swift`

**Interfaces:**
- Consumes: `EventsViewModel`, `Event` (Task 6/5), `Theme` (existing `DesignSystem/Theme.swift`), `ErrorStateView`/`LoadState` (existing `Core/UI`).
- Produces: `struct EventsListView: View`, `struct EventDetailView: View`, `struct MyEventsView: View`. Task 10's `SignedInView` wires these into a `TabView`.

UI only, same rationale as Task 4: verified by building, and by running the app in Task 12.

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

- [ ] **Step 3: Implement EventDetailView**

`Gabay/Features/Events/EventDetailView.swift`:

```swift
//
//  EventDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct EventDetailView: View {

    let event: Event
    let viewModel: EventsViewModel

    @Environment(\.openURL) private var openURL

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

                Text(event.description)
                    .font(Theme.Font.body)

                joinButton
            }
            .screenPadding()
            .padding(.vertical, Theme.Spacing.lg)
        }
        .navigationTitle(Text("Hike Details", comment: "Title of an event's detail screen"))
        .navigationBarTitleDisplayMode(.inline)
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

- [ ] **Step 5: Build to verify everything compiles**

Run: `xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Run the full test suite to confirm the ErrorStateView change broke nothing**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: all tests PASS (no test targets `ErrorStateView` directly, so this is a regression check on everything else)

- [ ] **Step 7: Commit**

```bash
git add Gabay/Features/Events Gabay/Core/UI/ErrorStateView.swift
git commit -m "$(cat <<'EOF'
Add the events list, detail, and My Events screens

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: PostEventViewModel

**Files:**
- Create: `Gabay/Core/Events/PostEventViewModel.swift`
- Test: `GabayTests/PostEventViewModelTests.swift`

**Interfaces:**
- Consumes: `EventFetching`, `EventDraft` (Task 5), `StubEventFetching`, `Event.fixture` (Task 6 test doubles), `LoadFailure` (existing).
- Produces: `@Observable @MainActor final class PostEventViewModel` with string-backed form fields (`title, cause, date: Date, meetingPoint, feePHP: String, capacity: String, joinURLText: String, eventDescription: String, photoURLText: String`), `var canSubmit: Bool`, `func submit() async`, `private(set) var didSubmit: Bool`. Task 9's `PostEventView` and Task 10's `AppDependencies.makePostEventViewModel()` consume this.

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
        viewModel.feePHP = "250"
        viewModel.capacity = "25"
        viewModel.joinURLText = "https://m.me/pawssionprojectcebu"
        viewModel.eventDescription = "A hike up Budlaan to Kang-Irag."
        return viewModel
    }

    @Test func cannotSubmitAnEmptyForm() {
        let viewModel = PostEventViewModel(events: StubEventFetching())
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceEveryFieldIsFilledCorrectly() {
        #expect(makeValidViewModel().canSubmit == true)
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

    @Test func submitCreatesTheEventAndMarksItSubmitted() async {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == true)
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

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/PostEventViewModelTests`
Expected: BUILD FAILED (`PostEventViewModel` does not exist yet)

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
    var feePHP = ""
    var capacity = ""
    var joinURLText = ""
    var eventDescription = ""
    var photoURLText = ""

    private(set) var isSubmitting = false
    private(set) var failure: LoadFailure?
    private(set) var didSubmit = false

    @ObservationIgnored private let events: any EventFetching

    init(events: any EventFetching) {
        self.events = events
    }

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    var isShowingConfirmation: Bool {
        get { didSubmit }
        set { if !newValue { didSubmit = false } }
    }

    // No image upload endpoint exists yet, so a photo is an already-hosted
    // link (the organizer's own upload elsewhere) rather than a picked file.
    var canSubmit: Bool {
        !isSubmitting
            && !title.trimmed.isEmpty
            && !cause.trimmed.isEmpty
            && !meetingPoint.trimmed.isEmpty
            && !eventDescription.trimmed.isEmpty
            && Int(feePHP) != nil
            && (Int(capacity) ?? 0) > 0
            && URL(string: joinURLText)?.scheme != nil
            && (photoURLText.trimmed.isEmpty || URL(string: photoURLText.trimmed)?.scheme != nil)
    }

    func submit() async {
        guard canSubmit,
              let fee = Int(feePHP),
              let capacity = Int(capacity),
              let joinURL = URL(string: joinURLText) else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let draft = EventDraft(
            title: title.trimmed,
            cause: cause.trimmed,
            date: date,
            meetingPoint: meetingPoint.trimmed,
            feePHP: fee,
            capacity: capacity,
            joinURL: joinURL,
            description: eventDescription.trimmed,
            photoURL: photoURLText.trimmed.isEmpty ? nil : URL(string: photoURLText.trimmed)
        )

        do {
            _ = try await events.create(draft)
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

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GabayTests/PostEventViewModelTests`
Expected: all 9 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Events/PostEventViewModel.swift GabayTests/PostEventViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add PostEventViewModel for the organizer event form

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Post a Hike screen

**Files:**
- Create: `Gabay/Features/Events/PostEventView.swift`

**Interfaces:**
- Consumes: `PostEventViewModel` (Task 8), `Theme` (existing).
- Produces: `struct PostEventView: View`. Task 10's `SignedInView` shows this tab only when `Session.account?.role == .organizer`.

UI only, same rationale as Tasks 4 and 7.

- [ ] **Step 1: Implement PostEventView**

`Gabay/Features/Events/PostEventView.swift`:

```swift
//
//  PostEventView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct PostEventView: View {

    @State var viewModel: PostEventViewModel

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
                    TextField(
                        "Meeting point",
                        text: $viewModel.meetingPoint,
                        prompt: Text("Meeting point", comment: "Placeholder for the meeting point field")
                    )
                } header: {
                    Text("Basics", comment: "Section header for an event's core details")
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
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Gabay/Features/Events/PostEventView.swift
git commit -m "$(cat <<'EOF'
Add the Post a Hike screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Cutover: wire the new app, remove the free-trail subsystem

**Files:**
- Modify: `Gabay/App/RootView.swift`
- Modify: `Gabay/App/AppDependencies.swift`
- Modify: `Gabay/Core/AppConfig.swift`
- Modify: `Config/Development.xcconfig`, `Config/Staging.xcconfig`, `Config/Production.xcconfig`
- Modify: `Config/Info.plist`
- Modify: `Gabay.xcodeproj/project.pbxproj` (build settings only, not file references)
- Delete: `Gabay/Core/Trails/` (all 7 files)
- Delete: `Gabay/Features/Trail/` (all 4 files)
- Delete: `trails/` (repo root)
- Delete: `GabayTests/TrailsViewModelTests.swift`, `GabayTests/TrailStoreTests.swift`, `GabayTests/GPXParserTests.swift`, `GabayTests/CatalogCacheTests.swift`, `GabayTests/TrailCatalogClientTests.swift`, `GabayTests/JSONCodersTests.swift`, `GabayTests/Fixtures/` (all 5 fixture files)

**Interfaces:**
- Consumes: `Session` (Task 3), `EventsViewModel` (Task 6), `SignInView`/`SignUpView` (Task 4), `EventsListView`/`MyEventsView` (Task 7), `PostEventView` (Task 9).
- Produces: the app's real launch flow. Nothing later depends on this task; it is the end of new code, and the deletion of everything the new code replaces.

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

In each of `Config/Development.xcconfig`, `Config/Staging.xcconfig`, and `Config/Production.xcconfig`, delete the `CATALOG_URL` line and its surrounding "Trail catalog" / "API" comment block that Task 1 left in place beside it (keep the `API_BASE_URL` block Task 1 added). For example, in `Config/Development.xcconfig`, delete these lines:

```
// Trail catalog

// "//" is a comment here, so escape the double slash as /$()/
CATALOG_URL = https:/$()/patrickechavez.github.io/gabay/trails
```

Do the equivalent removal in `Config/Staging.xcconfig` and `Config/Production.xcconfig` (their `CATALOG_URL` blocks are worded slightly differently but are removed the same way).

- [ ] **Step 5: Remove `CATALOG_URL` and the location background mode from Info.plist**

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

- [ ] **Step 6: Remove the unused location usage-description build settings**

The app no longer uses `CoreLocation`, so the two `INFOPLIST_KEY_NSLocation*` build settings (each repeated across the project's build configurations) are dead declarations. Run:

```bash
cd /Users/patrick/Projects/Gabay
sed -i '' '/INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription/d;/INFOPLIST_KEY_NSLocationWhenInUseUsageDescription/d' Gabay.xcodeproj/project.pbxproj
grep -c "INFOPLIST_KEY_NSLocation" Gabay.xcodeproj/project.pbxproj
```

Expected: the `grep -c` prints `0`.

- [ ] **Step 7: Delete the free-trail subsystem**

```bash
cd /Users/patrick/Projects/Gabay
git rm -r Gabay/Core/Trails Gabay/Features/Trail trails \
  GabayTests/TrailsViewModelTests.swift GabayTests/TrailStoreTests.swift \
  GabayTests/GPXParserTests.swift GabayTests/CatalogCacheTests.swift \
  GabayTests/TrailCatalogClientTests.swift GabayTests/JSONCodersTests.swift \
  GabayTests/Fixtures
```

- [ ] **Step 8: Build the app**

Run: `xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED (no references to `Trail`, `TrailsView`, `CatalogTrail`, or `AppConfig.catalogURL` remain anywhere)

- [ ] **Step 9: Run the full test suite**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: all tests PASS. `AppEnvironmentTests` and `BreadcrumbTests` are untouched by this plan and should still pass unchanged.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Wire the events app and remove the free-trail subsystem

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Rewrite the README

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

- iOS 17+ - Swift 6 - Xcode 26 - no third-party dependencies

## Why this exists

Hiking groups already organize cause-hikes on Facebook: pay a small fee,
join a hike, the money goes to a shelter or someone in need. Gabay gives
that its own app: a list of upcoming hikes, who they benefit, what they
cost, and a way to join.

## What it does

- Sign in or create an account
- Browse published cause-hike events: cause, date, fee, meeting point
- Join a hike, which opens the organizer's own payment/coordination link
- See the hikes joined so far, in one list
- Let organizer accounts post a new hike, reviewed before it goes public

There is no hike route, map, or GPS tracking yet. See "Not built yet" below.

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
│   ├── UI/         LoadState, error states
│   └── Observability/
├── DesignSystem/   theme
├── Features/
│   ├── Auth/       sign-in, sign-up
│   └── Events/     the list, an event's detail, My Events, Post a Hike
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
- Following an event's actual route on a map. Phase 1 is informational
  only: cause, date, fee, meeting point.
- In-app payment.
- Partnership with local government and DSWD for solicitation permits,
  deliberately deferred since payment never moves through the app in
  phase 1.
- Sign in with Apple.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/patrick/Projects/Gabay
git add README.md
git commit -m "$(cat <<'EOF'
Rewrite the README for the events platform

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite one more time**

Run: `xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: all tests PASS

- [ ] **Step 2: Build all three schemes**

Run:
```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Staging -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Production -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED for all three (this catches any config value only one scheme reads correctly)

- [ ] **Step 3: Confirm the working tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`, on branch `events-platform`

- [ ] **Step 4: Manually run the app and verify the golden path**

Since the C# backend does not exist yet, this step confirms the UI itself, not a real sign-in. Launch the Development build in the simulator and confirm: the sign-in screen appears at launch (no crash from `AppConfig.apiBaseURL` failing to resolve, since `Config/Development.xcconfig` now sets `API_BASE_URL`), the Sign Up sheet opens and closes, and the Post a Hike tab is absent when there is no signed-in account. A full join/post round trip needs the real backend and is out of scope until it exists.
