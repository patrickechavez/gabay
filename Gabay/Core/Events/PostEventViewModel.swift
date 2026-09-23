//
//  PostEventViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class PostEventViewModel {

    var title = ""
    var cause = ""
    // Optional and required, rather than defaulted to now. A pre-filled date
    // lets an organizer post a hike starting the instant they tap Submit
    // without ever noticing the field.
    var date: Date?
    var meetingPoint = ""
    var meetingCoordinate: Coordinate?
    var feePHP = ""
    var capacity = ""
    var joinURLText = ""
    var eventDescription = ""
    var photoURLText = ""

    var alert: AlertState?

    private(set) var isSubmitting = false
    private(set) var failure: LoadFailure?
    private(set) var didSubmit = false

    // A GPX is optional. Once picked, it must parse, a bad file blocks
    // only itself, with its own inline error, not the rest of the form.
    private(set) var route: RouteStats?
    private(set) var gpxError: LoadFailure?
    @ObservationIgnored private var gpxFileURL: URL?

    @ObservationIgnored private let events: any EventFetching
    @ObservationIgnored private let parser: GPXParser

    init(events: any EventFetching, parser: GPXParser = GPXParser()) {
        self.events = events
        self.parser = parser
    }

    // Every rule below guards on the field being non-empty first. An empty
    // required field shows as the required marker and a disabled button, so
    // an inline error always means "what you typed is not usable".

    var feeError: String? {
        guard !feePHP.trimmed.isEmpty, (Int(feePHP.trimmed) ?? -1) < 0 else { return nil }
        return String(
            localized: "Enter the fee as a whole number of pesos, 0 or more.",
            comment: "Validation message shown for a fee that is not a whole non-negative number"
        )
    }

    var capacityError: String? {
        guard !capacity.trimmed.isEmpty, (Int(capacity.trimmed) ?? 0) <= 0 else { return nil }
        return String(
            localized: "Enter how many hikers can join, at least 1.",
            comment: "Validation message shown for a capacity that is not a positive number"
        )
    }

    var joinURLError: String? {
        guard !joinURLText.trimmed.isEmpty, !joinURLText.trimmed.isFullLink else { return nil }
        return String(
            localized: "Enter a full link, starting with https://",
            comment: "Validation message shown for a link with no scheme"
        )
    }

    var photoURLError: String? {
        guard !photoURLText.trimmed.isEmpty, !photoURLText.trimmed.isFullLink else { return nil }
        return String(
            localized: "Enter a full link, starting with https://",
            comment: "Validation message shown for a link with no scheme"
        )
    }

    var gpxErrorMessage: String? {
        guard let gpxError, gpxError.isUserFacing else { return nil }
        return String(
            localized: "That file could not be read. Try a different GPX, or leave the route out, it's optional.",
            comment: "Shown when an attached GPX cannot be parsed"
        )
    }

    var submitErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(
            localized: "Check the form and try again.",
            comment: "Shown when posting an event fails"
        )
    }

    // No image upload endpoint exists yet, so a photo is an already-hosted
    // link (the organizer's own upload elsewhere) rather than a picked
    // file, unlike the GPX, which does upload.
    var canSubmit: Bool {
        !isSubmitting
            && !title.trimmed.isEmpty
            && !cause.trimmed.isEmpty
            && date != nil
            && !meetingPoint.trimmed.isEmpty
            && meetingCoordinate != nil
            && !eventDescription.trimmed.isEmpty
            && (Int(feePHP.trimmed) ?? -1) >= 0
            && (Int(capacity.trimmed) ?? 0) > 0
            && joinURLText.trimmed.isFullLink
            && (photoURLText.trimmed.isEmpty || photoURLText.trimmed.isFullLink)
    }

    func pickGPX(at url: URL) {
        gpxError = nil

        do {
            let data = try Data(contentsOf: url)
            let points = try parser.parse(data).points
            route = RouteStats(points: points)
            gpxFileURL = url
        } catch {
            route = nil
            gpxFileURL = nil
            gpxError = .unavailable
        }
    }

    func removeGPX() {
        route = nil
        gpxFileURL = nil
        gpxError = nil
    }

    func submit() async {
        guard canSubmit,
              let date,
              let fee = Int(feePHP.trimmed),
              let capacity = Int(capacity.trimmed),
              let joinURL = URL(string: joinURLText.trimmed),
              let meetingCoordinate else { return }

        failure = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let draft = EventDraft(
            title: title.trimmed,
            cause: cause.trimmed,
            date: date,
            meetingPoint: meetingPoint.trimmed,
            meetingCoordinate: meetingCoordinate,
            feePHP: fee,
            capacity: capacity,
            joinURL: joinURL,
            description: eventDescription.trimmed,
            photoURL: photoURLText.trimmed.isEmpty ? nil : URL(string: photoURLText.trimmed)
        )

        do {
            let created = try await events.create(draft)

            if let route, let gpxFileURL {
                _ = try await events.uploadGPX(
                    eventID: created.id,
                    fileURL: gpxFileURL,
                    distanceM: Int(route.distanceM),
                    ascentM: route.ascentM.map(Int.init),
                    estimatedMinutes: route.estimatedMinutes
                )
            }

            didSubmit = true
            alert = .notice(
                String(localized: "Submitted", comment: "Title confirming an event was submitted"),
                String(
                    localized: "Your event is pending review before it appears publicly.",
                    comment: "Shown after an organizer submits a new event"
                )
            )
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

private extension String {

    // A link the app can actually open: a web scheme with somewhere to go,
    // not just any string URL(string:) is willing to parse.
    var isFullLink: Bool {
        guard let url = URL(string: self), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && !(url.host?.isEmpty ?? true)
    }
}
