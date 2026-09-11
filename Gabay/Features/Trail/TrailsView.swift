//
//  TrailsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class TrailsViewModel {

    private(set) var trails: [Trail] = []

    private(set) var failure: LoadFailure?

    @ObservationIgnored private let store: any TrailStoring

    init(store: any TrailStoring) {
        self.store = store
    }

    func load() {
        trails = (try? store.trails()) ?? []
    }

    func points(of trail: Trail) -> [TrackPoint] {
        (try? store.points(of: trail)) ?? []
    }

    // A file from anywhere: Files, an email attachment, AirDrop.
    func `import`(_ result: Result<URL, any Error>) {
        guard case let .success(url) = result else { return }

        do {
            let trail = try store.importFile(at: url)
            trails.append(trail)
            trails.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            failure = nil
        } catch {
            failure = .unavailable
        }
    }
}

struct TrailsView: View {

    @State private var viewModel: TrailsViewModel
    @State private var isImporting = false

    init(viewModel: TrailsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trails.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle(Text("Trails", comment: "Title of the trail list"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Import a GPX file",
                                             comment: "Adds a trail from the user's own files"))
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.gpx, .xml, .data],
                onCompletion: viewModel.import
            )
            .task { viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.trails) { trail in
            NavigationLink {
                TrailDetailView(trail: trail, points: viewModel.points(of: trail))
            } label: {
                row(trail)
            }
        }
        .listStyle(.plain)
    }

    private func row(_ trail: Trail) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(trail.name)
                .font(Theme.Font.body)

            Text(verbatim: [trail.region, trail.formattedDistance, trail.formattedAscent]
                .filter { !$0.isEmpty }
                .joined(separator: " · "))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .padding(.vertical, 2)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label {
                Text("No trails yet", comment: "Shown when nothing has been downloaded or imported")
            } icon: {
                Image(systemName: "figure.hiking")
            }
        } description: {
            Text("Import a GPX file to walk it.",
                 comment: "What to do when the trail list is empty")
        } actions: {
            Button {
                isImporting = true
            } label: {
                Text("Import a GPX file", comment: "Adds a trail from the user's own files")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

extension UTType {

    // GPX is not one of Apple's declared types, so the app names it itself.
    static let gpx = UTType(filenameExtension: "gpx") ?? .xml
}
