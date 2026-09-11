//
//  LoadFailure.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// Why something did not load, in the only terms a screen can act on.
enum LoadFailure: Error, Equatable {
    case cancelled
    case offline
    case timedOut
    case unavailable
    case unknown

    static func classify(_ error: any Error) -> LoadFailure {
        if error is CancellationError { return .cancelled }

        guard let url = error as? URLError else { return .unknown }

        switch url.code {
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .offline
        default: return .unavailable
        }
    }

    // A cancelled load is the app's doing, not something to put on screen.
    var isUserFacing: Bool { self != .cancelled }

    var isRetryable: Bool { self != .cancelled }
}
