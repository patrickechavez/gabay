//
//  Breadcrumb.swift
//  Gabay
//  Created by John Patrick Echavez on 9/8/26.
//

import Foundation
import os

// Console logs never reach a crash report, so notable events go to both.
enum Breadcrumb {

    // Not behind @MainActor Observability — most breadcrumbs drop off the main actor.
    private static let reporter = OSAllocatedUnfairLock<any CrashReporting>(
        initialState: NoopCrashReporter()
    )

    // Called once, from Observability.install.
    static func install(_ crashes: any CrashReporting) {
        reporter.withLock { $0 = crashes }
    }

    static func record(_ message: String) {
        reporter.withLock { $0 }.log(message)
    }
}

extension Logger {

    // Logs to Console and leaves the same line on the next crash report.
    func breadcrumb(_ message: String) {
        notice("\(message, privacy: .public)")
        Breadcrumb.record(message)
    }
}
