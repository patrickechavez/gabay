//
//  SessionLink.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

/// Lets the networking layer end a session. Weak, or the two would keep each
/// other alive: `Session` owns `LiveAuthRepository`, which owns the client, which
/// owns the interceptor, which owns the coordinator. A strong reference back
/// would be a retain cycle. Set once in `AppDependencies.live()`.
@MainActor
final class SessionLink {

    weak var session: Session?

    init() {}
}
