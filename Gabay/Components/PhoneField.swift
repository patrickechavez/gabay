//
//  PhoneField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit

// Calling code plus national number; combine with country.e164(nationalNumber:).
struct PhoneField: View {

    @Binding var country: Country?
    @Binding var nationalNumber: String

    var label: String? = String(localized: "Phone", comment: "Label for the phone number field")
    var error: String?
    var isRequired: Bool = false

    @State private var isPresented = false

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            HStack(spacing: Theme.Spacing.sm) {
                countryButton

                Divider().frame(height: 22)

                TextField(
                    String(localized: "917 123 4567", comment: "Placeholder for the phone number field"),
                    text: $nationalNumber
                )
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .autocorrectionDisabled()
            }
        }
        .sheet(isPresented: $isPresented) {
            SelectionSheet(
                title: String(localized: "Country", comment: "Title of the country picker sheet"),
                items: Country.all,
                selection: $country,
                rowTitle: { "\($0.flag)  \($0.name)" },
                rowSubtitle: \.callingCode
            )
        }
        .task {
            // Default to the device's region; the picker can still change it.
            if country == nil { country = .deviceDefault }
        }
    }

    private var countryButton: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(country.map { "\($0.flag) \($0.callingCode)" } ?? "—")
                    .foregroundStyle(
                        country == nil ? Theme.Color.tertiaryText : Theme.Color.primaryText
                    )

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Country calling code", comment: "Accessibility label for the country code picker"))
        .accessibilityValue(country.map { "\($0.name) \($0.callingCode)" } ?? "")
    }
}
