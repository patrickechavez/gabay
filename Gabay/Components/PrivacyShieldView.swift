//
//  PrivacyShieldView.swift
//  Gabay
//  Created by John Patrick Echavez on 8/16/26.
//

import SwiftUI

// Hides the app's content when switching between apps for privacy.
struct PrivacyShieldView: View {

    var body: some View {
        Rectangle()
            .fill(Color("LaunchBackground"))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
