//
//  APIRoute.swift
//  Gabay
//

import Foundation

enum APIRoute {

    enum Auth {
        static let register = "auth/register"
        static let login = "auth/login"
        static let refresh = "auth/refresh"
        static let currentUser = "me"
    }

    enum Events {
        static let list = "events"
        static let mine = "me/events"
        static func gpx(_ id: String) -> String { "events/\(id)/gpx" }
        static func join(_ id: String) -> String { "events/\(id)/join" }
    }
}
