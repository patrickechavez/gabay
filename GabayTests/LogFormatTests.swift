//
//  LogFormatTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// `LogFormat.headers(_:)` is pure, unlike `LoggingInterceptor` (which only logs), so redaction is
// testable directly here.
struct LogFormatTests {

    // Fails if "authorization" is removed from `redactedHeaders`; the token would then appear in
    // full.
    @Test func redactsTheAuthorizationHeaderValue() {
        let formatted = LogFormat.headers(["Authorization": "Bearer secret-token"])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("Authorization"))
        #expect(formatted.contains("<redacted>"))
    }

    // Fails if redaction keyed on exact casing instead of the lowercase comparison `headers(_:)`
    // actually does.
    @Test func redactsRegardlessOfHeaderCasing() {
        let formatted = LogFormat.headers(["authorization": "Bearer secret-token"])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("<redacted>"))
    }

    // Fails if `headers(_:)` redacted everything or nothing; pairing a sensitive header with a
    // benign one catches both.
    @Test func leavesNonSensitiveHeadersIntactAlongsideARedactedOne() {
        let formatted = LogFormat.headers([
            "Authorization": "Bearer secret-token",
            "Accept": "application/json"
        ])

        #expect(!formatted.contains("secret-token"))
        #expect(formatted.contains("Accept: application/json"))
    }

    // Regression test: without stripping underscores, camelCase keys like `accessToken` (the actual
    // /auth/login wire spelling) wouldn't match snake_case `redactedBodyKeys`, and live tokens
    // would print in full.
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

    // Would not fail if the fix were reverted; snake_case already matched the unnormalized keys, so
    // this only guards against regressing what already worked.
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

    // Would not fail if the fix were reverted; it guards against a different bug instead, an
    // over-matching normalization that redacts non-sensitive camelCase keys, which the other two
    // tests wouldn't catch.
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
