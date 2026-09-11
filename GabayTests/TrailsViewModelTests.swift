//
//  TrailsViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct TrailsViewModelTests {

    // A real store over a temporary folder, so downloads land on a real disk.
    private func makeViewModel(
        catalog: StubCatalog = StubCatalog(),
        cached: CatalogUpdate? = nil
    ) -> (TrailsViewModel, StubCache) {
        let store = TrailStore(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let cache = StubCache(stored: cached)

        return (TrailsViewModel(store: store, catalog: catalog, cache: cache), cache)
    }

    @Test func showsCatalogTrailsThatAreNotOnThePhoneYet() async {
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(trails: [.osmena, .kandungaw]))

        await viewModel.load()

        #expect(viewModel.trails.count == 2)
        #expect(viewModel.trails.allSatisfy { !$0.isOnDevice })
    }

    // Alphabetical, so a downloaded trail does not jump the list.
    @Test func sortsEverythingByName() async {
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(trails: [.osmena, .kandungaw]))

        await viewModel.load()

        #expect(viewModel.trails.map(\.name) == ["Kandungaw Peak", "Osmeña Peak"])
    }

    @Test func downloadingPutsTheTrailOnThePhone() async throws {
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(trails: [.osmena]))
        await viewModel.load()

        let downloaded = await viewModel.download(try #require(viewModel.trails.first))

        #expect(downloaded)
        #expect(viewModel.trails.count == 1)
        #expect(viewModel.trails.first?.isOnDevice == true)
    }

    @Test func reportsAFailedDownloadWithoutAddingTheTrail() async throws {
        let catalog = StubCatalog(trails: [.osmena], gpxFails: true)
        let (viewModel, _) = makeViewModel(catalog: catalog)
        await viewModel.load()

        let downloaded = await viewModel.download(try #require(viewModel.trails.first))

        #expect(!downloaded)
        #expect(viewModel.failure == .offline)
        #expect(viewModel.trails.first?.isOnDevice == false)
    }

    // The catalogue keeps the trail. Only the file goes.
    @Test func removingADownloadedTrailLeavesItInTheList() async throws {
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(trails: [.osmena]))
        await viewModel.load()
        _ = await viewModel.download(try #require(viewModel.trails.first))

        viewModel.remove(try #require(viewModel.trails.first))

        #expect(viewModel.trails.count == 1)
        #expect(viewModel.trails.first?.isOnDevice == false)
    }

    @Test func keepsTheFetchedCatalogForTheNextLaunch() async {
        let (viewModel, cache) = makeViewModel(catalog: StubCatalog(trails: [.osmena]))

        await viewModel.load()

        #expect(cache.stored?.catalog.trails.count == 1)
        #expect(cache.stored?.etag == "v1")
    }

    // Offline at launch still shows a list, which is the point of the cache.
    @Test func fallsBackToTheCachedCatalogWhenTheFetchFails() async {
        let cached = CatalogUpdate(
            catalog: TrailCatalog(version: 1, updated: "2026-09-11", trails: [.osmena]),
            etag: "v1"
        )
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(catalogFails: true), cached: cached)

        await viewModel.load()

        #expect(viewModel.trails.map(\.name) == ["Osmeña Peak"])
    }

    // A 304 says the cached copy is current, so the list must survive it.
    @Test func keepsTheCachedCatalogWhenNothingChanged() async {
        let cached = CatalogUpdate(
            catalog: TrailCatalog(version: 1, updated: "2026-09-11", trails: [.osmena]),
            etag: "v1"
        )
        let (viewModel, _) = makeViewModel(catalog: StubCatalog(isUnchanged: true), cached: cached)

        await viewModel.load()

        #expect(viewModel.trails.count == 1)
    }
}

// MARK: - Stubs

private struct StubCatalog: TrailCatalogFetching {

    var trails: [CatalogTrail] = []
    var catalogFails = false
    var gpxFails = false
    var isUnchanged = false

    func catalog(matching etag: String?) async throws -> CatalogUpdate? {
        if catalogFails { throw URLError(.notConnectedToInternet) }
        if isUnchanged { return nil }

        return CatalogUpdate(
            catalog: TrailCatalog(version: 1, updated: "2026-09-11", trails: trails),
            etag: "v1"
        )
    }

    func gpx(at path: String) async throws -> Data {
        if gpxFails { throw URLError(.notConnectedToInternet) }
        return Data(GPXFixture.twoPoints.utf8)
    }
}

private final class StubCache: CatalogCaching, @unchecked Sendable {

    var stored: CatalogUpdate?

    init(stored: CatalogUpdate?) {
        self.stored = stored
    }

    func load() -> CatalogUpdate? { stored }

    func save(_ update: CatalogUpdate) { stored = update }
}

private extension CatalogTrail {

    static let osmena = CatalogTrail(
        id: "osmena-peak",
        name: "Osmeña Peak",
        region: "Cebu",
        distanceM: 5200,
        ascentM: 388,
        difficulty: "moderate",
        revision: 1,
        gpx: "osmena-peak.gpx",
        bounds: .init(north: 9.82, south: 9.79, east: 123.41, west: 123.37)
    )

    static let kandungaw = CatalogTrail(
        id: "kandungaw-peak",
        name: "Kandungaw Peak",
        region: "Cebu",
        distanceM: 4100,
        ascentM: 420,
        difficulty: "hard",
        revision: 1,
        gpx: "kandungaw-peak.gpx",
        bounds: .init(north: 9.88, south: 9.85, east: 123.45, west: 123.42)
    )
}

private enum GPXFixture {

    static let twoPoints = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
      <trk><name>Osmeña Peak</name><trkseg>
        <trkpt lat="9.7900" lon="123.3700"><ele>820</ele></trkpt>
        <trkpt lat="9.8200" lon="123.4100"><ele>860</ele></trkpt>
      </trkseg></trk>
    </gpx>
    """
}
