//
//  HistoryView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {

    private(set) var activities: [Activity] = []

    private(set) var isLoading = false

    @ObservationIgnored private let store: any ActivityStoring

    init(store: any ActivityStoring) {
        self.store = store
    }

    // Reading measures anything a crash left half written, so not on the main actor.
    func load() async {
        isLoading = activities.isEmpty

        let store = self.store
        activities = await Task.detached { (try? store.activities()) ?? [] }.value
        isLoading = false
    }

    func remove(_ activity: Activity) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }

        try? store.remove(activity)
        activities.remove(at: index)
    }

    func points(of activity: Activity) async -> [TrackPoint] {
        let store = self.store
        return await Task.detached { (try? store.points(of: activity)) ?? [] }.value
    }

    func file(of activity: Activity) -> URL {
        store.file(of: activity)
    }
}

struct HistoryView: View {

    @State private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.activities.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle(Text("History", comment: "Title of the saved walks tab"))
            .task { await viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.activities) { activity in
            NavigationLink {
                ActivityDetailView(
                    activity: activity,
                    file: viewModel.file(of: activity),
                    load: { await viewModel.points(of: activity) },
                    remove: { viewModel.remove(activity) }
                )
            } label: {
                row(activity)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    viewModel.remove(activity)
                } label: {
                    Label {
                        Text("Delete", comment: "Removes a saved walk from the phone")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
    }

    private func row(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(activity.name)
                .font(Theme.Font.body)

            HStack(spacing: Theme.Spacing.sm) {
                Label {
                    Text(label(for: activity.kind))
                } icon: {
                    Image(systemName: icon(for: activity.kind))
                }

                Text(activity.startedAt.formatted(.relative(presentation: .named)))

                Text(activity.formattedDistance)

                Text(activity.formattedDuration)
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.secondaryText)
        }
        .padding(.vertical, 3)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label {
                Text("No walks yet", comment: "Shown when nothing has been recorded")
            } icon: {
                Image(systemName: "clock")
            }
        } description: {
            Text("Walks you record are saved here, and can be shared as a GPX file.",
                 comment: "What the history tab will hold")
        }
    }

    private func label(for kind: Activity.Kind) -> LocalizedStringKey {
        switch kind {
        case .walk: "Walk"
        case .run: "Run"
        case .hike: "Hike"
        }
    }

    private func icon(for kind: Activity.Kind) -> String {
        switch kind {
        case .walk: "figure.walk"
        case .run: "figure.run"
        case .hike: "figure.hiking"
        }
    }
}
