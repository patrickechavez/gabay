//
//  DeepLink.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation

// Somewhere in the app a URL can open. Only the custom scheme is handled: universal links need a
// registered domain and an associated-domains entitlement, and this app has neither yet.
enum DeepLink: Equatable, Sendable {
    case events
    case event(id: String)
    case myEvents

    // Every destination is behind the sign-in wall, so a link that arrives while signed out is
    // held until there is a session rather than opened.
    var isPublic: Bool { false }

    var path: String {
        switch self {
        case .events: "/events"
        case let .event(id): "/events/\(id)"
        case .myEvents: "/my-events"
        }
    }

    var tab: AppTab {
        switch self {
        case .events, .event: .events
        case .myEvents: .myEvents
        }
    }
}

struct DeepLinkParser: Sendable {

    private let scheme: String

    init(scheme: String = APIConfig.urlScheme) {
        self.scheme = scheme.lowercased()
    }

    func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme?.lowercased() == scheme else {
            return nil
        }

        // In gabay://events/123 the first segment is the host, not part of the path.
        let segments = ([components.host] + components.path.split(separator: "/").map(String.init))
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        // Only the route word is case-normalised, because URLComponents does not normalise host
        // case for a custom scheme and `gabay://Events` should still work. The id is left alone:
        // it is a server-issued string and may well be case sensitive.
        switch segments.first?.lowercased() {
        case "events":
            guard let id = segments.dropFirst().first else { return .events }
            return .event(id: id)
        case "my-events":
            return .myEvents
        default:
            return nil
        }
    }
}
