//
//  RecordingView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import CoreLocation
import SwiftUI
import UIKit

// The walk in progress. One screen whether a trail is being followed or not.
struct RecordingView: View {

    @Bindable var recorder: Recorder

    // The trail underneath, empty for a walk with nothing to follow.
    let trail: [TrackPoint]

    @Environment(\.dismiss) private var dismiss

    @State private var isFollowing = true
    @State private var position: CLLocationCoordinate2D?
    @State private var finished: Activity?

    var body: some View {
        ZStack(alignment: .bottom) {
            TrailMapView(
                points: trail,
                track: recorder.points,
                isFollowing: $isFollowing,
                position: $position
            )
                .ignoresSafeArea()

            panel
        }
        .onAppear { UIDevice.current.isBatteryMonitoringEnabled = true }
        .sheet(item: $finished) { walk in
            FinishedView(walk: walk, recorder: recorder) { dismiss() }
                .interactiveDismissDisabled()
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            covered

            if total > 0 {
                ProgressView(value: min(recorder.distance / total, 1))
                    .tint(Theme.Color.accent)
            }

            HStack {
                numbers
                Spacer()
                buttons
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
    }

    // Distance is the hero: on a trail the only question is how much further.
    private var covered: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            Text(formatted(recorder.distance))
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()

            if total > 0 {
                Text("of \(formatted(total))",
                     comment: "The trail's full length, beside how far the walker has come")
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
        }
    }

    private var numbers: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(elapsed)
                .monospacedDigit()

            if let ascent = recorder.ascent {
                Label(formattedAscent(ascent), systemImage: "arrow.up")
            }

            // The app holds the GPS open for hours. Saying so is a small honesty.
            Label(battery, systemImage: "battery.50")
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Color.secondaryText)
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private var buttons: some View {
        if recorder.phase == .paused {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    recorder.resume()
                } label: {
                    Label {
                        Text("Resume", comment: "Continues a paused recording")
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    Task { finished = await recorder.finish() }
                } label: {
                    Text("Finish", comment: "Ends a recording and opens the summary")
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            // Finishing lives behind Pause: a walk cannot be un-ended.
            Button {
                recorder.pause()
            } label: {
                Label {
                    Text("Pause", comment: "Pauses the recording")
                } icon: {
                    Image(systemName: "pause.fill")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var total: Double {
        trail.count > 1 ? trail.distance : 0
    }

    private var elapsed: String {
        Duration.seconds(recorder.elapsed).formatted(
            .time(pattern: recorder.elapsed >= 3600 ? .hourMinuteSecond : .minuteSecond)
        )
    }

    private var battery: String {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return "--" }

        return (Double(level)).formatted(.percent.precision(.fractionLength(0)))
    }

    private func formatted(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private func formattedAscent(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            ))
    }
}
