//
//  RecordView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import SwiftUI

// Start, with nothing to follow. The whole tab.
struct RecordView: View {

    @Bindable var recorder: Recorder

    @State private var isRecording = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "figure.walk")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.Color.secondaryText)

                Text("Track where you go, with no trail to follow.",
                     comment: "What the Record tab is for")
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    start()
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
            }
            .screenPadding()
            .padding(.bottom, Theme.Spacing.xxl)
            .navigationTitle(Text("Record", comment: "Title of the recording tab"))
            .fullScreenCover(isPresented: $isRecording) {
                RecordingView(recorder: recorder, trail: [])
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
    }

    private func start() {
        do {
            try recorder.start()
            isRecording = true
        } catch {
            failed = true
        }
    }
}
