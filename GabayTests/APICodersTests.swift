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
