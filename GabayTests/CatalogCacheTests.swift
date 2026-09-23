//
//  CatalogCacheTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct CatalogCacheTests {

    // A folder per test, so one test's catalogue never reaches another.
    private func makeCache() -> (CatalogCache, URL) {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        return (CatalogCache(directory: directory), directory)
    }

    private func makeUpdate(etag: String? = "\"v1\"") -> CatalogUpdate {
        CatalogUpdate(
            catalog: TrailCatalog(version: 1, updated: "2026-09-11", trails: [.osmena]),
            etag: etag
        )
    }

    @Test func startsWithNothing() {
        let (cache, _) = makeCache()

        #expect(cache.load() == nil)
    }

    // The point of the cache: the list is there before the network is.
    @Test func givesBackWhatItWasGiven() {
        let (cache, _) = makeCache()

        cache.save(makeUpdate())
        let loaded = cache.load()

        #expect(loaded?.catalog.trails.count == 1)
        #expect(loaded?.catalog.trails.first?.name == "Osmeña Peak")
        #expect(loaded?.etag == "\"v1\"")
    }

    // The tag travels with the catalogue, or a 304 means nothing.
    @Test func survivesTheNextLaunch() {
        let (cache, directory) = makeCache()
        cache.save(makeUpdate())

        let reopened = CatalogCache(directory: directory)

        #expect(reopened.load()?.etag == "\"v1\"")
    }

    @Test func keepsACatalogueThatCameWithNoTag() {
        let (cache, _) = makeCache()

        cache.save(makeUpdate(etag: nil))

        #expect(cache.load()?.etag == nil)
        #expect(cache.load()?.catalog.trails.count == 1)
    }

    @Test func replacesWhatWasThereBefore() {
        let (cache, _) = makeCache()
        cache.save(makeUpdate(etag: "\"v1\""))

        cache.save(CatalogUpdate(
            catalog: TrailCatalog(version: 1, updated: "2026-09-12", trails: []),
            etag: "\"v2\""
        ))

        #expect(cache.load()?.etag == "\"v2\"")
        #expect(cache.load()?.catalog.trails.isEmpty == true)
    }

    // A half written file is not a crash, it is an empty list.
    @Test func readsNothingFromAFileItCannotDecode() throws {
        let (cache, directory) = makeCache()
        cache.save(makeUpdate())

        try Data("not json".utf8).write(to: directory.appending(path: "catalog.json"))

        #expect(cache.load() == nil)
    }
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
}
