//
//  AppNavigator.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation
import os

// Owns which tab is showing and each tab's own stack, so a deep link can reach any screen without
// a view having to reach into another view's state.
@Observable
@MainActor
final class AppNavigator {

    var tab: AppTab = .events

    let events = Router<EventsRoute>()
    let myEvents = Router<MyEventsRoute>()

    @ObservationIgnored private let parser: DeepLinkParser

    // A link can arrive while nobody is signed in. Holding it beats dropping it, since the user is
    // usually about to sign in precisely because they tapped it.
    private var pendingLink: DeepLink?

    init(parser: DeepLinkParser = DeepLinkParser()) {
        self.parser = parser
    }

    func open(_ url: URL, isSignedIn: Bool) {
        guard let link = parser.parse(url) else {
            AppLogger.navigation.debug("Ignoring a URL that is not a deep link")
            return
        }

        guard isSignedIn || link.isPublic else {
            pendingLink = link
            return
        }
        follow(link)
    }

    // Call once a session exists, so a link that arrived on the sign-in screen still lands.
    func resumePendingLink() {
        guard let pendingLink else { return }
        self.pendingLink = nil
        follow(pendingLink)
    }

    private func follow(_ link: DeepLink) {
        AppLogger.navigation.breadcrumb("Opening \(link.path)")
        tab = link.tab

        switch link {
        case .events:
            events.popToRoot()
        case let .event(id):
            events.showUnique(.eventDetail(id: id))
        case .myEvents:
            myEvents.popToRoot()
        }
    }
}
