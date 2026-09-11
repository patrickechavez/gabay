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
}
