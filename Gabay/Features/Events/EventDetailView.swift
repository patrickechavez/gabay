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
    @State private var route: LoadState<[TrackPoint]> = .idle

    private var hasJoined: Bool { viewModel.joined.contains(event.id) }

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

                if event.gpxURL != nil {
                    routeSection
                }

                Text(event.description)
                    .font(Theme.Font.body)

                joinButton
            }
            .screenPadding()
            .padding(.vertical, Theme.Spacing.lg)
        }
        .navigationTitle(Text("Hike Details", comment: "Title of an event's detail screen"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRoute() }
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
    private var routeSection: some View {
        switch route {
        case .idle, .loading:
            ProgressView()
        case .empty, .failed:
            EmptyView()
        case let .loaded(points):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                RoutePreviewMap(points: points)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

                if let distanceM = event.distanceM {
                    Text(routeSummary(distanceM: distanceM, ascentM: event.ascentM, minutes: event.estimatedMinutes))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }
        }
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

    private func loadRoute() async {
        guard let gpxURL = event.gpxURL, route.needsLoad else { return }

        route = .loading
        do {
            let (data, _) = try await URLSession.shared.data(from: gpxURL)
            let points = try GPXParser().parse(data).points
            route = .from(points)
        } catch {
            route = .failed(.classify(error))
        }
    }

    private func directionsURL(to coordinate: CLLocationCoordinate2D) -> URL {
        URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)")!
    }

    private func routeSummary(distanceM: Int, ascentM: Int?, minutes: Int?) -> String {
        let distanceText = Measurement(value: Double(distanceM), unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))

        var parts = [distanceText]
        if let ascentM {
            parts.append(Measurement(value: Double(ascentM), unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        if let minutes {
            parts.append("~\(minutes / 60)h \(minutes % 60)m")
        }
        return parts.joined(separator: " - ")
    }
}
