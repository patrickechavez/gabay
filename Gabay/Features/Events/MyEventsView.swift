//
//  MyEventsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

struct MyEventsView: View {

    @State var viewModel: EventsViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.mineState {
                case .idle, .loading:
                    ProgressView()
                case .empty:
                    ContentUnavailableView {
                        Label {
                            Text("No events joined yet", comment: "Shown when the hiker hasn't joined any event")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                    } description: {
                        Text("Events you join show up here.",
                             comment: "Shown when My Events is empty")
                    }
                case let .failed(error):
                    ErrorStateView(error: error) { await viewModel.refresh() }
                case .loaded:
                    list
                }
            }
            .navigationTitle(Text("My Events", comment: "Title of the joined-events list"))
            .task { await viewModel.load() }
        }
    }

    private var list: some View {
        List(viewModel.mine) { event in
            NavigationLink {
                EventDetailView(event: event, viewModel: viewModel)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(Theme.Font.body)
                    Text(event.date, style: .date)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                .padding(.vertical, 3)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }
}
