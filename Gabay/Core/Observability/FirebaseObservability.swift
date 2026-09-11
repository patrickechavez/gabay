//
//  FirebaseObservability.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import os

// The only file that imports Firebase. To remove it, see the README.
enum FirebaseBootstrap {

    // nil when there is no GoogleService-Info.plist — a fresh clone.
    static func start() -> (analytics: any AnalyticsTracking, crashes: any CrashReporting)? {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            AppLogger.lifecycle.notice("No Firebase plist — analytics and crash reporting are off.")
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
