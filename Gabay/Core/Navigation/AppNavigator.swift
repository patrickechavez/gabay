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
    // usually about to sign in precisely because they tapped it. It carries the time it arrived so
    // a link tapped and abandoned does not fire days later on an unrelated sign-in.
    private var pendingLink: (link: DeepLink, arrived: Date)?

    private static let pendingLinkLifetime: TimeInterval = 600

    init(parser: DeepLinkParser = DeepLinkParser()) {
        self.parser = parser
    }

    func open(_ url: URL, isSignedIn: Bool) {
        guard let link = parser.parse(url) else {
            AppLogger.navigation.debug("Ignoring a URL that is not a deep link")
            return
        }

        guard isSignedIn || link.isPublic else {
            pendingLink = (link, Date())
            return
        }
        follow(link)
    }

    // Call once a session exists, so a link that arrived on the sign-in screen still lands.
    func resumePendingLink() {
        guard let pendingLink else { return }
        self.pendingLink = nil

        guard Date().timeIntervalSince(pendingLink.arrived) < Self.pendingLinkLifetime else {
            AppLogger.navigation.debug("Dropping a deep link that has gone stale")
            return
        }
        follow(pendingLink.link)
    }

    // Sign-out. AppDependencies is built once for the process, so without this the next account
    // inherits the previous one's selected tab and pushed screens.
    func reset() {
        tab = .events
        events.popToRoot()
        myEvents.popToRoot()
        pendingLink = nil
    }

    // The Post a Hike tab only exists for organizers. A selection naming a tab the TabView does not
    // contain shows a blank screen with no way to correct it.
    func leavePostEventTabIfPresent() {
        if tab == .postEvent { tab = .events }
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
