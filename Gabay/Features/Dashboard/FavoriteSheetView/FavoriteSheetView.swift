//
//  FavoriteSheetView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/9/26.
//

import SwiftUI

// Takes a value in and hands one back through onSave.
struct FavoriteSheetView: View {

    let note: String

    let onSave: (String) -> Void

    @State private var draft: String

    @Environment(\.dismiss) private var dismiss

    init(note: String, onSave: @escaping (String) -> Void) {
        self.note = note
        self.onSave = onSave
        _draft = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(text: $draft) {
                    Text("Note", comment: "Label for the note field on the favorite sheet")
                }
            }
            .navigationTitle(Text("Edit Note", comment: "Title of the favorite sheet screen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Button that dismisses the favorite sheet without saving")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(draft)
                        dismiss()
                    } label: {
                        Text("Save", comment: "Button that saves the note and dismisses the favorite sheet")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG

#Preview {
    Color(uiColor: .systemBackground)
        .sheet(isPresented: .constant(true)) {
            FavoriteSheetView(note: "Weekend trip") { _ in }
        }
}

#endif
