//
//  AppRoute.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation

protocol AppRoute: Hashable, Codable, Sendable, Identifiable {}

// Lets a route bind straight to .sheet(item:) and .fullScreenCover(item:).
extension AppRoute {
    var id: Self { self }
}

enum AppTab: String, Hashable, Codable, CaseIterable, Identifiable, Sendable {
    case events
    case myEvents
    case postEvent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .events:
            String(localized: "Events", comment: "Tab title for the list of cause-hike events")
        case .myEvents:
            String(localized: "My Events", comment: "Tab title for events the hiker has joined")
        case .postEvent:
            String(localized: "Post a Hike", comment: "Tab title for the organizer event-creation form")
        }
    }

    var systemImage: String {
        switch self {
        case .events: "figure.hiking"
        case .myEvents: "checkmark.circle"
        case .postEvent: "plus.circle"
        }
    }
}

// Each tab keeps its own route list, so its screens stack independently.
//
// Routes carry an event id rather than an Event. That is what lets a path be Codable and restored,
// and it is why Event no longer has to be Hashable just to be a navigation destination.
enum EventsRoute: AppRoute {
    case eventDetail(id: String)
}

enum MyEventsRoute: AppRoute {
    case eventDetail(id: String)
}
