//
//  TrailDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import CoreLocation
import SwiftUI

// The trail on a map, and nothing else.
struct TrailDetailView: View {

    let trail: Trail

    @Bindable var recorder: Recorder

    let load: () async -> [TrackPoint]

    @State private var points: [TrackPoint] = []
    @State private var isFollowing = false
    @State private var position: CLLocationCoordinate2D?
    @State private var isRecording = false
    @State private var failed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TrailMapView(points: points, isFollowing: $isFollowing, position: $position)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                distanceToStart
                start
            }
            .padding(.bottom, Theme.Spacing.lg)
        }
            .task { points = await load() }
            .navigationTitle(trail.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isFollowing.toggle()
                    } label: {
                        Image(systemName: isFollowing ? "location.fill" : "location")
                    }
                    .accessibilityLabel(Text("Follow my position",
                                             comment: "Keeps the map centred on the walker"))
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                RecordingView(recorder: recorder, trail: points)
            }
            .alert(
                Text("Could not start", comment: "Title when a recording could not begin"),
                isPresented: $failed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the failed start alert")
                }
            } message: {
                Text("There was no room to write the walk. Free up some space.",
                     comment: "Shown when the app could not open a file for a new walk")
            }
    }

    // Nothing stands between a cold trailhead and Start.
    private var start: some View {
        Button {
            begin()
        } label: {
            Label {
                Text("Start", comment: "Begins recording a walk")
            } icon: {
                Image(systemName: "play.fill")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .screenPadding()
    }

    private func begin() {
        do {
            try recorder.start(following: trail)
            isRecording = true
        } catch {
            failed = true
        }
    }

    // Answers "am I near this" in text, so the camera never has to.
    @ViewBuilder
    private var distanceToStart: some View {
        if let position, let metres = points.distanceFromStart(to: position) {
            Text("\(formatted(metres)) to the start",
                 comment: "How far the walker is from the beginning of the trail")
                .font(Theme.Font.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private func formatted(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

// The shape of the walk: elevation against distance along the trail.
struct ElevationProfile: View {

    let points: [TrackPoint]

    var body: some View {
        GeometryReader { geometry in
            let elevations = points.compactMap(\.elevation)

            if elevations.count > 1 {
                let path = path(for: elevations, in: geometry.size)

                path.stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                path
                    .fill(Theme.Color.accent.opacity(0.12))
            } else {
                // No elevation in the file, so nothing rather than a flat line.
                Text("No elevation in this file",
                     comment: "Shown when a GPX has no elevation to draw")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func path(for elevations: [Double], in size: CGSize) -> Path {
        let lowest = elevations.min() ?? 0
        let highest = elevations.max() ?? 1
        let range = max(highest - lowest, 1)
        let step = size.width / CGFloat(elevations.count - 1)

        var path = Path()
        for (index, elevation) in elevations.enumerated() {
            let along = CGFloat(index) * step
            let height = size.height - CGFloat((elevation - lowest) / range) * size.height
            let point = CGPoint(x: along, y: height)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
