//
//  PreviewHost.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

#if DEBUG

import SwiftUI

// Signs in for real, then hands the screen a real, working AppDependencies.
struct PreviewHost<Content: View>: View {

    @ViewBuilder let content: (AppDependencies) -> Content

    // In-memory so a preview doesn't leave a real token in the Mac's keychain.
    @State private var dependencies = AppDependencies.live(tokenStore: InMemoryTokenStore())
    @State private var isSignedIn = false

    var body: some View {
        Group {
            if isSignedIn {
                content(dependencies)
                    .environment(AppNavigator())
            } else {
                ProgressView()
            }
        }
        .task {
            // Placeholder credentials — swap for a real account on your backend.
            let login = dependencies.makeLoginViewModel()
            login.email = "preview@example.com"
            login.password = "password"
            await login.signIn()

            isSignedIn = true
        }
    }
}

#endif
