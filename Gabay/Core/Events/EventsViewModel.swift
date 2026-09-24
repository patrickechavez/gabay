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

    // Its own `LoadState`, not just an array, so `MyEventsView` can tell loading/failed/empty apart instead of showing the empty copy for all three.
    private(set) var mineState: LoadState<[Event]> = .idle

    // Ids the hiker has joined, kept alongside `mineState` so a row's button updates the moment Join is tapped, without waiting on a refresh.
    private(set) var joined: Set<String> = []

    @ObservationIgnored let events: any EventFetching
    @ObservationIgnored private var hasLoaded = false

    init(events: any EventFetching) {
        self.events = events
    }

    var mine: [Event] { mineState.value ?? [] }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        await perform { try await self.fetchEvents() }
        await loadMine()
    }

    func refresh() async {
        await perform(isRefresh: true) { try await self.fetchEvents() }
        await loadMine(isRefresh: true)
    }

    func join(_ event: Event) async {
        do {
            try await events.join(event.id)
            joined.insert(event.id)
        } catch {
            // A soft RSVP; a failure here isn't worth blocking the hiker, who is about to leave the app for the payment link anyway.
        }
    }

    private func fetchEvents() async throws -> [Event] {
        try await events.events()
    }

    private func loadMine(isRefresh: Bool = false) async {
        if !isRefresh, mineState.value == nil {
            mineState = .loading
        }

        do {
            let fetched = try await events.mine()
            try Task.checkCancellation()
            mineState = .from(fetched)
            joined = Set(fetched.map(\.id))
        } catch {
            let apiError = APIError.classify(error)

            // A cancelled first load goes back to `.idle` so the view can retry.
            if apiError == .cancelled, case .loading = mineState {
                mineState = .idle
                return
            }

            guard apiError.isUserFacing else { return }

            // Failing silently while refreshing content that's already visible.
            if isRefresh, mineState.value != nil { return }

            mineState = .failed(apiError)
        }
    }
}
