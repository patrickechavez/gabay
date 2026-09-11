//
//  SessionManager.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class SessionManager {

    enum State: Equatable {

        case bootstrapping
        case unauthenticated
        case authenticated
    }

    private(set) var state: State = .bootstrapping

    private(set) var currentUser: User?

    private(set) var serviceStatus: ServiceStatus?

    enum ServiceStatus: Equatable {
        case updateRequired(message: String?)
        case maintenance(message: String?)
    }

    @ObservationIgnored private let tokenStore: any TokenStore
    @ObservationIgnored private let users: any UserRepository
    @ObservationIgnored private let crashes: any CrashReporting

    init(
        tokenStore: any TokenStore,
        users: any UserRepository,
        crashes: any CrashReporting = NoopCrashReporter()
    ) {
        self.tokenStore = tokenStore
        self.users = users
        self.crashes = crashes
    }

    func bootstrap() async {
        guard await tokenStore.load() != nil else {
            state = .unauthenticated
            return
        }

        do {
            setCurrentUser(try await users.currentUser())
            state = .authenticated
            AppLogger.lifecycle.breadcrumb("Resumed existing session")
        } catch let error as APIError where error.invalidatesSession {

            await signOut()
        } catch {

            AppLogger.lifecycle.breadcrumb(
                "Could not verify session (\(error.localizedDescription)); continuing optimistically."
            )
            state = .authenticated
        }
    }

    func didAuthenticate(tokens: AuthTokens, user: User? = nil) async {
        do {
            try await tokenStore.save(tokens)
        } catch {

            AppLogger.auth.error("Could not persist tokens: \(error.localizedDescription, privacy: .public)")
        }

        setCurrentUser(user)
        state = .authenticated

        if user == nil {

            Task { await refreshCurrentUser() }
        }
    }

    func signOut() async {
        await tokenStore.clear()
        setCurrentUser(nil)
        state = .unauthenticated
        AppLogger.lifecycle.breadcrumb("Signed out")
    }

    func refreshCurrentUser() async {
        guard state == .authenticated else { return }
        setCurrentUser(try? await users.currentUser())
    }

    func update(user: User) {
        setCurrentUser(user)
    }

    /// Keeps the crash reporter's user ID in step with the session.
    private func setCurrentUser(_ user: User?) {
        currentUser = user
        crashes.setUser(id: user.map { $0.id.uuidString })
    }

    func dismissServiceStatus() {
        serviceStatus = nil
    }

    /// Called when tokens can't be refreshed; ends the session if it hasn't ended.
    func expire() async {
        guard state == .authenticated else { return }
        AppLogger.auth.breadcrumb("Session expired — returning to sign-in")
        await signOut()
    }

    /// Called when the backend says the app is too old or down for maintenance.
    func show(serviceStatus: ServiceStatus) {
        self.serviceStatus = serviceStatus
    }
}
