//
//  LogFormatTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// `LogFormat.headers(_:)` is a pure function, unlike `LoggingInterceptor`
// itself (which only writes to the unified log), so redaction is testable
// here directly.
struct LogFormatTests {

    // Would fail if "authorization" were removed from `redactedHeaders`:
    // the formatted output would then contain "Bearer secret-token" in
    // full, and this assertion on the value's absence would break.
    @Test func redactsTheAuthorizationHeaderValue() {
        let formatted = LogFormat.headers(["Authorization": "Bearer secret-token"])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("Authorization"))
        #expect(formatted.contains("<redacted>"))
    }

    // Would fail if redaction were keyed on the header's exact casing
    // instead of the lowercased comparison `headers(_:)` actually does:
    // a lowercase "authorization" would then slip through unredacted.
    @Test func redactsRegardlessOfHeaderCasing() {
        let formatted = LogFormat.headers(["authorization": "Bearer secret-token"])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("<redacted>"))
    }

    // Would fail if `headers(_:)` redacted everything (or nothing): pairs
    // a sensitive header with a non-sensitive one so a change that removes
    // "authorization" from the set, or one that starts redacting
    // everything, is caught either way.
    @Test func leavesNonSensitiveHeadersIntactAlongsideARedactedOne() {
        let formatted = LogFormat.headers([
            "Authorization": "Bearer secret-token",
            "Accept": "application/json"
        ])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("Accept: application/json"))
    }

    // Would fail if the normalization fix in `redact(_:)` were reverted:
    // `redactedBodyKeys` only lists "access_token"/"refresh_token", and
    // without stripping underscores before comparing, "accessToken" and
    // "refreshToken" (the actual wire spelling `/auth/login` returns, per
    // `AuthResult` in AuthClient.swift) would not match, so both live
    // tokens would print in full. This is the regression test for the bug.
    @Test func redactsCamelCaseTokensInTheAuthLoginResponseShape() {
        let json = """
        {"accessToken":"live-access-token","refreshToken":"live-refresh-token","expiresAt":"2026-09-25T10:00:00Z","role":"hiker"}
        """
        let formatted = LogFormat.body(Data(json.utf8), contentType: "application/json")

        #expect(!formatted.contains("live-access-token"))
        #expect(!formatted.contains("live-refresh-token"))
        #expect(formatted.contains("\"accessToken\":\"<redacted>\""))
        #expect(formatted.contains("\"refreshToken\":\"<redacted>\""))
    }

    // Would NOT fail if the normalization fix were reverted: the snake_case
    // spellings already matched the un-normalized `redactedBodyKeys`
    // entries before this fix, so this only guards against the fix
    // regressing behavior that already worked.
    @Test func stillRedactsSnakeCaseTokens() {
        let json = """
        {"access_token":"live-access-token","refresh_token":"live-refresh-token"}
        """
        let formatted = LogFormat.body(Data(json.utf8), contentType: "application/json")

        #expect(!formatted.contains("live-access-token"))
        #expect(!formatted.contains("live-refresh-token"))
        #expect(formatted.contains("\"access_token\":\"<redacted>\""))
        #expect(formatted.contains("\"refresh_token\":\"<redacted>\""))
    }

    // Would NOT fail if the normalization fix were reverted: neither key
    // here is sensitive under either the old or the new comparison, so the
    // old un-normalized code already left both alone. This test isn't a
    // regression test for the leak; it guards against a differently broken
    // normalization - one that over-matches and redacts non-sensitive
    // camelCase keys too, which the previous two tests wouldn't catch
    // since they only assert on the sensitive keys.
    @Test func leavesNonSensitiveCamelCaseKeysIntact() {
        let json = """
        {"expiresAt":"2026-09-25T10:00:00Z","displayName":"Dana"}
        """
        let formatted = LogFormat.body(Data(json.utf8), contentType: "application/json")

        #expect(formatted.contains("\"expiresAt\":\"2026-09-25T10:00:00Z\""))
        #expect(formatted.contains("\"displayName\":\"Dana\""))
        #expect(!formatted.contains("<redacted>"))
    }
}
