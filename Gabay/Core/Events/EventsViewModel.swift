//
//  EventsViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class EventsViewModel: LoadableViewModel {

    var state: LoadState<[Event]> = .idle

    private(set) var mine: [Event] = []

    // Ids the hiker has joined, kept alongside `mine` so a row's button
    // updates the moment Join is tapped, without waiting on a refresh.
    private(set) var joined: Set<String> = []

    @ObservationIgnored let events: any EventFetching
    @ObservationIgnored private let session: Session
    @ObservationIgnored private var hasLoaded = false

    init(events: any EventFetching, session: Session) {
        self.events = events
        self.session = session
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        await perform { try await self.fetchEvents() }
        await loadMine()
    }

    func refresh() async {
        await perform(isRefresh: true) { try await self.fetchEvents() }
        await loadMine()
    }

    func join(_ event: Event) async {
        do {
            try await events.join(event.id)
            joined.insert(event.id)
        } catch APIError.unauthorized {
            await session.signOut()
        } catch {
            // A soft RSVP; a failure here isn't worth blocking the hiker,
            // who is about to leave the app for the payment link anyway.
        }
    }

    private func fetchEvents() async throws -> [Event] {
        do {
            return try await events.events()
        } catch APIError.unauthorized {
            await session.signOut()
            throw CancellationError()
        }
    }

    private func loadMine() async {
        do {
            mine = try await events.mine()
            joined = Set(mine.map(\.id))
        } catch APIError.unauthorized {
            await session.signOut()
        } catch {
            // Left as-is; `state` already reports the list's own failure.
        }
    }
}
