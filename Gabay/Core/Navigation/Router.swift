//
//  Router.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Observation
import SwiftUI

@Observable
@MainActor
final class Router<Route: AppRoute> {

    var path: [Route] = []

    var alert: AlertState?

    var sheet: Route?

    var cover: Route?

    init(path: [Route] = []) {
        self.path = path
    }

    var isAtRoot: Bool { path.isEmpty }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func set(_ routes: [Route]) {
        path = routes
    }

    func showUnique(_ route: Route) {
        if let index = path.firstIndex(of: route) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            push(route)
        }
    }

    func present(alert: AlertState) {
        self.alert = alert
    }

    func present(sheet route: Route) {
        sheet = route
    }

    func present(cover route: Route) {
        cover = route
    }

    func dismissSheet() {
        sheet = nil
    }

    func dismissCover() {
        cover = nil
    }

    var restorationData: Data? {
        try? JSONEncoder().encode(path)
    }

    func restore(from data: Data?) {
        guard let data, let routes = try? JSONDecoder().decode([Route].self, from: data) else {
            return
        }
        path = routes
    }
}
