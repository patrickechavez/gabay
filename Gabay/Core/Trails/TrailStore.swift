//
//  TrailStore.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// The trails on this phone, and the file each one came from.
protocol TrailStoring: Sendable {

    // Everything on the device, downloaded and imported alike.
    func trails() throws -> [Trail]

    func points(of trail: Trail) throws -> [TrackPoint]

    // Writes a downloaded file and returns the trail it turned out to be.
    @discardableResult
    func save(_ data: Data, as entry: CatalogTrail) throws -> Trail

    // Writes a file the user picked, measuring it rather than trusting a name.
    func importFile(at url: URL) throws -> Trail

    func remove(_ trail: Trail) throws
}

enum TrailStoreError: Error, Equatable {
    case fileMissing
    case unreadableFile
}

// One GPX per trail on disk. They are files, so the file system is the database.
struct TrailStore: TrailStoring {

    private let directory: URL
    private let parser = GPXParser()

    init(directory: URL = TrailStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Trails")
    }

    func trails() throws -> [Trail] {
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "gpx" }

        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let document = try? parser.parse(data) else { return nil }

            return Trail(
                imported: document,
                id: url.deletingPathExtension().lastPathComponent,
                fallbackName: url.deletingPathExtension().lastPathComponent
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func points(of trail: Trail) throws -> [TrackPoint] {
        // Reading is the existence check: a URL's path is percent encoded.
        guard let data = try? Data(contentsOf: file(for: trail.id)) else {
            throw TrailStoreError.fileMissing
        }

        return try parser.parse(data).points
    }

    @discardableResult
    func save(_ data: Data, as entry: CatalogTrail) throws -> Trail {
        // Parsed before it is kept, so a broken download never reaches the list.
        guard (try? parser.parse(data)) != nil else { throw TrailStoreError.unreadableFile }

        try data.write(to: file(for: entry.id), options: .atomic)
        return Trail(entry, isOnDevice: true)
    }

    func importFile(at url: URL) throws -> Trail {
        // A file from the picker lives outside the app's sandbox.
        let needsRelease = url.startAccessingSecurityScopedResource()
        defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw TrailStoreError.unreadableFile }
        guard let document = try? parser.parse(data) else { throw TrailStoreError.unreadableFile }

        let id = "imported-\(UUID().uuidString)"
        try data.write(to: file(for: id), options: .atomic)

        return Trail(
            imported: document,
            id: id,
            fallbackName: url.deletingPathExtension().lastPathComponent
        )
    }

    func remove(_ trail: Trail) throws {
        try FileManager.default.removeItem(at: file(for: trail.id))
    }

    private func file(for id: String) -> URL {
        directory.appending(path: "\(id).gpx")
    }
}
