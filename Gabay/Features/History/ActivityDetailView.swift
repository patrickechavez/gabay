//
//  ActivityDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import CoreLocation
import SwiftUI

// A walk that happened: where it went, what it cost, and where it can go next.
struct ActivityDetailView: View {

    let activity: Activity

    // The GPX itself, handed straight to the share sheet.
    let file: URL

    let load: () async -> [TrackPoint]

    let remove: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var points: [TrackPoint] = []
    @State private var isFollowing = false
    @State private var position: CLLocationCoordinate2D?
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            TrailMapView(
                points: [],
                track: points,
                framesTrack: true,
                isFollowing: $isFollowing,
                position: $position
            )

            panel
        }
        .task { points = await load() }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: file) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .confirmationDialog(
            Text("Delete this walk?", comment: "Title of the confirmation before deleting a walk"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                remove()
                dismiss()
            } label: {
                Text("Delete", comment: "Confirms deleting a saved walk")
            }
        } message: {
            Text("The GPX file goes with it.",
                 comment: "What is lost when a saved walk is deleted")
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("\(activity.startedAt.formatted(date: .long, time: .shortened))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            HStack(spacing: Theme.Spacing.xl) {
                measure(String(localized: "Distance", comment: "Label for how far a walk went"),
                        activity.formattedDistance)
                measure(String(localized: "Time", comment: "Label for how long a walk took"),
                        activity.formattedDuration)
                measure(String(localized: "Climb", comment: "Label for how much a walk climbed"),
                        activity.formattedAscent ?? "--")
            }

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Text("Delete walk", comment: "Removes a saved walk and its file")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .screenPadding()
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Color.background)
    }

    private func measure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .monospacedDigit()
        }
    }
}
