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

    @State private var dependencies = AppDependencies.live()

    var body: some View {
        content(dependencies)
            .environment(AppNavigator())
    }
}

#endif
