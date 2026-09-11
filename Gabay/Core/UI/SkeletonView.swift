//
//  SkeletonView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct SkeletonView: View {

    var cornerRadius: CGFloat = Theme.Radius.sm

    @State private var isAnimating = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.Color.placeholder)
            .opacity(isAnimating ? 0.45 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityHidden(true)
    }
}
