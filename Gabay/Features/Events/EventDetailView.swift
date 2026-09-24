//
//  EventDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import CoreLocation
import MapKit
import SwiftUI

struct EventDetailView: View {

    let event: Event
    let viewModel: EventsViewModel

    @Environment(\.openURL) private var openURL
    @State private var routeViewModel: EventRouteViewModel

    init(event: Event, viewModel: EventsViewModel) {
        self.event = event
        self.viewModel = viewModel
        _routeViewModel = State(wrappedValue: viewModel.makeRouteViewModel(for: event))
    }

    private var hasJoined: Bool { viewModel.joined.contains(event.id) }

    // `gpxURL` is read as a presence flag only. The file itself is fetched from the route the app
    // knows, so an authenticated request is never aimed at a URL the server chose.
    private var hasRoute: Bool { event.gpxURL != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(event.title)
                    .font(Theme.Font.screenTitle)

                Text(event.cause)
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)

                details
                meetingMap

                if hasRoute {
                    routeMap
                }

                // Outside the `hasRoute` branch on purpose: these numbers come down with the event,
                // so they show even while the map is loading, and still show if it never arrives.
                routeStats

                Text(event.description)
                    .font(Theme.Font.body)

                joinButton
            }
            .screenPadding()
            .padding(.vertical, Theme.Spacing.lg)
        }
        .navigationTitle(Text("Hike Details", comment: "Title of an event's detail screen"))
        .navigationBarTitleDisplayMode(.inline)
        // Keyed on the URL: a refresh can flip this from nil to a link once the organizer's upload
        // lands, and an unkeyed task would never run again, leaving the map spinning forever.
        .task(id: event.gpxURL) {
            guard hasRoute else { return }
            await routeViewModel.load()
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            row(icon: "calendar", text: event.date.formatted(date: .long, time: .shortened))
            row(icon: "mappin.and.ellipse", text: event.meetingPoint)
            row(icon: "pesosign.circle", text: "\u{20B1}\(event.feePHP) registration fee")
            row(icon: "person.2", text: "\(event.capacity) spots")
        }
        .font(Theme.Font.body)
    }

    private func row(icon: String, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
    }

    private var meetingMap: some View {
        let coordinate = CLLocationCoordinate2D(
            latitude: event.meetingCoordinate.latitude,
            longitude: event.meetingCoordinate.longitude
        )

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Map(initialPosition: .region(
                MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )) {
                Marker(event.meetingPoint, coordinate: coordinate)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .allowsHitTesting(false)

            Button {
                openURL(directionsURL(to: coordinate))
            } label: {
                Text("Get Directions", comment: "Opens the meeting point in Maps")
            }
        }
    }

    @ViewBuilder
    private var routeMap: some View {
        switch routeViewModel.route {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        case .empty:
            EmptyView()
        case let .failed(error):
            if error.isUserFacing {
                routeFailure
            }
        case let .loaded(points):
            RoutePreviewMap(points: points)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
    }

    // Deliberately small: the map is the only thing missing, and the hike's details are all still
    // on screen above and below it.
    private var routeFailure: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("The route map could not be loaded.",
                 comment: "Shown when an event's GPX route fails to download")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Button {
                Task { await routeViewModel.retry() }
            } label: {
                Text("Try Again", comment: "Retries loading the route map")
            }
            .font(Theme.Font.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var routeStats: some View {
        if let summary = routeSummaryText {
            Text(summary)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
        }
    }

    // Prefers what the event carried, since that is what the organizer saw, and falls back
    // field by field to the track once it loads. Without the fallback an event whose stats the
    // backend did not send would draw the route and print no numbers beside it.
    private var routeSummaryText: String? {
        let computed = routeViewModel.stats

        guard let distanceM = event.distanceM.map(Double.init) ?? computed?.distanceM else {
            return nil
        }
        return RouteSummary.text(
            distanceM: distanceM,
            ascentM: event.ascentM.map(Double.init) ?? computed?.ascentM,
            minutes: event.estimatedMinutes ?? computed?.estimatedMinutes
        )
    }

    private var joinButton: some View {
        Button {
            openURL(event.joinURL)
            Task { await viewModel.join(event) }
        } label: {
            if hasJoined {
                Text("Joined. Open Link Again", comment: "Button shown after the hiker has already joined")
            } else {
                Text("Join This Hike", comment: "Button that opens the external payment/coordination link")
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }

    private func directionsURL(to coordinate: CLLocationCoordinate2D) -> URL {
        URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)")!
    }
}
