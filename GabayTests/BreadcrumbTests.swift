//
//  BreadcrumbTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

// Serialized: Breadcrumb holds one process-wide reporter, so these assert on
// what the spy contains rather than on it being alone.
@Suite(.serialized)
struct BreadcrumbTests {

    private final class SpyCrashReporter: CrashReporting, @unchecked Sendable {
        var messages: [String] = []

        func record(_ error: Error) {}

        func log(_ message: String) { messages.append(message) }

        func setUser(id: String?) {}
    }

    @Test func sendsRecordedMessagesToTheInstalledReporter() {
        let spy = SpyCrashReporter()
        Breadcrumb.install(spy)
        defer { Breadcrumb.install(NoopCrashReporter()) }

        Breadcrumb.record("Signed in")

        #expect(spy.messages.contains("Signed in"))
    }

    @Test func leavesABreadcrumbForEveryLoggedEvent() {
        let spy = SpyCrashReporter()
        Breadcrumb.install(spy)
        defer { Breadcrumb.install(NoopCrashReporter()) }

        AppLogger.auth.breadcrumb("Access token refreshed")
        AppLogger.lifecycle.breadcrumb("Signed out")

        #expect(spy.messages.contains("Access token refreshed"))
        #expect(spy.messages.contains("Signed out"))
    }
}
