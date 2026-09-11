//
//  AppEnvironment.swift
//  Gabay
//  Created by John Patrick Echavez on 9/8/26.
//

import Foundation

// Which configuration is running, resolved from the flags the xcconfigs set.
enum AppEnvironment {

    case development
    case staging
    case production

    static let current: AppEnvironment = {
        #if DEVELOPMENT
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }()

    // nil in Production, which shows no ribbon.
    var label: String? {
        switch self {
        case .development: "dev"
        case .staging: "staging"
        case .production: nil
        }
    }
}
