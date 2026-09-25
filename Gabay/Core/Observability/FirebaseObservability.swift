//
//  FirebaseObservability.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation
import os

// The only file that imports Firebase.
//
// Two gates, not one. The `canImport` gate is a build-time check: the SDK is not in the Xcode
// project yet, so without it this file would not compile. Add the package (see the README) and the
// real implementation below takes over with no other change. The plist check is a run-time gate, so
// a checkout without GoogleService-Info.plist behaves exactly as it does today.
#if canImport(FirebaseCore)

import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics

enum FirebaseBootstrap {

    // nil when there is no GoogleService-Info.plist, which is a fresh clone.
    static func start() -> (analytics: any AnalyticsTracking, crashes: any CrashReporting)? {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            AppLogger.lifecycle.notice("No Firebase plist, analytics and crash reporting are off.")
            return nil
        }

        FirebaseApp.configure()
        return (FirebaseAnalyticsTracker(), FirebaseCrashReporter())
    }
}

struct FirebaseAnalyticsTracker: AnalyticsTracking {

    func track(_ event: String, parameters: [String: String]) {
        Analytics.logEvent(event, parameters: parameters.isEmpty ? nil : parameters)
    }

    func setUser(id: String?) {
        Analytics.setUserID(id)
    }
}

struct FirebaseCrashReporter: CrashReporting {

    func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    func setUser(id: String?) {
        Crashlytics.crashlytics().setUserID(id)
    }
}

#else

// The SDK is not linked into this target. `AppDependencies` falls back to the no-op trackers, which
// is what the app does today.
enum FirebaseBootstrap {

    static func start() -> (analytics: any AnalyticsTracking, crashes: any CrashReporting)? {
        AppLogger.lifecycle.notice("Firebase SDK is not linked, analytics and crash reporting are off.")
        return nil
    }
}

#endif
