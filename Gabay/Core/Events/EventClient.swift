//
//  EventClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

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

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func events() async throws -> [Event] {
        try await api.get(APIRoute.Events.list)
    }

    func event(id: String) async throws -> Event {
        try await api.get(APIRoute.Events.detail(id))
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

    func join(_ id: String) async throws {
        try await api.send(Endpoint(APIRoute.Events.join(id), method: .post))
    }

    func mine() async throws -> [Event] {
        try await api.get(APIRoute.Events.mine)
    }
}
