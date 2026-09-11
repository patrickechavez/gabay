//
//  CatalogCache.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// The last catalog we saw, so the list is there before the network is.
protocol CatalogCaching: Sendable {

    func load() -> CatalogUpdate?

    func save(_ update: CatalogUpdate)
}

// One file beside the trails. A failed read means an empty list, never a crash.
struct CatalogCache: CatalogCaching {

    private let file: URL

    init(directory: URL = URL.applicationSupportDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appending(path: "catalog.json")
    }

    func load() -> CatalogUpdate? {
        guard let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder.trails.decode(Stored.self, from: data) else { return nil }

        return CatalogUpdate(catalog: stored.catalog, etag: stored.etag)
    }

    func save(_ update: CatalogUpdate) {
        let stored = Stored(catalog: update.catalog, etag: update.etag)
        guard let data = try? JSONEncoder.trails.encode(stored) else { return }

        try? data.write(to: file, options: .atomic)
    }

    // The tag travels with the catalog it describes, or a 304 means nothing.
    private struct Stored: Codable {
        let catalog: TrailCatalog
        let etag: String?
    }
}
