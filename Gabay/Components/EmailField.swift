//
//  EmailField.swift
//  Gabay
//

import SwiftUI
import UIKit

// Text field preset for email: email keyboard, no autocapitalization, autofill.
struct EmailField: View {

    @Binding var text: String

    var label: String? = String(localized: "Email", comment: "Label for the email field")
    var error: String?

    var body: some View {
        AppTextField(
            text: $text,
            placeholder: String(localized: "name@example.com", comment: "Placeholder for the email field"),
            label: label,
            error: error,
            keyboard: .emailAddress,
            capitalization: .never,
            contentType: .emailAddress,
            disableAutocorrection: true
        )
    }
}
