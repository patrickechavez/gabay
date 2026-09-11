//
//  GPXParserTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct GPXParserTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: FixtureAnchor.self).url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    private func parse(_ name: String) throws -> GPXDocument {
        try GPXParser().parse(try fixture(name))
    }

    @Test func readsATrack() throws {
        let document = try parse("osmena")

        #expect(document.tracks.count == 1)
        #expect(document.tracks.first?.name == "Osmeña Peak")
        #expect(document.points.count == 5)
    }

    @Test func readsCoordinatesElevationAndTime() throws {
        let first = try #require(try parse("osmena").points.first)

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 11
        components.hour = 5
        components.minute = 14
        components.second = 2
        components.timeZone = TimeZone(identifier: "UTC")

        #expect(first.latitude == 9.8127)
        #expect(first.longitude == 123.3878)
        #expect(first.elevation == 820)
        #expect(first.time == Calendar(identifier: .gregorian).date(from: components))
    }

    // A hand drawn route has no elevation and no times, and is still a line.
    @Test func readsARouteWithoutElevation() throws {
        let document = try parse("route-no-elevation")

        #expect(document.points.count == 3)
        #expect(document.points.allSatisfy { $0.elevation == nil })
        #expect(document.points.allSatisfy { $0.time == nil })
        #expect(document.tracks.first?.name == "Budlaan loop")
    }

    // Waypoints are landmarks, not a line to follow, so they are not points.
    @Test func ignoresStandaloneWaypoints() throws {
        #expect(throws: GPXError.noPoints) {
            try parse("waypoints-only")
        }
    }

    // A transfer that died mid file still leaves usable points.
    @Test func keepsWhatItReadFromATruncatedFile() throws {
        let document = try parse("truncated")

        #expect(document.points.count == 3)
        #expect(document.tracks.first?.name == "Osmeña Peak")
    }

    @Test func refusesAFileThatIsNotXML() throws {
        #expect(throws: GPXError.notXML) {
            try parse("not-gpx")
        }
    }
}

struct TrackMathTests {

    private func points(_ elevations: [Double?]) -> [TrackPoint] {
        elevations.enumerated().map { index, elevation in
            // Roughly 111 metres of latitude per 0.001 degrees.
            TrackPoint(
                latitude: 9.8127 + Double(index) * 0.001,
                longitude: 123.3878,
                elevation: elevation,
                time: Date(timeIntervalSinceReferenceDate: Double(index) * 30)
            )
        }
    }

    @Test func measuresDistanceAlongThePoints() {
        let distance = points([nil, nil, nil]).distance

        // Two gaps of about 111 metres.
        #expect((220...225).contains(distance))
    }

    @Test func measuresNothingForASinglePoint() {
        #expect(points([nil]).distance == 0)
    }

    @Test func countsOnlyTheRises() {
        let ascent = points([100, 120, 110, 140]).ascent()

        #expect(ascent == 50)
    }

    // A GPS elevation drifts while standing still, so small rises are noise.
    @Test func ignoresWobbleUnderTheThreshold() {
        let ascent = points([100, 101, 100, 102, 101]).ascent()

        #expect(ascent == 0)
    }

    @Test func measuresDurationFromTheTimestamps() {
        #expect(points([nil, nil, nil]).duration == 60)
    }

    @Test func reportsNoDurationForARouteWithoutTimes() {
        let route = [
            TrackPoint(latitude: 9.8, longitude: 123.3, elevation: nil, time: nil),
            TrackPoint(latitude: 9.9, longitude: 123.3, elevation: nil, time: nil)
        ]

        #expect(route.duration == nil)
    }
}

// Locates the fixture files inside the test bundle.
private final class FixtureAnchor {}
