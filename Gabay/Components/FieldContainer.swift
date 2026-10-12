//
//  FieldContainer.swift
//  Gabay
//

import SwiftUI

// The label, box and error message every text field sits inside.
struct FieldContainer<Content: View>: View {
    let label: String?
    let error: String?
    @ViewBuilder let content: () -> Content

    private var hasError: Bool { !(error ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let label {
                Text(label)
                    .font(Theme.Font.fieldLabel)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            HStack(spacing: Theme.Spacing.sm) {
                content()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        hasError ? Theme.Color.danger : Theme.Color.separator,
                        lineWidth: 1
                    )
            )

            if hasError, let error {
                Text(error)
                    .font(Theme.Font.fieldError)
                    .foregroundStyle(Theme.Color.danger)
            }
        }
    }
}
