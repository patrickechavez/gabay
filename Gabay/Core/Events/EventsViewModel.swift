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
    @ObservationIgnored private var hasLoaded = false

    init(events: any EventFetching) {
        self.events = events
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
        } catch {
            // A soft RSVP; a failure here isn't worth blocking the hiker,
            // who is about to leave the app for the payment link anyway.
        }
    }

    private func fetchEvents() async throws -> [Event] {
        try await events.events()
    }

    private func loadMine() async {
        do {
            mine = try await events.mine()
            joined = Set(mine.map(\.id))
        } catch {
            // Left as-is; `state` already reports the list's own failure.
        }
    }
}
