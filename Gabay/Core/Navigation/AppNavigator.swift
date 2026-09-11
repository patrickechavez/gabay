//
//  AppNavigator.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Observation
import SwiftUI
import os

@Observable
@MainActor
final class AppNavigator {

    var selectedTab: AppTab = .home

    let home = Router<HomeRoute>()
    let favorites = Router<FavoritesRoute>()
    let profile = Router<ProfileRoute>()
    let settings = Router<SettingsRoute>()
    let auth = Router<AuthRoute>()

    private(set) var pendingLink: DeepLink?

    @ObservationIgnored private let parser: DeepLinkParser

    init(parser: DeepLinkParser = DeepLinkParser()) {
        self.parser = parser
    }

    @discardableResult
    func open(_ url: URL, isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(url) else {
            AppLogger.navigation.breadcrumb("Ignoring unhandled URL: \(url.absoluteString)")
            return false
        }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    @discardableResult
    func open(notification payload: [AnyHashable: Any], isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(notificationPayload: payload) else { return false }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    func open(_ link: DeepLink, isAuthenticated: Bool) {
        guard isAuthenticated || link.isPublic else {

            AppLogger.navigation.breadcrumb("Deferring deep link until signed in: \(link.path)")
            pendingLink = link
            return
        }

        apply(link)
    }

    func resumePendingLink() {
        guard let link = pendingLink else { return }
        pendingLink = nil
        AppLogger.navigation.breadcrumb("Resuming deferred deep link: \(link.path)")
        apply(link)
    }

    func clearPendingLink() {
        pendingLink = nil
    }

    func reset() {
        selectedTab = .home
        home.popToRoot()
        favorites.popToRoot()
        profile.popToRoot()
        settings.popToRoot()
        auth.popToRoot()
        pendingLink = nil
    }

    private func apply(_ link: DeepLink) {
        switch link {
        case .home:
            selectedTab = .home
            home.popToRoot()

        case let .item(id):
            selectedTab = .home

            home.set([.itemDetail(id: id)])

        case .profile:
            selectedTab = .profile
            profile.popToRoot()

        case .settings:
            selectedTab = .settings
            settings.popToRoot()

        case let .resetPassword(token):

            auth.set([.resetPassword(token: token)])
        }
    }
}
