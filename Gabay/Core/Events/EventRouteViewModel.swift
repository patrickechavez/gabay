//
//  EventRouteViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation

// Owns only the drawn route. The event's distance, ascent and time arrive with the event itself, so
// they render whether or not this ever succeeds; a failure here costs the map and nothing else.
@Observable
@MainActor
final class EventRouteViewModel: LoadableViewModel {

    var state: LoadState<[TrackPoint]> = .idle

    // The same numbers the organizer's phone computed, recovered from the track itself. Used only
    // to fill what the event did not carry.
    var stats: RouteStats? { state.value.map(RouteStats.init(points:)) }

    @ObservationIgnored private let eventID: String
    @ObservationIgnored private let events: any EventBrowsingRepository
    @ObservationIgnored private let parser: GPXParser

    init(eventID: String, events: any EventBrowsingRepository, parser: GPXParser = GPXParser()) {
        self.eventID = eventID
        self.events = events
        self.parser = parser
    }

    func load() async {
        guard state.needsLoad else { return }
        await fetch()
    }

    func retry() async {
        state = .idle
        await fetch()
    }

    private func fetch() async {
        // Fewer than two points draws no line, so that is nothing to show rather than a route.
        await perform(isEmpty: { $0.count < 2 }) { [eventID, events, parser] in
            let data = try await events.gpx(eventID: eventID)

            // Parsing a long track is not main-actor work.
            return try await Task.detached(priority: .userInitiated) {
                try parser.parse(data).points
            }.value
        }
    }
}
