//
//  OfflineWriteLoggerTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

struct OfflineWriteLoggerTests {

    @Test func marksTheWriteAsNeverSent() {
        let summary = OfflineWriteLogger.summary(.post)

        #expect(summary.hasPrefix("⇢ POST  (offline)"))
    }

    @Test func includesThePathWhenGiven() {
        let summary = OfflineWriteLogger.summary(.patch, path: "/rest/v1/items")

        #expect(summary.hasPrefix("⇢ PATCH /rest/v1/items  (offline)"))
    }

    @Test func stampsTheBuildThatWroteTheRow() {
        let summary = OfflineWriteLogger.summary(.delete)

        #expect(summary.contains("client=\(ClientMetadata.appVersion)(\(ClientMetadata.appBuild))"))
    }
}
