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

    // The published catalog and this phone's files, in one list.
    private(set) var trails: [Trail] = []

    private(set) var isLoading = false

    private(set) var failure: LoadFailure?

    // Ids being fetched, so a row can spin without blocking the rest.
    private(set) var downloading: Set<String> = []

    @ObservationIgnored private let store: any TrailStoring
    @ObservationIgnored private let catalog: any TrailCatalogFetching
    @ObservationIgnored private let cache: any CatalogCaching

    @ObservationIgnored private var onDevice: [Trail] = []
    @ObservationIgnored private var entries: [String: CatalogTrail] = [:]
    @ObservationIgnored private var etag: String?
    @ObservationIgnored private var hasLoaded = false

    init(store: any TrailStoring, catalog: any TrailCatalogFetching, cache: any CatalogCaching) {
        self.store = store
        self.catalog = catalog
        self.cache = cache
    }

    // Dismisses the failure alert.
    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    // Measuring every file is megabytes of XML, so not on the main actor.
    func load() async {
        if !hasLoaded {
            hasLoaded = true
            isLoading = true

            let store = self.store
            onDevice = await Task.detached { (try? store.trails()) ?? [] }.value
            if let cached = cache.load() { adopt(cached) }

            rebuild()
            isLoading = false
        }

        await refresh()
    }

    // Silent by design: a trailhead is the worst place to be told about wifi.
    func refresh() async {
        guard let update = try? await catalog.catalog(matching: etag) else { return }

        adopt(update)
        cache.save(update)
        rebuild()
    }

    // Fetches the file behind a catalog row. True when the trail is now here.
    func download(_ trail: Trail) async -> Bool {
        guard let entry = entries[trail.id], !downloading.contains(trail.id) else { return false }

        downloading.insert(trail.id)
        defer { downloading.remove(trail.id) }

        do {
            let data = try await catalog.gpx(at: entry.gpx)

            // Saving parses the file, which is megabytes of XML.
            let store = self.store
            let saved = try await Task.detached { try store.save(data, as: entry) }.value

            onDevice.append(saved)
            rebuild()
            failure = nil
            return true
        } catch {
            failure = LoadFailure.classify(error)
            return false
        }
    }

    // A trail on the phone is theirs to throw away. It stays in the catalog.
    func remove(_ trail: Trail) {
        guard let index = onDevice.firstIndex(where: { $0.id == trail.id }) else { return }

        do {
            try store.remove(trail)
            onDevice.remove(at: index)
            rebuild()
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
            onDevice.append(try store.importFile(at: url))
            rebuild()
            failure = nil
        } catch {
            failure = .unavailable
        }
    }

    private func adopt(_ update: CatalogUpdate) {
        etag = update.etag

        // Last one wins: the catalog is hand written and may repeat an id.
        entries = Dictionary(
            update.catalog.trails.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    // What is here wins over what the catalog says about it.
    private func rebuild() {
        let here = Set(onDevice.map(\.id))

        trails = (onDevice + entries.values.filter { !here.contains($0.id) }.map { Trail($0, isOnDevice: false) })
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct TrailsView: View {

    @State private var viewModel: TrailsViewModel
    @State private var isImporting = false
    @State private var selected: Trail?

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
                // Always here, contents come and go: a rebuilt item eats a tap.
                ToolbarItem(placement: .topBarTrailing) {
                    // The empty screen offers this as its own button already.
                    if !viewModel.trails.isEmpty {
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
            .navigationDestination(item: $selected) { trail in
                // Read when the screen opens, or the list parses every file.
                TrailDetailView(trail: trail) { await viewModel.points(of: trail) }
            }
            .alert(
                Text("Download failed", comment: "Title when a trail could not be fetched"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the failed download alert")
                }
            } message: {
                if viewModel.failure == .offline {
                    Text("Trails already on your phone still work.",
                         comment: "Shown when a download failed for want of a connection")
                } else {
                    Text("Try again in a moment.",
                         comment: "Shown when a download failed for any other reason")
                }
            }
            .task { await viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.trails) { trail in
            Button {
                open(trail)
            } label: {
                row(trail)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                // Nothing to delete until the file is here.
                if trail.isOnDevice {
                    Button(role: .destructive) {
                        viewModel.remove(trail)
                    } label: {
                        Label {
                            Text("Delete", comment: "Removes a trail from the phone")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    // Downloading is a consequence of opening a trail, not a chore of its own.
    private func open(_ trail: Trail) {
        guard !trail.isOnDevice else {
            selected = trail
            return
        }

        Task {
            guard await viewModel.download(trail) else { return }
            selected = viewModel.trails.first { $0.id == trail.id }
        }
    }

    private func row(_ trail: Trail) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(trail.name)
                    .font(Theme.Font.body)

                // Both are metres on a short trail, so they need naming.
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

            Spacer(minLength: 0)

            marker(trail)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func marker(_ trail: Trail) -> some View {
        if viewModel.downloading.contains(trail.id) {
            ProgressView()
        } else if !trail.isOnDevice {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Theme.Color.secondaryText)
                .accessibilityLabel(Text("Not downloaded yet",
                                         comment: "Marks a trail that is still only in the catalogue"))
        } else {
            Image(systemName: "chevron.right")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.tertiaryText)
        }
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
