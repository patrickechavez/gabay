//
//  PostEventView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct PostEventView: View {

    @State var viewModel: PostEventViewModel
    @State private var isPickingLocation = false
    @State private var isPickingGPX = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Title",
                        text: $viewModel.title,
                        prompt: Text("Title", comment: "Placeholder for the event title field")
                    )
                    TextField(
                        "Cause",
                        text: $viewModel.cause,
                        prompt: Text("Cause", comment: "Placeholder for the beneficiary/cause field")
                    )
                    DatePicker(selection: $viewModel.date) {
                        Text("Date", comment: "Label for the event date and time picker")
                    }
                } header: {
                    Text("Basics", comment: "Section header for an event's core details")
                }

                Section {
                    TextField(
                        "Meeting point",
                        text: $viewModel.meetingPoint,
                        prompt: Text("Meeting point", comment: "Placeholder for the meeting point label field")
                    )

                    Button {
                        isPickingLocation = true
                    } label: {
                        if viewModel.meetingCoordinate != nil {
                            Label {
                                Text("Pin set", comment: "Shown once a meeting point pin has been dropped")
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        } else {
                            Text("Choose on Map", comment: "Opens the meeting point pin-drop picker")
                        }
                    }
                } header: {
                    Text("Meeting Point", comment: "Section header for the meeting point label and pin")
                }

                Section {
                    TextField(
                        "Fee",
                        text: $viewModel.feePHP,
                        prompt: Text("Fee in pesos", comment: "Placeholder for the registration fee field")
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Capacity",
                        text: $viewModel.capacity,
                        prompt: Text("Capacity", comment: "Placeholder for the hiker capacity field")
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Join link",
                        text: $viewModel.joinURLText,
                        prompt: Text("https://", comment: "Placeholder for the external join/payment link field")
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Registration", comment: "Section header for fee, capacity, and join link")
                }

                gpxSection

                Section {
                    TextField(
                        "Photo link",
                        text: $viewModel.photoURLText,
                        prompt: Text("https:// (optional)",
                                     comment: "Placeholder for the optional event photo link field")
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Photo", comment: "Section header for the optional event photo")
                } footer: {
                    Text("Link to a photo already hosted somewhere, such as one you've posted elsewhere.",
                         comment: "Explains the photo link field, since there's no photo upload yet")
                }

                Section {
                    TextField(
                        "Description",
                        text: $viewModel.eventDescription,
                        prompt: Text("Description", comment: "Placeholder for the event description field"),
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                } header: {
                    Text("Description", comment: "Section header for the event description")
                }

                Section {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit for Review", comment: "Button that submits a new event for moderation")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle(Text("Post a Hike", comment: "Title of the organizer event-creation form"))
            .sheet(isPresented: $isPickingLocation) {
                LocationPicker(coordinate: $viewModel.meetingCoordinate)
            }
            .fileImporter(isPresented: $isPickingGPX, allowedContentTypes: [.gpxFile, .xml, .data]) { result in
                if case let .success(url) = result {
                    viewModel.pickGPX(at: url)
                }
            }
            .alert(
                Text("Submitted", comment: "Title confirming an event was submitted"),
                isPresented: $viewModel.isShowingConfirmation
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the submission confirmation")
                }
            } message: {
                Text("Your event is pending review before it appears publicly.",
                     comment: "Shown after an organizer submits a new event")
            }
            .alert(
                Text("Couldn't submit", comment: "Title when posting an event fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the submission failure alert")
                }
            } message: {
                Text("Check the form and try again.", comment: "Shown when posting an event fails")
            }
            .alert(
                Text("Couldn't read that file", comment: "Title when an attached GPX fails to parse"),
                isPresented: $viewModel.isShowingGPXFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the GPX read failure alert")
                }
            } message: {
                Text("Try a different GPX file, or leave the route out, it's optional.",
                     comment: "Shown when an attached GPX cannot be parsed")
            }
        }
    }

    @ViewBuilder
    private var gpxSection: some View {
        Section {
            if let route = viewModel.route {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label {
                        Text("Route attached", comment: "Shown once a GPX has been parsed successfully")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }

                    Text(routeSummary(route))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }

                Button(role: .destructive) {
                    viewModel.removeGPX()
                } label: {
                    Text("Remove Route", comment: "Removes the attached GPX from the form")
                }
            } else {
                Button {
                    isPickingGPX = true
                } label: {
                    Text("Attach a GPX (Optional)", comment: "Opens the file picker for an optional route")
                }
            }
        } header: {
            Text("Route", comment: "Section header for the optional GPX route")
        }
    }

    private func routeSummary(_ route: RouteStats) -> String {
        let distanceText = Measurement(value: route.distanceM, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))

        var parts = [distanceText]
        if let ascentM = route.ascentM {
            parts.append(Measurement(value: ascentM, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        parts.append("~\(route.estimatedMinutes / 60)h \(route.estimatedMinutes % 60)m")
        return parts.joined(separator: " - ")
    }
}

private extension UTType {

    // GPX is not one of Apple's declared types, so the app names it itself.
    // Named `gpxFile`, not `gpx`: the free-trail app's still-present
    // TrailsView.swift declares an internal `UTType.gpx` (deleted only in
    // Task 12), and a same-named member visible in this file would be
    // ambiguous at best.
    static let gpxFile = UTType(filenameExtension: "gpx") ?? .xml
}
