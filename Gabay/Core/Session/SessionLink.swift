//
//  SessionLink.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

/// Lets the networking layer end a session. Weak, or the two would keep each
/// other alive; set once in `AppDependencies.live()`.
@MainActor
final class SessionLink {

    weak var session: SessionManager?

    init() {}
}
