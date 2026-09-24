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
}
