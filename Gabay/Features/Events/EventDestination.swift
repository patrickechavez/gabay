//
//  EventDestination.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import SwiftUI

// A route carries an event id, not an event, so the destination looks the event up in the list it
// came from. A deep link can name an event that list has not loaded yet, or does not contain at
// all, which is why this can come up empty.
struct EventDestination: View {

    let id: String
    let events: [Event]
    let state: LoadState<[Event]>
    let viewModel: EventsViewModel

    var body: some View {
        if let event = events.first(where: { $0.id == id }) {
            EventDetailView(event: event, viewModel: viewModel)
        } else {
            // The list may simply not have loaded yet, so wait while it is in flight. Once it has
            // settled and the event still is not there, say so: it may be deleted, still pending
            // review, or unreachable because the load failed. An indefinite spinner here hides an
            // error that renders on the list underneath, where nobody can see it.
            switch state {
            case .idle, .loading:
                ProgressView()
            case let .failed(error):
                ErrorStateView(error: error) { await viewModel.refresh() }
            case .loaded, .empty:
                ContentUnavailableView {
                    Label {
                        Text("Hike not available",
                             comment: "Shown when a linked event is missing from the list")
                    } icon: {
                        Image(systemName: "figure.hiking")
                    }
                } description: {
                    Text("It may have been removed, or it is still awaiting review.",
                         comment: "Explains why a linked event cannot be shown")
                }
            }
        }
    }
}
