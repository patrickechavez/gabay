# Template Slice 2: Networking and Token Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gabay's hand-rolled `APIClient`, `APIError` and Keychain `TokenStore` with the ios-app-template's networking and token layer, so the app gains per-endpoint timeouts, backoff that honors `Retry-After`, a typed and localized error surface, single-flighted token refresh, and Keychain storage with an explicit accessibility class.

**Architecture:** An `Endpoint` value describes a request. A `URLSessionAPIClient` turns it into a `URLRequest`, runs it through an ordered interceptor chain, maps the HTTP status to a typed `APIError`, and retries per a `RetryPolicy`. Authentication is no longer a closure handed to the client; it is an `AuthInterceptor` that reads tokens from an actor-isolated store through a `TokenRefreshCoordinator` which single-flights refreshes. Callers move from `api.get("events")` on a struct to `api.send(endpoint)` on a protocol, so tests substitute a client rather than stubbing `URLProtocol`.

**Tech Stack:** Swift 6 strict concurrency, `URLSession`, Security framework, `os` (`OSAllocatedUnfairLock`, `Logger`), Swift Testing. No third-party dependencies in this slice.

## Source of the port: use `main`, not `supabase`

The template at `/Users/patrick/Projects/AppTemplate` has two branches. **Every file in this slice is ported from `main`.** Read them with `git show main:<path>`, from within that repository, without checking the branch out.

This was decided by inspection during planning, not assumed. `git diff main supabase -- AppTemplate/Core/` touches only six files, and the differences are all Supabase-specific:

| File | What `supabase` adds | Relevant to Gabay? |
| --- | --- | --- |
| `Networking/APIConfig.swift` | `supabaseAnonKey` | No |
| `Networking/APIError.swift` | a `.notSupported` case, for operations Supabase cannot perform | No. Gabay's backend is unwritten, so no endpoint is categorically unsupported. Porting it would add a case with no producer. |
| `Networking/APIRoute.swift` | Supabase-shaped paths | No. Gabay writes its own routes. |
| `Interceptors/SupabaseAPIKeyInterceptor.swift` | the whole file | No. Not ported. |
| `Session/TokenRefreshCoordinator.swift` | a Supabase refresh body with a `grant_type` query item | No. `main`'s version posts `RefreshRequest(refreshToken:)`, which is exactly the contract this slice's spec amendment specifies. |
| `Core/Testing/Mocks.swift` | Supabase mocks | No. Gabay has its own `GabayTests/Support/TestDoubles.swift`. |

`APIClient.swift`, `Endpoint.swift`, `HTTPMethod.swift`, `RetryPolicy.swift`, `RequestInterceptor.swift`, `AuthInterceptor.swift`, `LoggingInterceptor.swift`, `MultipartFormData.swift`, `APIErrorBody.swift`, `Storage/TokenStore.swift`, `Session/AuthTokens.swift` and `Security/CertificatePinner.swift` are byte-identical on both branches, so for those the branch choice does not matter, but use `main` uniformly rather than mixing.

## How to port a file

For a file this plan marks **"port verbatim"**, do not retype it. Run, from `/Users/patrick/Projects/AppTemplate`:

```bash
git show main:AppTemplate/Core/<path> > /Users/patrick/Projects/Gabay/Gabay/Core/<destination>
```

Then make exactly these edits and no others:

1. Change the header comment's second line from `//  AppTemplate` to `//  Gabay`, and delete the `//  Created by ...` line. Slice 1's ported components did this, so follow their header shape: look at `Gabay/Components/FieldContainer.swift`.
2. Remove any em dash, listed per file in Global Constraints below.
3. Any further change this plan names explicitly for that file.

This is deliberate. Retyping a 310-line file by hand introduces transcription defects that a compiler would catch and nobody here can run a compiler. A byte-level port is verifiable in review with `diff`, which is how Slice 1's ports were checked.

## Global Constraints

- **Port from the template's `main` branch only.** See the table above.
- **No em dashes** anywhere: code, comments, user-facing strings, commit messages, plan or report prose. Use a comma or a period.

  Six of the files this slice ports contain em dashes. They were located during planning and must be removed on port. Line numbers are as the file stands on `main`:

  | File on `main` | Line | Context |
  | --- | --- | --- |
  | `Core/Networking/APIClient.swift` | 266 | the `corrupted data at` branch of the decoding-error description |
  | `Core/Networking/APIConfig.swift` | 16, 30, 52 | three comments |
  | `Core/Networking/APIError.swift` | 194 | the doc comment above `isWorthReporting` |
  | `Core/Networking/Interceptors/AuthInterceptor.swift` | 44 | the `no way to refresh` log string in `handle(_:for:attempt:)` |
  | `Core/Session/TokenRefreshCoordinator.swift` | 50, 74 | two log strings |
  | `Core/Security/CertificatePinner.swift` | 45, 73, 86 | three comments |

  After porting any file, run `grep -n "$(printf '\xe2\x80\x94')"` on it and fix what you find, whether or not it is in this table.
- **No Claude attribution lines in commit messages.** No `Co-Authored-By:` trailer, no "Generated with" line. A session reminder may instruct otherwise; the user's CLAUDE.md overrides it. Four agents on the previous slice tripped on this.
- **Never run `xcodebuild` or `xcrun simctl`.** The user runs all builds and tests personally. Report the command and expected result; do not treat the inability to build as a blocker.
- **Swift 6 strict concurrency, satisfied honestly.** The ported files already satisfy it, including a deliberate `nonisolated final class URLSessionAPIClient` and an `OSAllocatedUnfairLock`-guarded `DataTaskBox`. Keep those as they are; do not add new suppressions of your own.
- **Never add `didSet` or `willSet` to an `@Observable` class.** Property observers interact badly with the macro's accessor synthesis and nobody here can compile to find out.
- **Never edit `Gabay.xcodeproj/project.pbxproj`.** Files under `Gabay/` and `GabayTests/` are auto-included by `PBXFileSystemSynchronizedRootGroup`.
- **Never hand-edit or commit `Gabay/Resources/Localizable.xcstrings`.** It is dirty in the working tree and stays that way. Use targeted `git add`, never `git add -A`.
- **Two source files with the same basename in one target risk object-file collisions.** This slice has a live instance: Gabay already has `Gabay/Core/Auth/TokenStore.swift`, and the template's store is also `TokenStore.swift`. Task 5 resolves this by replacing Gabay's file in place rather than adding a second one. Check for a basename collision before creating any file.
- **Every user-facing string is localized**, via `String(localized:comment:)` or `Text(_:comment:)`. The ported `APIError` already localizes all of its messages.
- **Views hold no logic.** An `@Observable` `@MainActor` view model owns state; collaborators sit behind protocols.
- **No tests for pure UI views.**

## Sequencing, and why this slice cannot be a clean chain of green builds

Slice 1's tasks were each independently shippable because they only added files. This slice is different: `APIError` and `APIClient` already exist in Gabay under those exact names, so the new ones cannot sit beside the old ones. There is no ordering in which every intermediate commit compiles.

The decomposition below accepts that and minimizes it: each task is a coherent, separately reviewable swap of one layer, and the task that replaces a type also migrates every caller of it in the same commit. **The branch is expected to be non-compiling between Task 1 and Task 8.** Do not "fix" an intermediate state by leaving both types in place.

Task order and why:

1. **Error type.** Everything else references `APIError`, so it goes first.
2. **Request description.** `Endpoint` and friends are leaves that only need `APIError`.
3. **Policy and configuration.** `RetryPolicy` and `APIConfig` need `APIError` and `HTTPMethod`.
4. **The client.** Needs 1 to 3. Migrates `AuthClient`, `EventClient`, `AppDependencies`.
5. **Token storage.** Independent of the client, but the coordinator in Task 6 needs it.
6. **Refresh and the auth interceptor.** Needs 4 and 5. This is where the 401 handling moves.
7. **Logging and pinning.** Additive once the interceptor protocol exists.
8. **Error handling in the UI.** Retires `LoadFailure` and funnels the screens through `APIError`. Last, because it needs the final error type and every earlier caller migrated.

## The `APIError` migration table

Task 1 replaces Gabay's five-case `APIError` with the template's seventeen-case one. Thirteen files reference the old cases. This table is the complete mapping; use it rather than inventing one per site.

| Old | New | Note |
| --- | --- | --- |
| `.badResponse` | `.invalidResponse` | |
| `.unauthorized` | `.unauthorized()` | **The parentheses are required.** The new case is `case unauthorized(message: String? = nil)`. A case with associated values, even all-defaulted, is a constructor function, so bare `.unauthorized` is not a value and will not type-check. |
| `.forbidden` | `.forbidden()` | Same. |
| `.validationFailed` | `.validation(ValidationErrors(fields: [:], summary: nil))` | The new case carries field detail. Tests that only need "a validation failure" pass an empty `fields`. |
| `.server` | `.server(status: 500)` | The new case carries the status. Pick the status the test actually means. |

The old cases live in `Gabay/Core/Networking/APIClient.swift`. The sites to migrate, found by `grep -rn "APIError\." --include="*.swift" Gabay GabayTests`:

`Gabay/Core/Networking/APIClient.swift`, `Gabay/Core/Events/EventsViewModel.swift`, `GabayTests/Support/TestDoubles.swift`, `GabayTests/APIClientTests.swift`, `GabayTests/AuthClientTests.swift`, `GabayTests/EventClientTests.swift`, `GabayTests/EventsViewModelTests.swift`, `GabayTests/PostEventViewModelTests.swift`, `GabayTests/SessionTests.swift`.

Re-run that grep yourself rather than trusting this list; it was taken at plan time.

## What the spec said that planning corrected

The spec states: "Gabay wires `APIClient(tokenProvider: { tokenStore.load() })` as a synchronous closure in `AppDependencies.live()`. That closure, `Session`'s three call sites and the composition root all become async."

**The composition root does not become async.** In the template's architecture the token is read inside `AuthInterceptor.adapt(_:for:)`, which is already `async` and is called by the client mid-request. `AppDependencies.live()` only constructs objects, and `KeychainTokenStore()`, `TokenRefreshCoordinator(...)`, `AuthInterceptor(...)` and `URLSessionAPIClient(...)` all have synchronous initializers. `live()` stays synchronous and `GabayApp` needs no change.

What does change on `Session`: `restore()`, `login(email:password:)` and `register(email:password:)` are already `async`, so their `tokenStore` calls simply gain `await`. Only `signOut()` is synchronous today and must become `async`, along with its call sites. Confirm this against `Gabay/Core/Auth/Session.swift` when you get to Task 5 rather than assuming it.

This is recorded because the spec's version is wrong, not because the spec was vague. If you find a third reading, the code wins.

## Not in this slice

- `SessionPolicyInterceptor`. It depends on the template's `SessionLink` and a `session.show(serviceStatus:)` surface that Gabay has no equivalent of. `.updateRequired` and `.maintenance` still classify correctly and surface as errors; they simply get no special presentation yet.
- `MetadataInterceptor` and `ClientMetadata`. Gabay's backend is unwritten and defines no metadata headers.
- The template's `Core/Networking/JSONCoders.swift`. Gabay already has `Gabay/Core/Networking/APICoders.swift` defining `JSONEncoder.api` and `JSONDecoder.api`. Task 2 reconciles the two rather than porting a second definition; see that task for the specific reason Gabay's must win.
- Repositories. Slice 3.
- `NetworkMonitor`, `OfflineBanner`, Firebase, `Router`. Slice 5.
- The Slice 1 items deferred to Slice 4: `routeSummary` duplication and its "~0h 45m" output, and the missing `startAccessingSecurityScopedResource()` in `pickGPX(at:)`.
- The stale whole-form error message on the three screens. Task 8 addresses it, because Task 8 is where `ActionState` lands; if Task 8 slips, it slips with it.

## File Structure

**Ported verbatim from the template's `main`** (header and em dash edits only, unless a task says otherwise):

| Destination in Gabay | Source on `main` |
| --- | --- |
| `Gabay/Core/Networking/APIError.swift` | `AppTemplate/Core/Networking/APIError.swift` |
| `Gabay/Core/Networking/APIErrorBody.swift` | `AppTemplate/Core/Networking/APIErrorBody.swift` |
| `Gabay/Core/Networking/Endpoint.swift` | `AppTemplate/Core/Networking/Endpoint.swift` |
| `Gabay/Core/Networking/HTTPMethod.swift` | `AppTemplate/Core/Networking/HTTPMethod.swift` |
| `Gabay/Core/Networking/MultipartFormData.swift` | `AppTemplate/Core/Networking/MultipartFormData.swift` |
| `Gabay/Core/Networking/ImageCompression.swift` | `AppTemplate/Core/Networking/ImageCompression.swift` (see Task 2) |
| `Gabay/Core/Networking/UIImage+Upload.swift` | `AppTemplate/Core/Networking/UIImage+Upload.swift` (see Task 2) |
| `Gabay/Core/Networking/RetryPolicy.swift` | `AppTemplate/Core/Networking/RetryPolicy.swift` |
| `Gabay/Core/Networking/APIConfig.swift` | `AppTemplate/Core/Networking/APIConfig.swift` |
| `Gabay/Core/Networking/RequestInterceptor.swift` | `AppTemplate/Core/Networking/RequestInterceptor.swift` |
| `Gabay/Core/Networking/URLSessionAPIClient.swift` | `AppTemplate/Core/Networking/APIClient.swift` (renamed, see Task 4) |
| `Gabay/Core/Networking/Interceptors/AuthInterceptor.swift` | same path (the `SessionPolicyInterceptor` at the bottom is dropped) |
| `Gabay/Core/Networking/Interceptors/LoggingInterceptor.swift` | same path |
| `Gabay/Core/Auth/AuthTokens.swift` | `AppTemplate/Core/Session/AuthTokens.swift` |
| `Gabay/Core/Auth/TokenStore.swift` | `AppTemplate/Core/Storage/TokenStore.swift` (**replaces** Gabay's file of the same name) |
| `Gabay/Core/Auth/TokenRefreshCoordinator.swift` | `AppTemplate/Core/Session/TokenRefreshCoordinator.swift` |
| `Gabay/Core/Security/CertificatePinner.swift` | `AppTemplate/Core/Security/CertificatePinner.swift` |
| `Gabay/Core/UI/ActionState.swift` | `AppTemplate/Core/UI/ActionState.swift` |

**Written for Gabay, not ported:**

| File | Responsibility |
| --- | --- |
| `Gabay/Core/Networking/APIRoute.swift` | Gabay's own paths. The template's routes are for a different product. |

**Deleted:**

| File | Why |
| --- | --- |
| `Gabay/Core/Networking/APIClient.swift` | The old `struct APIClient` and the old `enum APIError`. Task 4 removes it after Task 1 has emptied it of the error type. |
| `Gabay/Core/UI/LoadFailure.swift` | Task 8. `APIError` becomes the single classification point. |

**Modified:** `Gabay/Core/Auth/AuthClient.swift`, `Gabay/Core/Auth/Session.swift`, `Gabay/Core/Events/EventClient.swift`, `Gabay/Core/Events/EventsViewModel.swift`, `Gabay/Core/Events/PostEventViewModel.swift`, `Gabay/Core/UI/LoadState.swift`, `Gabay/Core/UI/ErrorStateView.swift`, `Gabay/Core/AppConfig.swift`, `Gabay/App/AppDependencies.swift`, `Gabay/Features/Auth/SignInView.swift`, `Gabay/Features/Auth/SignUpView.swift`, `Gabay/Features/Events/EventDetailView.swift`, `Gabay/Features/Events/MyEventsView.swift`, `Config/Development.xcconfig`, `Config/Staging.xcconfig`, `Config/Production.xcconfig`, `Config/Info.plist`, and the test files named per task.

---

### Task 1: Swap the error type

Replaces Gabay's five-case `APIError` with the template's, and migrates every reference in the same commit. Nothing compiles until the migration is complete, so treat the migration as part of the deliverable rather than follow-up.

**Files:**
- Create: `Gabay/Core/Networking/APIError.swift`, `Gabay/Core/Networking/APIErrorBody.swift`
- Modify: `Gabay/Core/Networking/APIClient.swift` (remove its `enum APIError`, repoint its status mapping)
- Modify: `Gabay/Core/Events/EventsViewModel.swift` and every test file the migration table names
- Test: `GabayTests/APIErrorTests.swift` (create)

**Interfaces produced,** relied on by every later task: `APIError` with the cases `offline`, `timedOut`, `cancelled`, `transport(detail:)`, `serverTrustFailed`, `invalidURL`, `invalidResponse`, `decodingFailed(detail:)`, `unauthorized(message:)`, `forbidden(message:)`, `notFound(message:)`, `conflict(message:)`, `validation(ValidationErrors)`, `rateLimited(retryAfter:message:)`, `updateRequired(message:)`, `maintenance(message:)`, `server(status:message:)`; the properties `isRetryable`, `invalidatesSession`, `validationErrors`, `isUserFacing`, `analyticsReason`, `isWorthReporting`; and the statics `from(transportError:)`, `from(statusCode:data:headers:)` and `@MainActor classify(_:)`. Plus `ValidationErrors` with `fields`, `summary`, `first(for:)` and `allMessages`.

- [ ] **Step 1: Port the two files**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/Networking/APIError.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/APIError.swift
git show main:AppTemplate/Core/Networking/APIErrorBody.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/APIErrorBody.swift
```

Fix the headers, then remove the em dash on `APIError.swift` line 194. Confirm with `grep -n "$(printf '\xe2\x80\x94')"` on both files that nothing remains.

- [ ] **Step 2: Check what `APIError.classify` depends on**

The ported `classify(_:)` is `@MainActor` and calls `Breadcrumb.record(_:)` and `Observability.crashes.record(_:)`. Gabay has `Gabay/Core/Observability/Breadcrumb.swift` and `Gabay/Core/Observability/Observability.swift`. Read both and confirm those two call shapes exist. If either differs, report it rather than adapting the ported file on your own judgment; the adaptation changes what gets reported to crash reporting, which is a decision, not a detail.

- [ ] **Step 3: Remove the old error type and repoint the old client**

In `Gabay/Core/Networking/APIClient.swift`, delete `enum APIError` entirely. That file's `send`/`sendRaw` currently map status codes to the old cases by hand. Replace that mapping with a single call to `APIError.from(statusCode:data:headers:)`, passing the response's `allHeaderFields`. The old client keeps working; it is deleted in Task 4.

- [ ] **Step 4: Migrate every reference**

Run `grep -rn "APIError\." --include="*.swift" Gabay GabayTests` and apply the migration table from the Global section above. **The parenthesised forms matter:** `.unauthorized` becomes `.unauthorized()`, `.forbidden` becomes `.forbidden()`. A case with all-defaulted associated values is a constructor function, not a value.

`Gabay/Core/Events/EventsViewModel.swift` has three `catch APIError.unauthorized` clauses. A pattern match on a case with associated values is written `catch APIError.unauthorized` still, without parentheses, because that is a pattern rather than a value. Do not add parentheses there. Leave the `throw CancellationError()` on line 60 alone for now; Task 6 removes it along with the rest of the 401 handling.

- [ ] **Step 5: Write tests for the parts with logic**

Create `GabayTests/APIErrorTests.swift`. `APIError` is mostly data, so test only the parts that decide something:

- `from(statusCode:data:headers:)` maps 401, 403, 404, 409, 422, 426, 429, 503 and an unlisted status to the right cases.
- 400 maps to `.validation` when the body carries field errors and to `.server` when it does not. This branch is easy to get wrong and is worth pinning.
- 429 reads `Retry-After` out of the headers, and tolerates the header being absent or unparseable.
- `from(transportError:)` maps `URLError.notConnectedToInternet` to `.offline`, `.timedOut` to `.timedOut`, `.cancelled` to `.cancelled`, a certificate error to `.serverTrustFailed`, and `CancellationError` to `.cancelled`.
- `isRetryable` is true for `.offline`, `.timedOut`, `.transport`, `.rateLimited` and a 5xx `.server`, and false for `.unauthorized()`, `.validation` and a 4xx `.server`.
- `validationErrors` returns the payload for `.validation` and nil otherwise.

Do not test `errorDescription` string contents; that asserts copy, not behavior. Do not test `classify(_:)`, which is `@MainActor` and reaches into Observability; note in your report that it is untested and why.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Networking Gabay/Core/Events/EventsViewModel.swift GabayTests
git commit -m "Replace the API error type with the template's"
```

---

### Task 2: Request description

**Files:**
- Create: `Gabay/Core/Networking/Endpoint.swift`, `Gabay/Core/Networking/HTTPMethod.swift`, `Gabay/Core/Networking/MultipartFormData.swift`
- Modify: `Gabay/Core/Networking/APICoders.swift` only if Step 2 finds a real mismatch
- Test: `GabayTests/EndpointTests.swift` (create)

**Interfaces produced:** `HTTPMethod` with `isIdempotent`; `HTTPBody` with `.data(_:contentType:)`, `.json(_:)` and `.multipart(_:)`; `Endpoint(_:method:query:headers:body:requiresAuth:timeout:)` with `urlRequest(baseURL:defaultTimeout:)` and the static helpers `get`, `post`, `put`, `patch`, `delete`, `upload`; `MultipartFormData`.

- [ ] **Step 1: Port the three files**

```bash
cd /Users/patrick/Projects/AppTemplate
for f in Endpoint HTTPMethod MultipartFormData; do
  git show main:AppTemplate/Core/Networking/$f.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/$f.swift
done
```

Fix headers. None of these three contained an em dash at plan time; re-check anyway.

**Reversed during execution.** The template's `MultipartFormData` carries an `addImage(_:name:filename:compression:)` helper depending on `ImageCompression` and a `UIImage` extension, neither of which this plan originally listed. That omission was first handled by deleting the helper, on the grounds that Gabay uploads no images. The user then confirmed photo upload is planned, so the decision was reversed: `ImageCompression.swift` and `UIImage+Upload.swift` are ported alongside, from the same `main` branch and into the same directory, and `MultipartFormData` is left byte-identical to the template apart from its header. The helper has no caller yet and that is expected; it is groundwork for a photo upload flow, in the same spirit as Slice 5 taking the Firebase dependency ahead of the push work.

- [ ] **Step 2: Reconcile the JSON coders, do not port a second pair**

`HTTPBody.json(_:)` calls `JSONEncoder.api`. The template defines `JSONEncoder.api` and `JSONDecoder.api` in `Core/Networking/JSONCoders.swift`. **Gabay already defines both**, in `Gabay/Core/Networking/APICoders.swift`. Porting the template's file would be a redeclaration and would not compile.

**Gabay's version wins.** Read both and confirm the reason still holds: Gabay's deliberately does not apply `convertFromSnakeCase`, because Gabay's `Event` has a `feePHP` property whose name snake-case conversion would mangle. Gabay's also uses a tolerant ISO8601 strategy that accepts a plain stamp, fractional seconds and an offset, which the events API needs.

Do not port the template's file. If reading the two shows Gabay's is missing something `Endpoint` or `URLSessionAPIClient` actually relies on, add that one thing to `APICoders.swift` and say what and why in your report. Do not "align" Gabay's coders with the template's beyond that.

- [ ] **Step 3: Test `Endpoint.urlRequest(baseURL:defaultTimeout:)`**

This is the one piece with real logic. Create `GabayTests/EndpointTests.swift` covering:

- A path joins onto the base URL correctly, including when the base URL has a trailing slash and when the path has a leading one. The implementation splits on `/` and appends components, so both should produce the same URL; pin that.
- Query items appear in the composed URL, and an empty query array leaves the URL untouched.
- The method, the `Accept: application/json` header, and custom headers are all set.
- A JSON body sets both `httpBody` and `Content-Type: application/json`.
- `timeout` overrides the default when set and falls back when nil.
- `HTTPMethod.isIdempotent` is true for get, put and delete, false for post and patch.

- [ ] **Step 4: Commit**

```bash
git add Gabay/Core/Networking GabayTests/EndpointTests.swift
git commit -m "Add the endpoint and multipart request types"
```

---

### Task 3: Retry policy, configuration and the interceptor protocol

**Files:**
- Create: `Gabay/Core/Networking/RetryPolicy.swift`, `Gabay/Core/Networking/APIConfig.swift`, `Gabay/Core/Networking/RequestInterceptor.swift`
- Modify: `Gabay/Core/AppConfig.swift`
- Test: `GabayTests/RetryPolicyTests.swift` (create)

**Interfaces produced:** `RetryPolicy(maxAttempts:baseDelay:maxDelay:jitter:)` with `.none`, `.standard`, `shouldRetry(_:attempt:method:sentBody:)` and `delay(afterAttempt:error:)`; `APIConfig` with `baseURL`, `timeout`, `maxAttempts`, `isLoggingEnabled`, `isCertificatePinningEnabled`, `pinnedPublicKeyHashes`, `updateURL`, `retryPolicy`; `RequestInterceptor` with defaulted `adapt`, `didReceive` and `handle`, and `InterceptorDecision` with `.proceed`, `.retry`, `.fail(APIError)`.

- [ ] **Step 1: Port the three files**

```bash
cd /Users/patrick/Projects/AppTemplate
for f in RetryPolicy APIConfig RequestInterceptor; do
  git show main:AppTemplate/Core/Networking/$f.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/$f.swift
done
```

Fix headers. Remove the three em dashes in `APIConfig.swift` (lines 16, 30, 52 on `main`).

- [ ] **Step 2: Trim `APIConfig` to what Gabay has**

The ported `APIConfig` reads two keys Gabay has no use for in this slice: `APP_URL_SCHEME` (`urlScheme`, for deep links, which is Slice 5) and `ENV_BANNER_ENABLED` (`isEnvironmentBannerEnabled`, for the template's `EnvironmentRibbon`, which Gabay does not have). Delete both properties rather than adding dead keys to three xcconfigs. Keep `isForceUpdateEnabled` and `updateURL`, because Gabay's xcconfigs already define `FORCE_UPDATE_ENABLED` and `UPDATE_URL`.

- [ ] **Step 3: Reconcile with `AppConfig`**

`Gabay/Core/AppConfig.swift` already has an `apiBaseURL` property reading the same `API_BASE_URL` key. Two types reading one key is exactly the duplication this slice is meant to remove.

Read `AppConfig.swift`. Delete its `apiBaseURL` and repoint every caller at `APIConfig.baseURL`. If `AppConfig` has no other members left, delete the file. If it does, leave the rest alone. Report which way it went.

- [ ] **Step 4: Test `RetryPolicy`**

Create `GabayTests/RetryPolicyTests.swift`. The logic worth pinning:

- `shouldRetry` is false once `attempt` reaches `maxAttempts`, and false for a non-retryable error regardless of attempt.
- An idempotent method retries; a POST that already sent a body does not, **except** when the error is `.offline`, where it does. That exception is the subtle one; test both halves.
- `delay(afterAttempt:error:)` honors `Retry-After` when `.rateLimited` carries a positive one, and caps it at `maxDelay`.
- Backoff grows with the attempt number and never exceeds `maxDelay`. Jitter makes the exact value nondeterministic, so assert bounds rather than an exact `Duration`. Construct the policy with a degenerate jitter range such as `1.0...1.0` where you need an exact value, rather than asserting on randomness.
- `RetryPolicy(maxAttempts: 0)` clamps to 1 rather than looping forever.

- [ ] **Step 5: Commit**

```bash
git add Gabay/Core/Networking Gabay/Core/AppConfig.swift GabayTests/RetryPolicyTests.swift
git commit -m "Add the retry policy, API config and interceptor protocol"
```

---

### Task 4: The client swap

Replaces `struct APIClient` with the `APIClient` protocol and `URLSessionAPIClient`, and migrates all three callers in the same commit.

**Files:**
- Create: `Gabay/Core/Networking/URLSessionAPIClient.swift`, `Gabay/Core/Networking/APIRoute.swift`
- Delete: `Gabay/Core/Networking/APIClient.swift`
- Modify: `Gabay/Core/Auth/AuthClient.swift`, `Gabay/Core/Events/EventClient.swift`, `Gabay/App/AppDependencies.swift`
- Modify: `GabayTests/APIClientTests.swift`, `GabayTests/AuthClientTests.swift`, `GabayTests/EventClientTests.swift`

**Interfaces produced:** `protocol APIClient: Sendable` with `send<T>(_:as:)`, plus the extension methods `send<T>(_:)`, `send(_:)`, `get<T>(_:query:requiresAuth:)`, `post<T>(_:body:requiresAuth:)`, `post(_:body:requiresAuth:)`, `put<T>`, `patch<T>`, `delete`, `upload<T>(_:form:method:requiresAuth:)`; `struct EmptyResponse`; `nonisolated final class URLSessionAPIClient(baseURL:session:interceptors:retryPolicy:defaultTimeout:)`.

- [ ] **Step 1: Port the client**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/Networking/APIClient.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/URLSessionAPIClient.swift
```

Fix the header. Remove the em dash on line 266. The destination filename differs from the source on purpose: the file's principal type is `URLSessionAPIClient`, and Gabay's old `APIClient.swift` is being deleted in this same task, so reusing that basename would obscure the swap in review.

Keep `nonisolated final class URLSessionAPIClient` and the `OSAllocatedUnfairLock`-backed `DataTaskBox` exactly as they are. They are the file's answer to Swift 6 isolation and to distinguishing a caller cancellation from a pinning rejection; changing either is a design decision, not a port.

- [ ] **Step 2: Delete the old client**

```bash
git rm Gabay/Core/Networking/APIClient.swift
```

Task 1 already removed the `enum APIError` from it, so what is being deleted is `struct APIClient` and its private `makeRequest`/`send`/`sendRaw`/`postMultipart` helpers.

- [ ] **Step 3: Write Gabay's routes**

Create `Gabay/Core/Networking/APIRoute.swift`. Do not port the template's; its routes belong to a different product. Gabay's paths, taken from the events-platform spec and the spec's auth amendment:

```swift
//
//  APIRoute.swift
//  Gabay
//

import Foundation

enum APIRoute {

    enum Auth {
        static let register = "auth/register"
        static let login = "auth/login"
        static let refresh = "auth/refresh"
        static let currentUser = "me"
    }

    enum Events {
        static let list = "events"
        static let mine = "me/events"
        static func detail(_ id: String) -> String { "events/\(id)" }
        static func gpx(_ id: String) -> String { "events/\(id)/gpx" }
        static func join(_ id: String) -> String { "events/\(id)/join" }
    }
}
```

Note `currentUser` is `me`, not `auth/me`. That is what the spec's contract says and what Gabay's `AuthClient.me()` calls today.

- [ ] **Step 4: Migrate `AuthClient`**

Change `private let api: APIClient` to `private let api: any APIClient`, and the initializer parameter with it. The template's protocol extension provides `get(_:query:requiresAuth:)` and `post(_:body:requiresAuth:)` with the same shapes Gabay already calls, so the bodies barely change. Two things do:

- **`register` and `login` must pass `requiresAuth: false`.** The extension defaults it to `true`, which would make the auth interceptor attach a token to the two endpoints that exist to obtain one, and in Task 6 would make a 401 from a bad password trigger a refresh attempt.
- Replace the string literals with `APIRoute.Auth.register`, `.login` and `.currentUser`.

Leave `AuthResult` alone in this task. Task 5 changes its shape when `AuthTokens` lands.

- [ ] **Step 5: Migrate `EventClient`**

Change `private let api: APIClient` to `any APIClient` and swap the literals for `APIRoute.Events` members. Three call sites need more than that:

- `join(_:)` currently calls `api.post("events/\(id)/join")`, a POST with no body. The protocol extension's `post` requires a body. Use the endpoint form instead:

  ```swift
  func join(_ id: String) async throws {
      try await api.send(Endpoint(APIRoute.Events.join(id), method: .post))
  }
  ```

- `uploadGPX(...)` currently calls the old client's `postMultipart`. Rebuild it on `MultipartFormData` and `api.upload`. The form type's API is `addField(_:value:)` and `addFile(_:filename:mimeType:data:)`, and `Endpoint.upload` already sets a 120 second timeout, which is why the old hand-rolled timeout is no longer needed. Read the current implementation for the exact field names it sends and preserve every one of them; the backend contract has not changed here.

  One thing to fix while you are in there, because it is a defect in the code being replaced rather than a new behavior: the old implementation interpolated the filename into the `Content-Disposition` header without escaping. `addFile` has the same shape, so pass a filename you control rather than the user's raw filename. Use the event id plus `.gpx`. Say so in your report.

- `event(id:)` has no production caller. Leave it for now; Slice 3 removes it along with the rest of the `EventFetching` split.

- [ ] **Step 6: Rewire the composition root**

In `AppDependencies.live()`, replace `APIClient(base:tokenProvider:)` with `URLSessionAPIClient(baseURL: APIConfig.baseURL)`. Pass no interceptors yet; Task 6 adds them. The `tokenStore` local stays where it is for now and Task 5 replaces it.

`live()` stays synchronous. The token read moves into the interceptor in Task 6, so nothing here becomes `async`, and `GabayApp` needs no change.

- [ ] **Step 7: Migrate the tests**

`GabayTests/APIClientTests.swift` tests the deleted struct through `StubURLProtocol`. Rewrite it against `URLSessionAPIClient` constructed with a `URLSession` whose configuration registers `StubURLProtocol`, which is how it already works. Keep the existing cases: a GET decodes, a POST sends a body and decodes, a bodiless POST ignores the response, and each status maps to the right `APIError`. Add one for the new behavior: a 2xx with an empty body decodes as `EmptyResponse` rather than throwing.

`AuthClientTests` and `EventClientTests` construct the old struct. Point them at `URLSessionAPIClient` the same way.

Do not rewrite these suites onto a hand-written stub client in this task. Slice 3 introduces repositories and that is where the stubbing seam moves. Changing it twice is wasted work.

- [ ] **Step 8: Commit**

```bash
git add -u && git add Gabay/Core/Networking
git commit -m "Replace the API client with the template's URLSession client"
```

---

### Task 5: Token storage

**Files:**
- Create: `Gabay/Core/Auth/AuthTokens.swift`
- Replace: `Gabay/Core/Auth/TokenStore.swift` (contents entirely; the path stays)
- Modify: `Gabay/Core/Auth/Session.swift`, `Gabay/Core/Auth/AuthClient.swift`, `Gabay/App/AppDependencies.swift`, `Gabay/Features/Events/EventsListView.swift` and any other `signOut()` caller
- Modify: `GabayTests/Support/TestDoubles.swift`, `GabayTests/TokenStoreTests.swift`, `GabayTests/SessionTests.swift`

**Interfaces produced:** `AuthTokens(accessToken:refreshToken:expiresAt:)` with `isExpired`, `needsProactiveRefresh`, `canRefresh`; `protocol TokenStore: Sendable` with `load() async -> AuthTokens?`, `save(_:) async throws`, `clear() async`; `actor KeychainTokenStore(service:)`; `actor InMemoryTokenStore(tokens:)`; `enum KeychainError`.

- [ ] **Step 1: Port both files**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/Session/AuthTokens.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Auth/AuthTokens.swift
git show main:AppTemplate/Core/Storage/TokenStore.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Auth/TokenStore.swift
```

The second command **overwrites** Gabay's existing `TokenStore.swift`, which is intended. Gabay's old file declared `protocol TokenStoring`, `struct TokenStore` and `enum TokenStoreError`, all of which are replaced. Writing the port to a new path instead would leave two files named `TokenStore.swift` in one target, which risks an object-file collision, and would leave two types competing for the name `TokenStore`.

Fix headers. Neither file contained an em dash at plan time; check anyway.

- [ ] **Step 2: Note what changes about the Keychain**

Two behavior changes worth stating in your report, because they are the point of the task:

- The new store sets `kSecAttrAccessible` to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Gabay's old store set no accessibility attribute at all, which means the default, which syncs to a backup. This is the security fix.
- The new store caches the decoded tokens in the actor, so a request no longer pays a Keychain read every time. The old store hit the Keychain synchronously on the main actor for every request.

The ported `KeychainTokenStore.init` calls `preconditionFailure` when `Bundle.main.bundleIdentifier` is nil. That is a deliberate trap in the template, with a comment explaining that a literal fallback would let two apps share one keychain entry. Keep it and keep the comment. It is the one `preconditionFailure` this slice's constraint on crash paths tolerates, because the alternative is silent cross-app credential sharing.

- [ ] **Step 3: Change the auth contract to carry tokens**

In `AuthClient.swift`, `AuthResult` currently is `{ token: String, role: AccountRole }`. The spec's amendment makes the endpoints return `{ accessToken, refreshToken, expiresAt, role }`. Redefine it:

```swift
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

`expiresAt` decodes through `JSONDecoder.api`, whose tolerant ISO8601 strategy already handles the plain, fractional and offset forms. Do not add a custom date strategy for it.

- [ ] **Step 4: Migrate `Session`**

`Session` holds `any TokenStoring`; change it to `any TokenStore`. Then:

- `restore()`: `tokenStore.load()` becomes `await tokenStore.load()`, and the guard tests for a non-nil `AuthTokens` rather than a `String`. The `tokenStore.clear()` in its catch becomes `await tokenStore.clear()`.
- `login` and `register`: `try tokenStore.save(result.token)` becomes `try await tokenStore.save(result.tokens)`.
- `signOut()` calls `clear()`, which is now `async`, so `signOut()` becomes `async`. Find its callers with `grep -rn "signOut()" --include="*.swift" Gabay GabayTests` and add `await`. `EventsViewModel` calls it from three `catch` blocks that are already in `async` functions, so those just gain `await`.

All three of `restore`, `login` and `register` are already `async`, so nothing above changes a signature except `signOut()`.

- [ ] **Step 5: Migrate the doubles and tests**

`GabayTests/Support/TestDoubles.swift` has a `StubTokenStore` conforming to the old `TokenStoring`. The template ships `InMemoryTokenStore`, an actor conforming to the new protocol, and Task 5 ports it. Delete `StubTokenStore` and use `InMemoryTokenStore` everywhere it was used, rather than keeping a second in-memory store.

That changes every call site: `tokenStore.saved` becomes `await tokenStore.load()`, and `try tokenStore.save("abc123")` becomes `try await tokenStore.save(AuthTokens(accessToken: "abc123"))`. `SignInViewModelTests`, `SignUpViewModelTests` and `SessionTests` all construct one.

`GabayTests/TokenStoreTests.swift` tests the old struct against the real Keychain. Rewrite it against `KeychainTokenStore` with a per-test unique `service` string so runs do not collide, which is what the `service` parameter exists for. Cover: a save then load round-trips; load with nothing stored returns nil; clear removes it; a second save overwrites rather than duplicating; and the in-actor cache returns the saved value without a second Keychain read.

Add tests for `AuthTokens` itself, which has real logic: `isExpired` is false when `expiresAt` is nil, true when it is in the past, false when future; `needsProactiveRefresh` is true inside the 60 second window and false outside it; `canRefresh` is false for a nil and for an empty refresh token.

- [ ] **Step 6: Update the composition root**

`AppDependencies.live()` constructs `TokenStore()`. Change it to `KeychainTokenStore()`. It stays synchronous.

- [ ] **Step 7: Commit**

```bash
git add -u && git add Gabay/Core/Auth
git commit -m "Store auth tokens in an actor-isolated keychain store"
```

---

### Task 6: Refresh and the auth interceptor

Where the 401 handling moves out of the view model. This task has the most Gabay-specific adaptation in the slice; it is not a clean port.

**Files:**
- Create: `Gabay/Core/Auth/TokenRefreshCoordinator.swift`, `Gabay/Core/Auth/SessionLink.swift`, `Gabay/Core/Networking/Interceptors/AuthInterceptor.swift`
- Modify: `Gabay/Core/Auth/AuthClient.swift`, `Gabay/Core/Events/EventsViewModel.swift`, `Gabay/App/AppDependencies.swift`
- Test: `GabayTests/TokenRefreshCoordinatorTests.swift` (create), `GabayTests/EventsViewModelTests.swift`

- [ ] **Step 1: Port, then adapt, the coordinator**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/Session/TokenRefreshCoordinator.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Auth/TokenRefreshCoordinator.swift
git show main:AppTemplate/Core/Session/SessionLink.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Auth/SessionLink.swift
```

Fix headers and remove the two em dashes in the coordinator (lines 50 and 74 on `main`). Then make these adaptations, which are required because the template's surrounding types do not exist in Gabay:

- `SessionLink` holds `weak var session: SessionManager?`. Gabay's type is `Session`. Change it and keep the file's comment, which explains why the reference is weak: `Session` owns `AuthClient`, which owns the client, which owns the interceptor, which owns the coordinator. A strong reference back would be a cycle.
- `TokenRefreshCoordinator.invalidate()` calls `await link.session?.expire()`. Gabay's `Session` has `signOut()`, which after Task 5 is `async` and does the same job. Call that instead. Do not add an `expire()` alias.
- `LiveTokenRefresher.refresh(using:)` decodes an `AuthResponse` that lives in the template's `Data/AuthRepository.swift`, which is Slice 3 and not ported.

  **This plan originally said to use `AuthResult` here. That was wrong and it was caught in Task 6's review.** `AuthResult` carries a non-optional `role`, because `/auth/register` and `/auth/login` return one. `/auth/refresh` does not, per this spec's own contract. Decoding `AuthResult` from a refresh response therefore fails with `keyNotFound: role`, which becomes `APIError.decodingFailed`, which the coordinator treats as a failed refresh, which clears the Keychain and signs the user out. Every single refresh would have ended in a sign-out, which is exactly the behaviour this task exists to remove, reinstated one layer down. No coordinator test caught it because they all stub `TokenRefreshing` and nothing constructs `LiveTokenRefresher`.

  Define a `private struct RefreshResponse` beside `RefreshRequest` instead, matching the contract exactly: `accessToken`, optional `refreshToken`, optional `expiresAt`, and a `tokens` property. Do not make `AuthResult.role` optional to accommodate this; that would weaken the type for the two endpoints that genuinely return a role. The request body is `RefreshRequest(refreshToken:)`, which does not exist in Gabay either; define it as a small `private struct` in this file.

  The call keeps `requiresAuth: false`, which matters: refreshing must not go through the interceptor that is asking for the refresh.

- [ ] **Step 2: Port the auth interceptor, without the session policy one**

```bash
git show main:AppTemplate/Core/Networking/Interceptors/AuthInterceptor.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/Interceptors/AuthInterceptor.swift
```

Fix the header and remove the em dash on line 44. **Delete the `SessionPolicyInterceptor` declaration at the bottom of the file.** It depends on `link.session?.show(serviceStatus:)`, which Gabay has no equivalent of. `.updateRequired` and `.maintenance` still classify correctly and reach the caller as errors; they simply get no special presentation in this slice.

- [ ] **Step 3: Remove the 401 workaround from `EventsViewModel`**

`EventsViewModel` has three `catch APIError.unauthorized` blocks that call `session.signOut()`, and one of them throws a `CancellationError` afterwards. That throw is the defect the architecture audit recorded: `CancellationError` is treated as "the app cancelled this on purpose", so the list stays in `.idle` behind a spinner that can never reload.

With the interceptor in place, a 401 is handled one layer down: the interceptor refreshes and retries once, and only a genuinely failed refresh reaches the caller, by which point the coordinator has already signed the session out. Delete all three `catch APIError.unauthorized` blocks and the `throw CancellationError()`. Let the error land in whatever generic failure branch each method already has, so the list ends in `.failed` with a retry available rather than a permanent spinner.

Update `EventsViewModelTests` accordingly. The existing test that feeds `APIError.unauthorized()` and asserts a sign-out is now asserting behavior that belongs to the coordinator; move that assertion to the coordinator's own tests and replace it here with one asserting the list reaches `.failed` and can be reloaded.

- [ ] **Step 4: Wire the chain in the composition root**

In `AppDependencies.live()`, build in this order, which is forced by the dependency graph:

1. `let tokenStore = KeychainTokenStore()`
2. `let sessionLink = SessionLink()`
3. A bare `URLSessionAPIClient` with no interceptors, used **only** by `LiveTokenRefresher`. The refresher must not go through the auth interceptor, or a failing refresh would recurse into itself.
4. `let coordinator = TokenRefreshCoordinator(store: tokenStore, refresher: LiveTokenRefresher(api: refreshClient), link: sessionLink)`
5. The real `URLSessionAPIClient` with `interceptors: [AuthInterceptor(coordinator: coordinator)]`
6. `Session`, then `sessionLink.session = session`

Step 3 is the part that is easy to get wrong and impossible to catch without running it. Say in your report that you did it and why.

- [ ] **Step 5: Test the coordinator**

Create `GabayTests/TokenRefreshCoordinatorTests.swift`. This is the highest-value test file in the slice, because single-flighting is exactly the kind of thing that looks right and is not. Cover:

- A refresh with no stored tokens throws `.unauthorized()`.
- A refresh with stored tokens but no refresh token throws `.unauthorized()` and invalidates.
- A successful refresh saves the renewed tokens to the store and returns them.
- **Concurrent refreshes single-flight.** Start several `refresh(staleAccessToken:)` calls at once against a refresher that counts its calls, and assert the count is exactly one while every caller receives the renewed tokens. Use a refresher whose `refresh` suspends until the test releases it, so the calls genuinely overlap rather than completing one at a time. A test that does not force overlap does not test single-flighting.
- **The stale-token short circuit.** When the stored access token already differs from the `staleAccessToken` passed in, the coordinator returns the stored tokens without calling the refresher at all. Assert the refresher was not called.
- A failed refresh invalidates the session and throws `.unauthorized()`, and a cancelled one throws `.cancelled` **without** invalidating. That difference matters: a cancelled request must not sign the user out.

- [ ] **Step 6: Commit**

```bash
git add -u && git add Gabay/Core/Auth Gabay/Core/Networking/Interceptors GabayTests
git commit -m "Refresh tokens in an interceptor instead of signing out on every 401"
```

---

### Task 7: Logging and certificate pinning

Both are inert by default. This task is small and additive.

**Files:**
- Create: `Gabay/Core/Networking/Interceptors/LoggingInterceptor.swift`, `Gabay/Core/Security/CertificatePinner.swift`
- Modify: `Gabay/App/AppDependencies.swift`, `Config/Development.xcconfig`, `Config/Staging.xcconfig`, `Config/Production.xcconfig`, `Config/Info.plist`

- [ ] **Step 1: Port both files**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/Networking/Interceptors/LoggingInterceptor.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Networking/Interceptors/LoggingInterceptor.swift
git show main:AppTemplate/Core/Security/CertificatePinner.swift > /Users/patrick/Projects/Gabay/Gabay/Core/Security/CertificatePinner.swift
```

Fix headers. Remove the three em dashes in `CertificatePinner.swift` (lines 45, 73, 86 on `main`).

- [ ] **Step 2: Add the config keys that are already commented for**

`APIConfig` reads `API_TIMEOUT_SECONDS`, `API_MAX_RETRIES` and `API_LOGGING_ENABLED`. None of the three xcconfigs define them.

`Config/Staging.xcconfig` and `Config/Production.xcconfig` already carry orphan comments for exactly these, left behind by an earlier task: "Seconds before a request gives up", "Retries for flaky connections" and a note that logging must stay off because it leaks user data to the device console. Add each key directly under the comment that describes it, rather than appending a new block. `Config/Development.xcconfig` has no such comments; add the keys with comments in the same voice as its neighbours.

Values: a 30 second timeout everywhere; 2 retries in Development and Staging and 2 in Production; logging `YES` in Development only and `NO` in Staging and Production. `CERT_PINNING_ENABLED` and `PINNED_PUBLIC_KEY_HASHES` already exist in all three and stay exactly as they are, pinning off and hashes blank.

**The `Info.plist` gap is larger than three keys, and Task 3's review found it.** `Config/Info.plist` currently bridges exactly one key, `API_BASE_URL`. `APIConfig` reads eight. An xcconfig value that is not surfaced in `Info.plist` never reaches `Bundle.main.object(forInfoDictionaryKey:)`, so it silently returns the default.

Add all seven missing keys to `Config/Info.plist` as `$(KEY)` entries, matching how `API_BASE_URL` is already declared there:

| Key | Already in the xcconfigs? |
| --- | --- |
| `API_TIMEOUT_SECONDS` | no, add it in Step 2 |
| `API_MAX_RETRIES` | no, add it in Step 2 |
| `API_LOGGING_ENABLED` | no, add it in Step 2 |
| `CERT_PINNING_ENABLED` | yes, in all three |
| `PINNED_PUBLIC_KEY_HASHES` | yes, in all three |
| `FORCE_UPDATE_ENABLED` | yes, in all three |
| `UPDATE_URL` | yes, in all three |

The last four were added to the xcconfigs by earlier events-platform work as scaffolding and have never been readable from code, which is why nothing noticed. Their defaults are all benign (pinning off, force update off, no update URL), so this is inert rather than dangerous, but leaving it half-wired would mean `CERT_PINNING_ENABLED = YES` silently doing nothing the day someone sets it.

Verify the result rather than assuming: after editing, every key `APIConfig` reads should appear in `Info.plist`. Cross-check them.

- [ ] **Step 3: Wire both into the composition root, behind their flags**

Append `LoggingInterceptor()` to the interceptor array only when `APIConfig.isLoggingEnabled`. Order matters: it must come after `AuthInterceptor` so that what it logs is the request as actually sent. Confirm the ported interceptor redacts the `Authorization` header before you rely on that; if it does not, stop and report rather than logging bearer tokens to the console.

`CertificatePinner` is a `URLSessionDelegate`. Construct the `URLSession` with it as the delegate and hand that session to `URLSessionAPIClient`. With `CERT_PINNING_ENABLED = NO` the pinner returns no pinned hashes and falls back to default TLS trust, so this is inert until someone supplies real SPKI hashes. The client's `data(for:)` already routes through the session delegate specifically so pinning challenges reach the pinner; that is why it uses a continuation rather than the async `URLSession.data(for:)`.

- [ ] **Step 4: No new tests**

`LoggingInterceptor` writes to the unified log and returns its input unchanged; `CertificatePinner` is inert without hashes and its live path needs a real TLS handshake. Neither has testable behavior in this configuration. Say so explicitly in your report rather than adding a test that asserts a passthrough.

- [ ] **Step 5: Commit**

```bash
git add -u && git add Gabay/Core/Networking/Interceptors Gabay/Core/Security
git commit -m "Add request logging and inert certificate pinning"
```

---

### Task 8: Error handling in the UI

The last task. Retires `LoadFailure` so `APIError` is the single classification point, and brings `ActionState` in so the screens stop hand-rolling their in-flight and failure state.

**Files:**
- Create: `Gabay/Core/UI/ActionState.swift`
- Delete: `Gabay/Core/UI/LoadFailure.swift`
- Modify: `Gabay/Core/UI/LoadState.swift`, `Gabay/Core/UI/ErrorStateView.swift`, `Gabay/Core/Events/EventsViewModel.swift`, `Gabay/Core/Events/PostEventViewModel.swift`, `Gabay/Features/Auth/SignInView.swift`, `Gabay/Features/Auth/SignUpView.swift`, `Gabay/Features/Events/EventDetailView.swift`, `Gabay/Features/Events/MyEventsView.swift`
- Modify: every test asserting on `LoadFailure`

- [ ] **Step 1: Port `ActionState`**

```bash
cd /Users/patrick/Projects/AppTemplate
git show main:AppTemplate/Core/UI/ActionState.swift > /Users/patrick/Projects/Gabay/Gabay/Core/UI/ActionState.swift
```

Fix the header. Read it before using it: it owns an in-flight flag, the last error, and `message(for:)`, which reads a per-field message out of `APIError.validationErrors`. That last part is what closes the spec's "server-supplied per-field validation messages" gap, which Slice 1 explicitly deferred to this slice.

- [ ] **Step 2: Retire `LoadFailure`**

`LoadState.failed` carries a `LoadFailure`; change it to carry an `APIError`, and change `LoadState.error` with it. `LoadFailure.classify(_:)` is replaced by `APIError.classify(_:)`, which is `@MainActor` and additionally records a breadcrumb and reports the errors worth reporting.

`ErrorStateView` switches over `LoadFailure` for its title, message and icon. Rewrite it over `APIError`. Use the ported `errorDescription` for the message rather than writing a second set of strings, since `APIError` already localizes every case. Keep a short switch for the title and icon, and map `.offline`, `.timedOut`, `.maintenance` and `.updateRequired` to their own icons, everything else to a generic one. `LoadFailure.isRetryable` becomes `APIError.isRetryable`; note that the two are not the same predicate, so read the ported one before wiring the retry button.

Then `git rm Gabay/Core/UI/LoadFailure.swift` and fix what breaks.

- [ ] **Step 3: Migrate the three screens' error state**

`SignInViewModel`, `SignUpViewModel` and `PostEventViewModel` each hold a `private(set) var failure: LoadFailure?` plus a hand-rolled in-flight flag, and each derives a fixed message string from it. Replace each with an `ActionState` and derive the message from the error rather than from a constant.

This is also where the stale-message defect from Slice 1's final review gets fixed, and it is the reason it was deferred here: `ActionState` is the shared place to clear the error, so all three screens get the same behavior from one implementation rather than three copies of a workaround.

Keep the screens' error routing as Slice 1 established it: per-field rules render inside `FieldContainer`, a whole-form failure renders as `InlineErrorText` above the submit button, and a success confirmation is a modal alert. Now that `ActionState.message(for:)` exists, a field's `error:` argument should prefer a server-supplied message when there is one and fall back to the local rule, which is the pattern the template's `RegisterViewModel` uses. Read that file for the idiom.

- [ ] **Step 4: Fix the `MyEventsView` empty state**

While `LoadState` is being touched: `MyEventsView` currently shows "No events joined yet" both while loading and on failure, with no retry. That is audit finding I5 and it is a two-line fix once `LoadState` is the thing driving the view. Show a progress view for `.loading`, the empty copy only for `.empty`, and `ErrorStateView` with a retry for `.failed`.

- [ ] **Step 5: Update the tests**

Every test asserting `LoadFailure` moves to `APIError`. Add tests for the new view model error surfaces, in particular that a server-supplied field message wins over the local rule and that clearing works.

- [ ] **Step 6: Commit**

```bash
git add -u && git add Gabay/Core/UI/ActionState.swift
git commit -m "Classify every failure through APIError"
```

---

## What this slice does not fix

- `routeSummary` is still duplicated between `PostEventView` and `EventDetailView` and still renders 45 minutes as "~0h 45m". Slice 4.
- `pickGPX(at:)` still lacks `startAccessingSecurityScopedResource()`, so a GPX picked from iCloud Drive still fails to read. Slice 4.
- `EventDetailView` still fetches its GPX with `URLSession.shared`, bypassing the client entirely, and still parses it on the main actor. Slice 4. Note it gets worse in relative terms after this slice, since everything around it now has timeouts, retries and typed errors and it has none.
- `EventFetching` is still one fat protocol with an `event(id:)` nobody calls. Slice 3 splits it.
- `StubURLProtocol` is still shared across suites. Slice 4.
- `.updateRequired` and `.maintenance` classify correctly but get no dedicated presentation, because `SessionPolicyInterceptor` is not ported.

## Self-Review

**Spec coverage.** The spec's Slice 2 names `Endpoint`, the `APIClient` protocol and `URLSessionAPIClient`, `APIError`, `RetryPolicy`, `APIConfig`, `RequestInterceptor` with the auth and logging interceptors, `KeychainTokenStore` with `InMemoryTokenStore`, and `TokenRefreshCoordinator`. Tasks 1 to 7 cover all of them. The two consequences the spec calls load-bearing are Task 5 (the store becomes an actor) and Task 6 (401 handling moves into the interceptor, and the `CancellationError` throw is deleted). Certificate pinning lands inert in Task 7 with the flags the spec specifies. The contract amendment lands in Task 5 for `AuthResult` and Task 6 for `POST /auth/refresh`. The spec's error-handling section, which says `APIError` becomes the single classification point and that `LoadState` and `ActionState` funnel through it, is Task 8.

**One correction to the spec, stated in its own section above:** the composition root does not become async, because the token read moves into an already-async interceptor. Only `Session.signOut()` changes shape.

**Placeholder scan.** No "TBD", "handle edge cases", or "similar to Task N". Where a step does not inline code, it is because the file is a byte-level port and the plan gives the exact command to produce it plus the exact edits to make; that is more precise than a retyped copy, not less.

**Type consistency.** `APIError`'s case list in Task 1 matches the migration table and the `catch` sites in Task 6. `AuthTokens` as defined in Task 5 is what `TokenStore`, `TokenRefreshCoordinator` and `AuthInterceptor` all consume. `AuthResult.tokens` is introduced in Task 5 Step 3 and used in Task 6 Step 1. `APIRoute.Auth.refresh` is defined in Task 4 Step 3 and used in Task 6. `any APIClient` is the parameter type from Task 4 onward, including `LiveTokenRefresher`.

**Known risk the implementer of Task 6 must confirm.** The composition root builds two `URLSessionAPIClient` instances: one bare, for the refresher, and one with the auth interceptor, for everything else. If they are collapsed into one, a failing refresh recurses through the interceptor that triggered it. Task 6 Step 4 calls this out and asks for confirmation in the report, because it is invisible in a diff and cannot be caught without running it.
