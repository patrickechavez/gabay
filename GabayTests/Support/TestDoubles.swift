//
//  TestDoubles.swift
//  GabayTests
//

import Foundation
@testable import Gabay

// Shared stand-ins for the protocols view models depend on, so tests don't need a network or a
// Keychain.

final class StubAuthRepository: AuthRepository, @unchecked Sendable {
    var registerResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized())
    var loginResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized())
    var meResult: Result<Account, any Error> = .failure(APIError.unauthorized())
    private(set) var registeredEmail: String?
    private(set) var loggedInEmail: String?

    func register(email: String, password: String) async throws -> AuthResult {
        registeredEmail = email
        return try registerResult.get()
    }

    func login(email: String, password: String) async throws -> AuthResult {
        loggedInEmail = email
        return try loginResult.get()
    }

    func me() async throws -> Account {
        try meResult.get()
    }
}

final class StubEventRepository: EventBrowsingRepository, EventPublishingRepository, @unchecked Sendable {
    var eventsResult: Result<[Event], any Error> = .success([])
    var mineResult: Result<[Event], any Error> = .success([])
    var createResult: Result<Event, any Error> = .failure(APIError.forbidden())
    var uploadGPXResult: Result<Event, any Error> = .failure(APIError.forbidden())
    var joinResult: Result<Void, any Error> = .success(())
    private(set) var joinedIds: [String] = []
    private(set) var uploadedGPXEventIds: [String] = []
    private(set) var eventsCallCount = 0
    var gpxResult: Result<Data, any Error> = .failure(APIError.notFound())
    private(set) var requestedGPXEventIds: [String] = []

    func events() async throws -> [Event] {
        eventsCallCount += 1
        return try eventsResult.get()
    }

    func create(_ draft: EventDraft) async throws -> Event { try createResult.get() }

    func uploadGPX(
        eventID: String,
        data: Data,
        distanceM: Int,
        ascentM: Int?,
        estimatedMinutes: Int
    ) async throws -> Event {
        uploadedGPXEventIds.append(eventID)
        return try uploadGPXResult.get()
    }

    func join(_ id: String) async throws {
        joinedIds.append(id)
        try joinResult.get()
    }

    func mine() async throws -> [Event] { try mineResult.get() }

    func gpx(eventID: String) async throws -> Data {
        requestedGPXEventIds.append(eventID)
        return try gpxResult.get()
    }
}

extension Event {

    static func fixture(
        id: String = "hike-for-pawssion",
        title: String = "Hike for Pawssion Project",
        gpxURL: URL? = nil,
        distanceM: Int? = nil,
        ascentM: Int? = nil,
        estimatedMinutes: Int? = nil,
        status: Status = .published
    ) -> Event {
        Event(
            id: id,
            title: title,
            cause: "Pawssion Project Cebu",
            date: Date(timeIntervalSince1970: 1_760_000_000),
            meetingPoint: "Budlaan barangay hall",
            meetingCoordinate: Coordinate(latitude: 10.398, longitude: 123.887),
            feePHP: 250,
            capacity: 25,
            joinURL: URL(string: "https://m.me/pawssionprojectcebu")!,
            description: "A hike up Budlaan to Kang-Irag.",
            photoURL: nil,
            gpxURL: gpxURL,
            distanceM: distanceM,
            ascentM: ascentM,
            estimatedMinutes: estimatedMinutes,
            status: status
        )
    }
}
