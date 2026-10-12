//
//  AppTextField.swift
//  Gabay
//

import SwiftUI
import UIKit

struct AppTextField: View {

    @Binding var text: String

    var placeholder: String = ""
    var label: String?
    var error: String?

    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var contentType: UITextContentType?
    var disableAutocorrection: Bool = false
    var submitLabel: SubmitLabel = .return

    var body: some View {
        FieldContainer(label: label, error: error) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .autocorrectionDisabled(disableAutocorrection)
                .submitLabel(submitLabel)
                .accessibilityLabel(label.map(Text.init) ?? Text(placeholder))
        }
    }
}

// A failure that belongs to the whole form rather than to one field.
struct InlineErrorText: View {

    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Theme.Font.secondary)
            .foregroundStyle(Theme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct AsyncButton: View {

    let title: Text
    let isRunning: Bool
    let action: @Sendable () async -> Void

    var role: ButtonRole?

    var body: some View {
        Button(role: role) {
            Task { await action() }
        } label: {

            ZStack {
                title.opacity(isRunning ? 0 : 1)
                if isRunning {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isRunning)
        .animation(Theme.Animation.content, value: isRunning)
        .accessibilityAddTraits(isRunning ? .updatesFrequently : [])
    }
}
