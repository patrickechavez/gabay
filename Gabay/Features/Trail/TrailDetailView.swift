//
//  TrailDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// The trail on a map, and nothing else.
struct TrailDetailView: View {

    let trail: Trail

    let load: () async -> [TrackPoint]

    @State private var points: [TrackPoint] = []
    @State private var isFollowing = false

    var body: some View {
        TrailMapView(points: points, isFollowing: $isFollowing)
            .ignoresSafeArea()
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
                // A hand drawn route carries no elevation, so there is nothing
                // to show rather than a flat line pretending otherwise.
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
