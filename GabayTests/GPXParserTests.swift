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

    @Test func dropsAPointWithANonNumericLatitude() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.82" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 2)
        #expect(document.points.allSatisfy { $0.latitude.isFinite })
    }

    @Test func dropsAPointWithAnInfiniteCoordinate() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="inf" lon="123.38"/>
        <trkpt lat="9.82" lon="-inf"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 1)
    }

    @Test func dropsAPointOutsideTheCoordinateRange() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="91" lon="123.38"/>
        <trkpt lat="9.82" lon="181"/>
        <trkpt lat="-90.5" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 1)
    }

    @Test func keepsTheExtremesOfTheCoordinateRange() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="90" lon="180"/>
        <trkpt lat="-90" lon="-180"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 2)
    }

    @Test func keepsTheOrderOfTheSurvivingPoints() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.83" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.map(\.latitude) == [9.81, 9.83])
    }

    @Test func keepsAPointWhoseElevationIsNotFinite() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"><ele>nan</ele></trkpt>
        <trkpt lat="9.82" lon="123.38"><ele>120</ele></trkpt>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        // The position is usable, so the point survives; only the climb is lost.
        #expect(document.points.count == 2)
        #expect(document.points.first?.elevation == nil)
        #expect(document.points.last?.elevation == 120)
    }

    @Test func keepsAPointWhoseElevationIsInfinite() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"><ele>inf</ele></trkpt>
        <trkpt lat="9.82" lon="123.38"><ele>120</ele></trkpt>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        // The position is usable, so the point survives; only the climb is lost.
        #expect(document.points.count == 2)
        #expect(document.points.first?.elevation == nil)
        #expect(document.points.last?.elevation == 120)
    }

    @Test func keepsAPointWhoseElevationOverflowsToInfinity() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"><ele>1e400</ele></trkpt>
        <trkpt lat="9.82" lon="123.38"><ele>120</ele></trkpt>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        // 1e400 overflows Double to +infinity, which fails isFinite the same way "inf" and "nan"
        // do; the position is still usable.
        #expect(document.points.count == 2)
        #expect(document.points.first?.elevation == nil)
        #expect(document.points.last?.elevation == 120)
    }

    @Test func refusesAFileWhereEveryPointIsUnusable() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.81" lon="inf"/>
        </trkseg></trk></gpx>
        """

        #expect(throws: GPXError.noPoints) {
            try GPXParser().parse(Data(xml.utf8))
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
