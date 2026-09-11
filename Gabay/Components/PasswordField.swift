//
//  PasswordField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit

// Password field with a reveal button; set isNewPassword when signing up.
struct PasswordField: View {

    @Binding var text: String

    var label: String? = String(localized: "Password", comment: "Label for the password field")
    var error: String?
    var isRequired: Bool = false
    var isNewPassword: Bool = false
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(isNewPassword ? .newPassword : .password)
            .focused($isFocused)
            .accessibilityLabel(label.map(Text.init) ?? Text(placeholder))

            Button {
                isRevealed.toggle()

                isFocused = true
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isRevealed
                    ? Text("Hide password", comment: "Accessibility label for the password reveal toggle")
                    : Text("Show password", comment: "Accessibility label for the password reveal toggle")
            )
        }
    }

    private var placeholder: String {
        String(localized: "Password", comment: "Placeholder for the password field")
    }
}
