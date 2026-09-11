//
//  EnvironmentRibbon.swift
//  Gabay
//  Created by John Patrick Echavez on 9/8/26.
//

import SwiftUI

// Names the environment in the corner, the way Flutter's debug banner does.
//
// Bottom leading rather than top trailing: the top right corner belongs to the
// navigation bar, and a ribbon there covers whatever button is in it.
struct EnvironmentRibbon: View {

    let label: String

    let color: Color

    // Wide enough that the ends run off screen, leaving only the diagonal band.
    private let width: CGFloat = 150

    var body: some View {
        Text(label)
            .font(Theme.Font.caption)
            .foregroundStyle(.white)
            .frame(width: width)
            .padding(.vertical, Theme.Spacing.xs)
            .background(color)
            .rotationEffect(.degrees(45))
            .offset(x: -35, y: 30)
    }
}

extension View {

    /// Bottom-left ribbon naming the environment; compiled out of Production.
    func environmentRibbon() -> some View {
        #if PRODUCTION
        self
        #else
        overlay(alignment: .bottomLeading) {
            if AppConfig.isEnvironmentBannerEnabled, let label = AppEnvironment.current.label {
                EnvironmentRibbon(label: label, color: AppEnvironment.current.ribbonColor)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        #endif
    }
}

#if !PRODUCTION

extension AppEnvironment {

    // Staging is the one mistaken for production, so it gets the louder color.
    var ribbonColor: Color {
        switch self {
        case .development: Theme.Color.accent
        case .staging: Theme.Color.warning
        case .production: .clear
        }
    }
}

#endif

#if DEBUG

#Preview("Development") {
    Color(uiColor: .systemBackground)
        .overlay(alignment: .topTrailing) {
            EnvironmentRibbon(label: "dev", color: Theme.Color.accent)
        }
}

#Preview("Staging") {
    Color(uiColor: .systemBackground)
        .overlay(alignment: .topTrailing) {
            EnvironmentRibbon(label: "staging", color: Theme.Color.warning)
        }
}

#endif
