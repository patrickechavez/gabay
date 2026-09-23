//
//  JSONCodersTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct JSONCodersTests {

    private struct Stamped: Codable, Equatable {
        var recordedAt: Date
    }

    private func decode(_ stamp: String) throws -> Date {
        let data = Data("{\"recorded_at\":\"\(stamp)\"}".utf8)
        return try JSONDecoder.trails.decode(Stamped.self, from: data).recordedAt
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

    // Strava and Garmin both write fractional seconds. Foundation's plain
    // formatter rejects them, so the decoder tries both.
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

    // The catalogue is hand written in camelCase, which has no underscores,
    // so the strategy leaves those keys alone.
    @Test func leavesACamelCaseKeyAlone() throws {
        let data = Data("""
        {
          "version": 1,
          "updated": "2026-09-11",
          "trails": [
            {
              "id": "osmena-peak",
              "name": "Osmeña Peak",
              "region": "Cebu",
              "distanceM": 5200,
              "ascentM": 388,
              "difficulty": "moderate",
              "revision": 1,
              "gpx": "osmena-peak.gpx",
              "bounds": { "north": 9.82, "south": 9.79, "east": 123.41, "west": 123.37 }
            }
          ]
        }
        """.utf8)

        let catalog = try JSONDecoder.trails.decode(TrailCatalog.self, from: data)

        #expect(catalog.trails.first?.distanceM == 5200)
        #expect(catalog.trails.first?.ascentM == 388)
    }

    // What the app writes, the app must read back.
    @Test func roundTripsThroughBothCoders() throws {
        let written = Stamped(recordedAt: noon)

        let data = try JSONEncoder.trails.encode(written)
        let read = try JSONDecoder.trails.decode(Stamped.self, from: data)

        #expect(read == written)
    }
}
