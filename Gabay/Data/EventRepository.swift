//
//  EventRepository.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

// Split in two so neither consumer sees methods it cannot use: the browsing screens cannot
// publish an event, and the organizer form cannot list or join one.
protocol EventBrowsingRepository: Sendable {

    func events() async throws -> [Event]

    func mine() async throws -> [Event]

    func join(_ id: String) async throws
}

protocol EventPublishingRepository: Sendable {

    func create(_ draft: EventDraft) async throws -> Event

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event
}

// One backend, so one implementation conforms to both; the split is for the consumers.
struct LiveEventRepository: EventBrowsingRepository, EventPublishingRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func events() async throws -> [Event] {
        try await api.get(APIRoute.Events.list)
    }

    func mine() async throws -> [Event] {
        try await api.get(APIRoute.Events.mine)
    }

    func join(_ id: String) async throws {
        try await api.send(Endpoint(APIRoute.Events.join(id), method: .post))
    }

    func create(_ draft: EventDraft) async throws -> Event {
        try await api.post(APIRoute.Events.list, body: draft)
    }

    func uploadGPX(
        eventID: String,
        fileURL: URL,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        var form = MultipartFormData()
        form.addField("distanceM", value: String(distanceM))
        if let ascentM { form.addField("ascentM", value: String(ascentM)) }
        form.addField("estimatedMinutes", value: String(estimatedMinutes))

        // The filename rides in the multipart Content-Disposition header unescaped, so it must be
        // one we control, not the user's raw file name.
        form.addFile(
            "gpx",
            filename: "\(eventID).gpx",
            mimeType: "application/gpx+xml",
            data: try Data(contentsOf: fileURL)
        )

        return try await api.upload(APIRoute.Events.gpx(eventID), form: form)
    }
}
