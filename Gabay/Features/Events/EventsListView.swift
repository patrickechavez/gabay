//
//  EventsListView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct EventsListView: View {

    @State var viewModel: EventsViewModel
    @State private var selected: Event?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                case .empty:
                    ContentUnavailableView {
                        Label {
                            Text("No events yet", comment: "Shown when no cause-hikes are published")
                        } icon: {
                            Image(systemName: "figure.hiking")
                        }
                    } description: {
                        Text("Check back soon for the next hike for a cause.",
                             comment: "Shown when the events list is empty")
                    }
                case let .failed(error):
                    ErrorStateView(error: error) { await viewModel.refresh() }
                case let .loaded(events):
                    list(events)
                }
            }
            .navigationTitle(Text("Events", comment: "Title of the cause-hike events list"))
            .navigationDestination(item: $selected) { event in
                EventDetailView(event: event, viewModel: viewModel)
            }
            .task { await viewModel.load() }
        }
    }

    private func list(_ events: [Event]) -> some View {
        List(events) { event in
            Button {
                selected = event
            } label: {
                row(event)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    private func row(_ event: Event) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(Theme.Font.body)

                Text(event.cause)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)

                Text(event.date, style: .date)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            Spacer(minLength: 0)

            if viewModel.joined.contains(event.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Color.success)
                    .accessibilityLabel(Text("Joined", comment: "Marks an event the hiker has already joined"))
            } else {
                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.tertiaryText)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}
