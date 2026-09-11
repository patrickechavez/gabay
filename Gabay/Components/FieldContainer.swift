//
//  FieldContainer.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// The label, box and error message every text field sits inside.
struct FieldContainer<Content: View>: View {
    let label: String?
    let isRequired: Bool
    let error: String?
    @ViewBuilder let content: () -> Content

    private var hasError: Bool { !(error ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let label {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(label)
                    if isRequired { Text("*").foregroundStyle(Theme.Color.danger) }
                }
                .font(Theme.Font.fieldLabel)
                .foregroundStyle(Theme.Color.secondaryText)
            }

            HStack(spacing: Theme.Spacing.sm) {
                content()
                if isRequired && label == nil {
                    Text("*").foregroundStyle(Theme.Color.danger)
                }
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
