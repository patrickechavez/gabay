//
//  EmailField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit

// Text field preset for email: email keyboard, no autocapitalization, autofill.
struct EmailField: View {

    @Binding var text: String

    var label: String? = String(localized: "Email", comment: "Label for the email field")
    var error: String?
    var isRequired: Bool = false

    var body: some View {
        AppTextField(
            text: $text,
            placeholder: String(localized: "name@example.com", comment: "Placeholder for the email field"),
            label: label,
            error: error,
            isRequired: isRequired,
            keyboard: .emailAddress,
            capitalization: .never,
            contentType: .emailAddress,
            disableAutocorrection: true
        )
    }
}
