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
final class EventRouteViewModel {

    private(set) var route: LoadState<[TrackPoint]> = .idle

    @ObservationIgnored private let eventID: String
    @ObservationIgnored private let events: any EventBrowsingRepository
    @ObservationIgnored private let parser: GPXParser

    init(eventID: String, events: any EventBrowsingRepository, parser: GPXParser = GPXParser()) {
        self.eventID = eventID
        self.events = events
        self.parser = parser
    }

    func load() async {
        guard route.needsLoad else { return }
        await fetch()
    }

    func retry() async {
        route = .idle
        await fetch()
    }

    private func fetch() async {
        route = .loading

        do {
            let data = try await events.gpx(eventID: eventID)
            let points = try parser.parse(data).points
            try Task.checkCancellation()
            route = .from(points)
        } catch {
            let apiError = APIError.classify(error)

            // A cancelled load goes back to `.idle` so returning to the screen tries again.
            if apiError == .cancelled {
                route = .idle
                return
            }
            route = .failed(apiError)
        }
    }
}
