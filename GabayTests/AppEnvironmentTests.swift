//
//  AppEnvironmentTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

struct AppEnvironmentTests {

    // Fails if the compilation conditions or the #if ladder break.
    @Test func resolvesTheBuildConfiguration() {
        #expect(AppEnvironment.current == .development)
    }

    @Test func labelsDevelopmentAndStaging() {
        #expect(AppEnvironment.development.label == "dev")
        #expect(AppEnvironment.staging.label == "staging")
    }

    @Test func showsNoLabelInProduction() {
        #expect(AppEnvironment.production.label == nil)
    }
}
