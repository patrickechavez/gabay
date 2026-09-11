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

    private(set) var isLoading = false

    private(set) var failure: LoadFailure?

    @ObservationIgnored private let store: any TrailStoring

    init(store: any TrailStoring) {
        self.store = store
    }

    // Reading every file to measure it is slow enough to notice: a long walk
    // is megabytes of XML. None of it belongs on the main actor.
    func load() async {
        guard trails.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let store = self.store
        trails = await Task.detached { (try? store.trails()) ?? [] }.value
    }

    // A trail somebody imported is theirs to throw away again.
    func remove(_ trail: Trail) {
        guard let index = trails.firstIndex(where: { $0.id == trail.id }) else { return }

        do {
            try store.remove(trail)
            trails.remove(at: index)
        } catch {
            failure = .unavailable
        }
    }

    func points(of trail: Trail) async -> [TrackPoint] {
        let store = self.store
        return await Task.detached { (try? store.points(of: trail)) ?? [] }.value
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
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.trails.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle(Text("Trails", comment: "Title of the trail list"))
            .toolbar {
                // Only once there is a list. An empty screen offers the import
                // as its own button, and two of them says it twice.
                if !viewModel.trails.isEmpty {
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
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.gpx, .xml, .data],
                onCompletion: viewModel.import
            )
            .task { await viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.trails) { trail in
            NavigationLink {
                // Points are read when the screen opens, not when the row is
                // built, or opening the list parses every file.
                TrailDetailView(trail: trail) { await viewModel.points(of: trail) }
            } label: {
                row(trail)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    viewModel.remove(trail)
                } label: {
                    Label {
                        Text("Delete", comment: "Removes an imported trail from the phone")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func row(_ trail: Trail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(trail.name)
                .font(Theme.Font.body)

            // Distance and climb are both in metres on a short trail, so they
            // need naming or the row reads as two of the same number.
            HStack(spacing: Theme.Spacing.md) {
                Text("\(trail.formattedDistance) far",
                     comment: "How long a trail is, shown under its name")

                if let ascent = trail.formattedAscent {
                    Text("\(ascent) up",
                         comment: "How much a trail climbs, shown under its name")
                } else {
                    Text("no elevation",
                         comment: "Shown when a trail's file carries no heights")
                }

                if !trail.region.isEmpty {
                    Text(trail.region)
                }
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.secondaryText)
        }
        .padding(.vertical, 3)
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
