//
//  UsernameField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit

// Text field preset for usernames: no autocapitalization, no autocorrect, autofill.
struct UsernameField: View {

    @Binding var text: String

    var label: String? = String(localized: "Username", comment: "Label for the username field")
    var error: String?
    var isRequired: Bool = false

    var body: some View {
        AppTextField(
            text: $text,
            placeholder: String(localized: "Username", comment: "Placeholder for the username field"),
            label: label,
            error: error,
            isRequired: isRequired,
            capitalization: .never,
            contentType: .username,
            disableAutocorrection: true
        )
    }
}
