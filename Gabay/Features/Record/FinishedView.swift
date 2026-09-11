//
//  FinishedView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import SwiftUI

// What was walked, and whether to keep it.
struct FinishedView: View {

    let walk: Activity

    @Bindable var recorder: Recorder

    let onDone: () -> Void

    @State private var name: String
    @State private var kind: Activity.Kind
    @State private var failed = false

    init(walk: Activity, recorder: Recorder, onDone: @escaping () -> Void) {
        self.walk = walk
        self.recorder = recorder
        self.onDone = onDone
        _name = State(initialValue: walk.name)
        _kind = State(initialValue: walk.kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "Name", comment: "Label for the activity name field"),
                        text: $name
                    )

                    Picker(selection: $kind) {
                        ForEach(Activity.Kind.allCases, id: \.self) { kind in
                            Text(label(for: kind)).tag(kind)
                        }
                    } label: {
                        Text("Type", comment: "Label for the activity type picker")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    numbers
                }

                Section {
                    ElevationProfile(points: recorder.points)
                        .frame(height: 90)
                        .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(Text("Finished", comment: "Title of the summary shown after a walk"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        recorder.discard(walk)
                        onDone()
                    } label: {
                        Text("Discard", comment: "Throws away a walk that was just recorded")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Text("Save", comment: "Keeps a walk that was just recorded")
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert(
                Text("Could not save", comment: "Title when a finished walk could not be kept"),
                isPresented: $failed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the failed save alert")
                }
            } message: {
                Text("The walk is still on your phone. Try again.",
                     comment: "Reassurance when saving a walk failed")
            }
        }
    }

    private var numbers: some View {
        Grid(horizontalSpacing: Theme.Spacing.lg, verticalSpacing: Theme.Spacing.md) {
            GridRow {
                measure(String(localized: "Distance", comment: "Label for how far a walk went"),
                        walk.formattedDistance)
                measure(String(localized: "Time", comment: "Label for how long a walk took"),
                        walk.formattedDuration)
            }
            GridRow {
                measure(String(localized: "Climb", comment: "Label for how much a walk climbed"),
                        walk.formattedAscent ?? "--")
                measure(String(localized: "Pace", comment: "Label for a walk's average pace"),
                        walk.formattedPace ?? "--")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(for kind: Activity.Kind) -> LocalizedStringKey {
        switch kind {
        case .walk: "Walk"
        case .run: "Run"
        case .hike: "Hike"
        }
    }

    private func save() {
        var saved = walk
        saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? walk.name : name
        saved.kind = kind

        do {
            try recorder.save(saved)
            onDone()
        } catch {
            failed = true
        }
    }
}
