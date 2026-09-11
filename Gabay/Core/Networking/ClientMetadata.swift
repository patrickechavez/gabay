//
//  ClientMetadata.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

protocol RequestMetadataProviding: Sendable {
    var headers: [String: String] { get }
}

struct ClientMetadata: RequestMetadataProviding {

    var headers: [String: String] { Self.cachedHeaders }

    private static let cachedHeaders: [String: String] = [
        "X-App-Version": appVersion,
        "X-App-Build": appBuild,
        "X-Platform": platform,
        "X-OS-Version": osVersion,
        "X-Device-Model": deviceModel
    ]

    static let appVersion = bundleValue("CFBundleShortVersionString")

    static let appBuild = bundleValue("CFBundleVersion")

    static let platform = "iOS"

    static let osVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion > 0 ? "\(base).\(version.patchVersion)" : base
    }()

    static let deviceModel: String = {
        if let simulator = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulator
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }()

    private static func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unknown"
    }
}
