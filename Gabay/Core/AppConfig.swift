//
//  AppConfig.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Values the xcconfigs set, read back through the generated Info.plist.
enum AppConfig {

    // Where the trail catalog and its GPX files are published.
    static let catalogURL: URL = {
        guard let value = string("CATALOG_URL"), let url = URL(string: value) else {
            fatalError("CATALOG_URL is missing. Set it in Config/<Environment>.xcconfig.")
        }
        return url
    }()

    static let isEnvironmentBannerEnabled: Bool = bool("ENV_BANNER_ENABLED")

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }

    private static func bool(_ key: String) -> Bool {
        string(key)?.uppercased() == "YES"
    }
}
