//
//  PickerField.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Tap to pick from a searchable sheet; items only need Hashable.
struct PickerField<Item: Hashable>: View {

    let label: String

    let items: [Item]
    @Binding var selection: Item?

    // How each item is drawn; subtitle is optional second line.
    let title: (Item) -> String
    var subtitle: ((Item) -> String)?

    var placeholder: String = String(localized: "Select", comment: "Placeholder for a picker field")
    var error: String?
    var isRequired: Bool = false
    var isEnabled: Bool = true

    @State private var isPresented = false

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Button {
                isPresented = true
            } label: {
                HStack {
                    Text(selection.map(title) ?? placeholder)
                        .foregroundStyle(
                            selection == nil ? Theme.Color.tertiaryText : Theme.Color.primaryText
                        )

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
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
            .accessibilityValue(selection.map(title) ?? placeholder)
        }
        .sheet(isPresented: $isPresented) {
            SelectionSheet(
                title: label,
                items: items,
                selection: $selection,
                rowTitle: title,
                rowSubtitle: subtitle
            )
        }
    }
}

// Also used by PhoneField for its country picker.
struct SelectionSheet<Item: Hashable>: View {

    let title: String
    let items: [Item]
    @Binding var selection: Item?

    let rowTitle: (Item) -> String
    var rowSubtitle: ((Item) -> String)?

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var matches: [Item] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return items }
        return items.filter { rowTitle($0).localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        NavigationStack {
            List(matches, id: \.self) { item in
                Button {
                    selection = item
                    dismiss()
                } label: {
                    row(for: item)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(
                text: $query,
                prompt: Text("Search", comment: "Prompt for the picker's search field")
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Dismisses the picker without choosing")
                    }
                }
            }
        }
    }

    private func row(for item: Item) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                Text(rowTitle(item))
                    .foregroundStyle(Theme.Color.primaryText)

                if let rowSubtitle {
                    Text(rowSubtitle(item))
                        .font(Theme.Font.secondary)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }

            Spacer()

            if item == selection {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.Color.accent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item == selection ? .isSelected : [])
    }
}
