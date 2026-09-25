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
    let viewModel: EventsViewModel

    var body: some View {
        if let event = events.first(where: { $0.id == id }) {
            EventDetailView(event: event, viewModel: viewModel)
        } else {
            ProgressView()
                .task { await viewModel.refresh() }
        }
    }
}
