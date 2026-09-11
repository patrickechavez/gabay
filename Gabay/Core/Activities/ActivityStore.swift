//
//  ActivityStore.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import Foundation

// The walks on this phone, and the file each one produced.
protocol ActivityStoring: Sendable {

    // Newest first, healing anything a crash left behind.
    func activities() throws -> [Activity]

    func points(of activity: Activity) throws -> [TrackPoint]

    // The GPX itself, for the share sheet.
    func file(of activity: Activity) -> URL

    // Opens a file for a walk that is starting.
    func beginWriting(_ activity: Activity) throws -> GPXWriter

    // Keeps a finished walk, with whatever name and type it was saved under.
    func save(_ activity: Activity, startedAs started: (name: String, kind: Activity.Kind)) throws

    func remove(_ activity: Activity) throws

    // Throws away a walk that was never saved.
    func discard(_ activity: Activity)
}

enum ActivityStoreError: Error, Equatable {
    case fileMissing
}

// One GPX and one small sidecar per walk. The sidecar is what history reads.
struct ActivityStore: ActivityStoring {

    // The type a walk is written with before anybody says what it was.
    static let startingKind = Activity.Kind.walk

    private let directory: URL
    private let parser = GPXParser()

    init(directory: URL = ActivityStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Activities")
    }

    func activities() throws -> [Activity] {
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "gpx" }

        return files
            .compactMap { activity(for: $0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func points(of activity: Activity) throws -> [TrackPoint] {
        guard let data = try? Data(contentsOf: file(of: activity)) else {
            throw ActivityStoreError.fileMissing
        }

        return try parser.parse(data).points
    }

    func file(of activity: Activity) -> URL {
        directory.appending(path: "\(activity.id).gpx")
    }

    func beginWriting(_ activity: Activity) throws -> GPXWriter {
        try GPXWriter(
            url: file(of: activity),
            name: activity.name,
            kind: Self.startingKind,
            startedAt: activity.startedAt
        )
    }

    func save(_ activity: Activity, startedAs started: (name: String, kind: Activity.Kind)) throws {
        GPXWriter.relabel(
            file(of: activity),
            from: started,
            to: (activity.name, activity.kind)
        )

        try JSONEncoder.trails
            .encode(activity)
            .write(to: sidecar(for: activity.id), options: .atomic)
    }

    func remove(_ activity: Activity) throws {
        try FileManager.default.removeItem(at: file(of: activity))
        try? FileManager.default.removeItem(at: sidecar(for: activity.id))
    }

    func discard(_ activity: Activity) {
        try? remove(activity)
    }

    private func sidecar(for id: String) -> URL {
        directory.appending(path: "\(id).json")
    }

    // The sidecar when there is one, otherwise measured back out of the file.
    private func activity(for id: String) -> Activity? {
        if let data = try? Data(contentsOf: sidecar(for: id)),
           let saved = try? JSONDecoder.trails.decode(Activity.self, from: data) {
            return saved
        }

        return recovered(id)
    }

    // A walk the app died in the middle of. Shorter than it was, but real.
    private func recovered(_ id: String) -> Activity? {
        guard let data = try? Data(contentsOf: directory.appending(path: "\(id).gpx")),
              let document = try? parser.parse(data) else { return nil }

        let points = document.points
        let started = points.first?.time ?? Date()
        let hasElevation = points.contains { $0.elevation != nil }

        return Activity(
            id: id,
            name: document.tracks.first?.name ?? document.name
                ?? String(localized: "Recovered walk",
                          comment: "Name for a walk the app was interrupted during"),
            kind: Self.startingKind,
            startedAt: started,
            distance: points.distance,
            ascent: hasElevation ? points.ascent() : nil,
            duration: points.duration ?? 0
        )
    }
}
