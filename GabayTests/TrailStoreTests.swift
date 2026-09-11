//
//  TrailStoreTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct TrailStoreTests {

    // A directory per test, so one test's trails never reach another.
    private func makeStore() -> (TrailStore, URL) {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        return (TrailStore(directory: directory), directory)
    }

    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle(for: StoreFixtureAnchor.self).url(forResource: name, withExtension: "gpx"))
    }

    @Test func startsEmpty() throws {
        let (store, _) = makeStore()

        #expect(try store.trails().isEmpty)
    }

    // The list has to show something the moment a file arrives, so the numbers
    // are measured on import rather than waiting for the map.
    @Test func importsAFileAndMeasuresIt() throws {
        let (store, _) = makeStore()

        let trail = try store.importFile(at: try fixture("osmena"))

        #expect(trail.name == "Osmeña Peak")
        #expect(trail.source == .imported)
        #expect(trail.isOnDevice)
        #expect(trail.distance > 0)
        // 820, 830, 828, 860, 855: ten up, a two metre dip ignored, thirty up.
        #expect(trail.ascent == 40)
    }

    @Test func keepsAnImportedFileForTheNextLaunch() throws {
        let (store, directory) = makeStore()
        _ = try store.importFile(at: try fixture("osmena"))

        // A second store over the same folder is the next launch.
        let reopened = TrailStore(directory: directory)

        #expect(try reopened.trails().count == 1)
        #expect(try reopened.trails().first?.name == "Osmeña Peak")
    }

    @Test func readsThePointsBackForTheMap() throws {
        let (store, _) = makeStore()
        let trail = try store.importFile(at: try fixture("osmena"))

        #expect(try store.points(of: trail).count == 5)
    }

    // Two imports of the same file are two trails: somebody may well carry two
    // versions of a route and want both.
    @Test func keepsEachImportSeparately() throws {
        let (store, _) = makeStore()

        _ = try store.importFile(at: try fixture("osmena"))
        _ = try store.importFile(at: try fixture("osmena"))

        #expect(try store.trails().count == 2)
    }

    @Test func refusesAFileThatIsNotATrail() throws {
        let (store, _) = makeStore()

        #expect(throws: TrailStoreError.unreadableFile) {
            try store.importFile(at: try fixture("not-gpx"))
        }
        #expect(try store.trails().isEmpty)
    }

    // A half written download must never reach the list.
    @Test func refusesToSaveAnUnreadableDownload() throws {
        let (store, _) = makeStore()
        let entry = CatalogTrail(
            id: "broken",
            name: "Broken",
            region: "Cebu",
            distanceM: 1000,
            ascentM: 100,
            difficulty: "easy",
            revision: 1,
            gpx: "trails/broken.gpx",
            bounds: .init(north: 1, south: 0, east: 1, west: 0)
        )

        #expect(throws: TrailStoreError.unreadableFile) {
            try store.save(Data("not a trail".utf8), as: entry)
        }
        #expect(try store.trails().isEmpty)
    }

    @Test func removesATrail() throws {
        let (store, _) = makeStore()
        let trail = try store.importFile(at: try fixture("osmena"))

        try store.remove(trail)

        #expect(try store.trails().isEmpty)
    }
}

// Locates the fixture files inside the test bundle.
private final class StoreFixtureAnchor {}
