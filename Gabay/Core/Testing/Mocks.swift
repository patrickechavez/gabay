//
//  Mocks.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

#if DEVELOPMENT

import Foundation
import UIKit

enum SampleData {

    static let user = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "raven",
        email: "raven@example.com",
        firstName: "Raven",
        lastName: "Solis",
        image: nil
    )

    static let tokens = AuthTokens(
        accessToken: "sample-access-token",
        refreshToken: "sample-refresh-token",
        expiresAt: Date().addingTimeInterval(3600)
    )


}

final class MockAuthRepository: AuthRepository, @unchecked Sendable {

    var loginResult: Result<AuthTokens, APIError> = .success(SampleData.tokens)
    var registerResult: Result<RegisterResponse, APIError> = .success(
        RegisterResponse(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, username: "raven")
    )
    var passwordResetResult: Result<Void, APIError> = .success(())
    var logoutResult: Result<Void, APIError> = .success(())

    private(set) var loginCallCount = 0
    private(set) var lastLoginUsername: String?
    private(set) var logoutCallCount = 0

    init() {}

    func login(username: String, password: String) async throws -> AuthTokens {
        loginCallCount += 1
        lastLoginUsername = username
        return try loginResult.get()
    }

    func register(_ request: RegisterRequest) async throws -> RegisterResponse {
        try registerResult.get()
    }

    func requestPasswordReset(email: String) async throws {
        try passwordResetResult.get()
    }

    func resetPassword(token: String, newPassword: String) async throws {
        try passwordResetResult.get()
    }

    func logout(refreshToken: String?) async throws {
        logoutCallCount += 1
        try logoutResult.get()
    }
}

final class MockUserRepository: UserRepository, @unchecked Sendable {

    var currentUserResult: Result<User, APIError> = .success(SampleData.user)
    var uploadResult: Result<User, APIError> = .success(SampleData.user)

    private(set) var currentUserCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var registeredPushToken: String?

    init() {}

    func currentUser() async throws -> User {
        currentUserCallCount += 1
        return try currentUserResult.get()
    }

    func updateProfile(_ user: User) async throws -> User {
        user
    }

    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User {
        uploadCallCount += 1
        return try uploadResult.get()
    }

    func registerForPushNotifications(token: String) async throws {
        registeredPushToken = token
    }

    func unregisterForPushNotifications(token: String) async throws {
        registeredPushToken = nil
    }
}


actor MockImageLoader: ImageLoading {

    private(set) var evictedURLs: [URL] = []

    init() {}

    func image(for url: URL) async throws -> UIImage {
        throw ImageLoaderError.invalidImageData
    }

    func evict(_ url: URL) async {
        evictedURLs.append(url)
    }

    func clear() async {
        evictedURLs.removeAll()
    }

    func trimMemory() async {}
}

#endif
