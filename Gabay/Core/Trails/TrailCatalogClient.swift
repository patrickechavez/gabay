//
//  TrailCatalogClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// One trail as the published catalog describes it.
struct CatalogTrail: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let region: String
    let distanceM: Int
    let ascentM: Int
    let difficulty: String
    let revision: Int
    let gpx: String
    let bounds: Bounds

    struct Bounds: Codable, Equatable, Sendable {
        let north: Double
        let south: Double
        let east: Double
        let west: Double
    }
}

struct TrailCatalog: Codable, Equatable, Sendable {
    let version: Int
    let updated: String
    let trails: [CatalogTrail]
}

// What one fetch of the catalog came back with.
struct CatalogUpdate: Equatable, Sendable {
    let catalog: TrailCatalog
    let etag: String?
}

// Fetches the published catalog and the GPX files it lists.
protocol TrailCatalogFetching: Sendable {

    // nil when the catalog has not changed since the tag we already hold.
    func catalog(matching etag: String?) async throws -> CatalogUpdate?

    func gpx(at path: String) async throws -> Data
}

// Plain GETs against static files. No auth, no retry, no interceptors: there
// is no server to negotiate with, only files on a CDN.
struct TrailCatalogClient: TrailCatalogFetching {

    // A trail that will not download in this long is not worth waiting for.
    private static let timeout: TimeInterval = 20

    let base: URL

    private let session: URLSession

    init(base: URL = AppConfig.catalogURL) {
        self.base = base

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func catalog(matching etag: String?) async throws -> CatalogUpdate? {
        var request = URLRequest(url: base.appending(path: "catalog.json"))
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TrailCatalogError.badResponse }

        // Unchanged, so the copy on disk is already right.
        if http.statusCode == 304 { return nil }
        guard http.statusCode == 200 else { throw TrailCatalogError.badResponse }

        return CatalogUpdate(
            catalog: try JSONDecoder.trails.decode(TrailCatalog.self, from: data),
            etag: http.value(forHTTPHeaderField: "ETag")
        )
    }

    func gpx(at path: String) async throws -> Data {
        let (data, response) = try await session.data(from: base.appending(path: path))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TrailCatalogError.badResponse
        }
        return data
    }
}

enum TrailCatalogError: Error, Equatable {
    case badResponse
}
