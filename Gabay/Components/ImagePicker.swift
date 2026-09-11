//
//  ImagePicker.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import PhotosUI
import SwiftUI
import os

struct ImagePicker<Label: View>: View {

    @Binding var image: UIImage?
    @ViewBuilder var label: @Sendable () -> Label
    var onError: ((any Error) -> Void)?

    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            label()
        }
        .task(id: selection) {
            await loadSelection()
        }
    }

    private func loadSelection() async {
        guard let selection else { return }

        do {
            guard let data = try await selection.loadTransferable(type: Data.self) else { return }

            let decoded = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value

            guard !Task.isCancelled, let decoded else { return }
            image = decoded
        } catch {
            AppLogger.images.error("Could not load picked photo: \(error.localizedDescription, privacy: .public)")
            onError?(error)
        }
    }
}

