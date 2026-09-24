//
//  EventClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct EventClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient() -> EventClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return EventClient(api: APIClient(base: base, configuration: configuration))
    }

    private var eventJSON: Data {
        Data("""
        {
          "id": "hike-for-pawssion",
          "title": "Hike for Pawssion Project",
          "cause": "Pawssion Project Cebu",
          "date": "2026-10-18T05:30:00+08:00",
          "meetingPoint": "Budlaan barangay hall",
          "meetingCoordinate": { "latitude": 10.398, "longitude": 123.887 },
          "feePHP": 250,
          "capacity": 25,
          "joinURL": "https://m.me/pawssionprojectcebu",
          "description": "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
          "photoURL": null,
          "gpxURL": null,
          "distanceM": null,
          "ascentM": null,
          "estimatedMinutes": null,
          "status": "published"
        }
        """.utf8)
    }

    @Test func listsPublishedEvents() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("[\(String(data: eventJSON, encoding: .utf8)!)]".utf8)))

        let events = try await client.events()

        #expect(events.count == 1)
        #expect(events.first?.title == "Hike for Pawssion Project")
        #expect(events.first?.meetingCoordinate == Coordinate(latitude: 10.398, longitude: 123.887))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/events")
    }

    @Test func readsOneEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: eventJSON))

        let event = try await client.event(id: "hike-for-pawssion")

        #expect(event.feePHP == 250)
        #expect(event.gpxURL == nil)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion")
    }

    @Test func createsAnEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: eventJSON))

        let draft = EventDraft(
            title: "Hike for Pawssion Project",
            cause: "Pawssion Project Cebu",
            date: Date(),
            meetingPoint: "Budlaan barangay hall",
            meetingCoordinate: Coordinate(latitude: 10.398, longitude: 123.887),
            feePHP: 250,
            capacity: 25,
            joinURL: URL(string: "https://m.me/pawssionprojectcebu")!,
            description: "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
            photoURL: nil
        )

        let event = try await client.create(draft)

        #expect(event.status == .published)
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    // A hiker-role account hitting the endpoint anyway: the server refuses it.
    @Test func refusesCreatingAnEventWithoutTheOrganizerRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 403, body: Data()))

        let draft = EventDraft(
            title: "x", cause: "x", date: Date(), meetingPoint: "x",
            meetingCoordinate: Coordinate(latitude: 0, longitude: 0),
            feePHP: 0, capacity: 1, joinURL: URL(string: "https://example.test")!,
            description: "x", photoURL: nil
        )

        await #expect(throws: APIError.forbidden()) {
            try await client.create(draft)
        }
    }

    @Test func uploadsAGPXAndReturnsTheUpdatedEvent() async throws {
        let client = makeClient()
        let withRoute = Data("""
        {
          "id": "hike-for-pawssion",
          "title": "Hike for Pawssion Project",
          "cause": "Pawssion Project Cebu",
          "date": "2026-10-18T05:30:00+08:00",
          "meetingPoint": "Budlaan barangay hall",
          "meetingCoordinate": { "latitude": 10.398, "longitude": 123.887 },
          "feePHP": 250,
          "capacity": 25,
          "joinURL": "https://m.me/pawssionprojectcebu",
          "description": "A hike up Budlaan to Kang-Irag, proceeds go to the shelter.",
          "photoURL": null,
          "gpxURL": "https://example.test/uploads/hike-for-pawssion.gpx",
          "distanceM": 4761,
          "ascentM": 386,
          "estimatedMinutes": 132,
          "status": "published"
        }
        """.utf8)
        StubURLProtocol.queue(.init(status: 200, body: withRoute))

        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try Data("<gpx></gpx>".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let event = try await client.uploadGPX(
            eventID: "hike-for-pawssion",
            fileURL: fileURL,
            distanceM: 4761,
            ascentM: 386,
            estimatedMinutes: 132
        )

        #expect(event.gpxURL?.absoluteString == "https://example.test/uploads/hike-for-pawssion.gpx")
        #expect(event.distanceM == 4761)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion/gpx")
    }

    @Test func joinsAnEvent() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 204, body: Data()))

        try await client.join("hike-for-pawssion")

        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/api/events/hike-for-pawssion/join")
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func listsJoinedEvents() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("[\(String(data: eventJSON, encoding: .utf8)!)]".utf8)))

        let mine = try await client.mine()

        #expect(mine.count == 1)
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/me/events")
    }
}
