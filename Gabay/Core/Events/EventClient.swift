//
//  EventClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

// Hashable, not merely Equatable: `.navigationDestination(item:)` in the
// events list requires it, the same reason the free-trail app's Trail was
// declared Hashable.
struct Event: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
    let gpxURL: URL?
    let distanceM: Int?
    let ascentM: Int?
    let estimatedMinutes: Int?
    let status: Status

    enum Status: String, Codable, Sendable {
        case pending
        case published
    }
}

// What the organizer form sends to create an event. No id, status, or route
// stats, the backend assigns the first two, and a route (if any) is added
// afterward through a separate upload.
struct EventDraft: Encodable, Sendable {
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
}

// Lists published events, lets an organizer post one and attach a route,
// and tracks joins.
protocol EventFetching: Sendable {

    func events() async throws -> [Event]

    func event(id: String) async throws -> Event

    func create(_ draft: EventDraft) async throws -> Event

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event

    func join(_ id: String) async throws

    func mine() async throws -> [Event]
}

struct EventClient: EventFetching {

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func events() async throws -> [Event] {
        try await api.get("events")
    }

    func event(id: String) async throws -> Event {
        try await api.get("events/\(id)")
    }

    func create(_ draft: EventDraft) async throws -> Event {
        try await api.post("events", body: draft)
    }

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        var fields = [
            "distanceM": String(distanceM),
            "estimatedMinutes": String(estimatedMinutes)
        ]
        if let ascentM { fields["ascentM"] = String(ascentM) }

        return try await api.postMultipart(
            "events/\(eventID)/gpx",
            fileURL: fileURL,
            fieldName: "gpx",
            filename: fileURL.lastPathComponent,
            mimeType: "application/gpx+xml",
            fields: fields
        )
    }

    func join(_ id: String) async throws {
        try await api.post("events/\(id)/join")
    }

    func mine() async throws -> [Event] {
        try await api.get("me/events")
    }
}
