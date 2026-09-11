//
//  DateField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Tap to open a calendar sheet; the optional binding allows a placeholder.
struct DateField: View {

    let label: String

    @Binding var date: Date?

    var placeholder: String
    var error: String?
    var isRequired: Bool = false
    var isEnabled: Bool = true

    // Limits the selectable dates when set.
    var range: ClosedRange<Date>?

    private let format: DateFormat
    private let formatter: DateFormatter

    @State private var isPresented = false

    init(
        label: String,
        date: Binding<Date?>,
        format: DateFormat = .monthDayYear,
        placeholder: String = String(localized: "Select", comment: "Placeholder for a date field"),
        error: String? = nil,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        range: ClosedRange<Date>? = nil
    ) {
        self.label = label
        _date = date
        self.format = format
        self.placeholder = placeholder
        self.error = error
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.range = range

        let formatter = DateFormatter()
        formatter.dateFormat = format.pattern
        // Current locale, not POSIX — month and weekday names stay localised.
        formatter.locale = Locale.current
        self.formatter = formatter
    }

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Button {
                isPresented = true
            } label: {
                HStack {
                    Text(date.map(formatter.string(from:)) ?? placeholder)
                        .foregroundStyle(
                            date == nil ? Theme.Color.tertiaryText : Theme.Color.primaryText
                        )

                    Spacer()

                    Image(systemName: format.components == .hourAndMinute ? "clock" : "calendar")
                        .font(.footnote)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                // Spacer() is not hit-testable, so give the whole row a shape to tap.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityLabel(Text(label))
        }
        .sheet(isPresented: $isPresented) {
            DateSheet(title: label, date: $date, components: format.components, range: range)
        }
    }
}

// Kept file-private: nothing outside DateField presents it.
private struct DateSheet: View {

    let title: String
    @Binding var date: Date?
    var components: DatePicker.Components
    var range: ClosedRange<Date>?

    // Edits stay local until Done, so Cancel leaves the binding untouched.
    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        date: Binding<Date?>,
        components: DatePicker.Components = .date,
        range: ClosedRange<Date>? = nil
    ) {
        self.title = title
        _date = date
        self.components = components
        self.range = range
        _selection = State(wrappedValue: date.wrappedValue ?? Date())
    }

    var body: some View {
        NavigationStack {
            VStack {
                styledPicker
                    .labelsHidden()

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Dismisses the date picker without choosing")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        date = selection
                        dismiss()
                    } label: {
                        Text("Done", comment: "Confirms the chosen date")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // The calendar grid has nothing to show when only a time is wanted.
    @ViewBuilder
    private var styledPicker: some View {
        if components == .hourAndMinute {
            picker.datePickerStyle(.wheel)
        } else {
            picker.datePickerStyle(.graphical)
        }
    }

    @ViewBuilder
    private var picker: some View {
        if let range {
            DatePicker("", selection: $selection, in: range, displayedComponents: components)
        } else {
            DatePicker("", selection: $selection, displayedComponents: components)
        }
    }
}
