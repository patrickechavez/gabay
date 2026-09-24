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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    basicsSection
                    meetingPointSection
                    registrationSection
                    routeSection
                    photoSection
                    descriptionSection

                    if let message = viewModel.submitErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Submit for Review",
                                    comment: "Button that submits a new event for moderation"),
                        isRunning: viewModel.action.isRunning,
                        action: { await viewModel.submit() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Post a Hike", comment: "Title of the organizer event-creation form"))
            .sheet(isPresented: $isPickingLocation) {
                LocationPicker(coordinate: $viewModel.meetingCoordinate)
            }
            .fileImporter(isPresented: $isPickingGPX, allowedContentTypes: [.gpxFile, .xml, .data]) { result in
                if case let .success(url) = result {
                    Task { await viewModel.pickGPX(at: url) }
                }
            }
            .appAlert($viewModel.alert)
        }
    }

    @ViewBuilder
    private var basicsSection: some View {
        sectionHeader(Text("Basics", comment: "Section header for an event's core details"))

        AppTextField(
            text: $viewModel.title,
            placeholder: String(localized: "Title", comment: "Placeholder for the event title field"),
            label: String(localized: "Title", comment: "Label for the event title field"),
            isRequired: true,
            capitalization: .words
        )

        AppTextField(
            text: $viewModel.cause,
            placeholder: String(localized: "Cause", comment: "Placeholder for the beneficiary/cause field"),
            label: String(localized: "Cause", comment: "Label for the beneficiary/cause field"),
            isRequired: true,
            capitalization: .words
        )

        DateField(
            label: String(localized: "Date", comment: "Label for the event date and time field"),
            date: $viewModel.date,
            format: .monthDayYearTime12,
            isRequired: true
        )
    }

    @ViewBuilder
    private var meetingPointSection: some View {
        sectionHeader(Text("Meeting Point", comment: "Section header for the meeting point label and pin"))

        AppTextField(
            text: $viewModel.meetingPoint,
            placeholder: String(localized: "Meeting point",
                                comment: "Placeholder for the meeting point label field"),
            label: String(localized: "Meeting point", comment: "Label for the meeting point label field"),
            isRequired: true
        )

        FieldContainer(
            label: String(localized: "Meeting point pin", comment: "Label for the meeting point pin picker"),
            isRequired: true,
            error: nil
        ) {
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
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var registrationSection: some View {
        sectionHeader(Text("Registration", comment: "Section header for fee, capacity, and join link"))

        AppTextField(
            text: $viewModel.feePHP,
            placeholder: String(localized: "Fee in pesos",
                                comment: "Placeholder for the registration fee field"),
            label: String(localized: "Fee", comment: "Label for the registration fee field"),
            error: viewModel.feeError,
            isRequired: true,
            keyboard: .numberPad
        )

        AppTextField(
            text: $viewModel.capacity,
            placeholder: String(localized: "Capacity", comment: "Placeholder for the hiker capacity field"),
            label: String(localized: "Capacity", comment: "Label for the hiker capacity field"),
            error: viewModel.capacityError,
            isRequired: true,
            keyboard: .numberPad
        )

        AppTextField(
            text: $viewModel.joinURLText,
            placeholder: String(localized: "https://",
                                comment: "Placeholder for the external join/payment link field"),
            label: String(localized: "Join link", comment: "Label for the external join/payment link field"),
            error: viewModel.joinURLError,
            isRequired: true,
            keyboard: .URL,
            capitalization: .never,
            contentType: .URL,
            disableAutocorrection: true
        )
    }

    @ViewBuilder
    private var routeSection: some View {
        sectionHeader(Text("Route", comment: "Section header for the optional GPX route"))

        if let route = viewModel.route {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label {
                    Text("Route attached", comment: "Shown once a GPX has been parsed successfully")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text(RouteSummary.text(distanceM: route.distanceM,
                                       ascentM: route.ascentM,
                                       minutes: route.estimatedMinutes))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                viewModel.removeGPX()
            } label: {
                Text("Remove Route", comment: "Removes the attached GPX from the form")
            }
            .buttonStyle(.bordered)
        } else {
            Button {
                isPickingGPX = true
            } label: {
                Text("Attach a GPX (Optional)", comment: "Opens the file picker for an optional route")
            }
            .buttonStyle(.bordered)
        }

        if let message = viewModel.gpxErrorMessage {
            InlineErrorText(message)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        sectionHeader(Text("Photo", comment: "Section header for the optional event photo"))

        AppTextField(
            text: $viewModel.photoURLText,
            placeholder: String(localized: "https:// (optional)",
                                comment: "Placeholder for the optional event photo link field"),
            label: String(localized: "Photo link", comment: "Label for the optional event photo link field"),
            error: viewModel.photoURLError,
            keyboard: .URL,
            capitalization: .never,
            contentType: .URL,
            disableAutocorrection: true
        )

        Text("Link to a photo already hosted somewhere, such as one you've posted elsewhere.",
             comment: "Explains the photo link field, since there's no photo upload yet")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var descriptionSection: some View {
        sectionHeader(Text("Description", comment: "Section header for the event description"))

        FieldContainer(
            label: String(localized: "Description", comment: "Label for the event description field"),
            isRequired: true,
            error: nil
        ) {
            TextField(
                String(localized: "Description", comment: "Placeholder for the event description field"),
                text: $viewModel.eventDescription,
                axis: .vertical
            )
            .lineLimit(4...8)
            .accessibilityLabel(Text("Description", comment: "Label for the event description field"))
        }
    }

    // Section headers are identical everywhere, so they are built once here rather than repeated at
    // each of the six call sites.
    private func sectionHeader(_ text: Text) -> some View {
        text
            .font(Theme.Font.sectionTitle)
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.sm)
    }
}

private extension UTType {

    // GPX is not one of Apple's declared types, so the app names it itself; called `gpxFile`, not
    // `gpx`, to stay clear of any other GPX type declared elsewhere in the target.
    static let gpxFile = UTType(filenameExtension: "gpx") ?? .xml
}
