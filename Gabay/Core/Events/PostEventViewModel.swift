//
//  PostEventViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class PostEventViewModel {

    // Each field has its own storage and hand-written setter (not a plain stored property) so every
    // edit clears a stale failure via `ActionState.clear()`, instead of leaving it on screen until
    // a resubmit a bad edit might never allow.
    private var storedTitle = ""
    private var storedCause = ""
    private var storedDate: Date?
    private var storedMeetingPoint = ""
    private var storedMeetingCoordinate: Coordinate?
    private var storedFeePHP = ""
    private var storedCapacity = ""
    private var storedJoinURLText = ""
    private var storedEventDescription = ""
    private var storedPhotoURLText = ""

    var title: String {
        get { storedTitle }
        set { storedTitle = newValue; action.clear() }
    }

    var cause: String {
        get { storedCause }
        set { storedCause = newValue; action.clear() }
    }

    // Optional and required, not defaulted to now, so a pre-filled date can't let an organizer post
    // a hike starting the instant they tap Submit without noticing the field.
    var date: Date? {
        get { storedDate }
        set { storedDate = newValue; action.clear() }
    }

    var meetingPoint: String {
        get { storedMeetingPoint }
        set { storedMeetingPoint = newValue; action.clear() }
    }

    var meetingCoordinate: Coordinate? {
        get { storedMeetingCoordinate }
        set { storedMeetingCoordinate = newValue; action.clear() }
    }

    var feePHP: String {
        get { storedFeePHP }
        set { storedFeePHP = newValue; action.clear() }
    }

    var capacity: String {
        get { storedCapacity }
        set { storedCapacity = newValue; action.clear() }
    }

    var joinURLText: String {
        get { storedJoinURLText }
        set { storedJoinURLText = newValue; action.clear() }
    }

    var eventDescription: String {
        get { storedEventDescription }
        set { storedEventDescription = newValue; action.clear() }
    }

    var photoURLText: String {
        get { storedPhotoURLText }
        set { storedPhotoURLText = newValue; action.clear() }
    }

    var alert: AlertState?

    let action = ActionState()

    private(set) var didSubmit = false

    // A GPX is optional; once picked it must parse, but a bad file blocks only itself with its own
    // inline error, not the rest of the form.
    private(set) var route: RouteStats?
    private(set) var gpxError: APIError?
    @ObservationIgnored private var gpxFileURL: URL?

    @ObservationIgnored private let events: any EventPublishingRepository
    @ObservationIgnored private let parser: GPXParser

    init(events: any EventPublishingRepository, parser: GPXParser = GPXParser()) {
        self.events = events
        self.parser = parser
    }

    // Every rule below guards on the field being non-empty first: an empty required field already
    // shows the required marker and a disabled button, so an inline error always means "what you
    // typed is not usable". A server-supplied message, when there is one, wins over the local rule.

    var feeError: String? {
        if let serverMessage = action.message(for: "feePHP") { return serverMessage }
        guard !feePHP.trimmed.isEmpty, (Int(feePHP.trimmed) ?? -1) < 0 else { return nil }
        return String(
            localized: "Enter the fee as a whole number of pesos, 0 or more.",
            comment: "Validation message shown for a fee that is not a whole non-negative number"
        )
    }

    var capacityError: String? {
        if let serverMessage = action.message(for: "capacity") { return serverMessage }
        guard !capacity.trimmed.isEmpty, (Int(capacity.trimmed) ?? 0) <= 0 else { return nil }
        return String(
            localized: "Enter how many hikers can join, at least 1.",
            comment: "Validation message shown for a capacity that is not a positive number"
        )
    }

    var joinURLError: String? {
        if let serverMessage = action.message(for: "joinURL") { return serverMessage }
        guard !joinURLText.trimmed.isEmpty, !joinURLText.trimmed.isFullLink else { return nil }
        return String(
            localized: "Enter a full link, starting with https://",
            comment: "Validation message shown for a link with no scheme"
        )
    }

    var photoURLError: String? {
        if let serverMessage = action.message(for: "photoURL") { return serverMessage }
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

    // Fields with their own inline slot on the form. title, cause, meetingPoint and description
    // render none, so an error keyed to one of those must fall through to the whole-form line
    // below, or the user sees nothing.
    private static let fieldsWithSlots: Set<String> = ["feePHP", "capacity", "joinURL", "photoURL"]

    // A field-level message already shows next to its field, so the whole-form line is suppressed
    // only when every returned key has a slot. If any key lacks one, this falls through to
    // `action.errorMessage` so the failure stays visible.
    var submitErrorMessage: String? {
        if let fields = action.error?.validationErrors?.fields,
           !fields.isEmpty,
           fields.keys.allSatisfy(Self.fieldsWithSlots.contains) {
            return nil
        }
        return action.errorMessage
    }

    // No image upload endpoint yet, so a photo is an already-hosted link (uploaded elsewhere by the
    // organizer), unlike the GPX, which does upload.
    var canSubmit: Bool {
        !action.isRunning
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
        action.clear()

        // A file from Files or iCloud Drive is security scoped: without this the read fails, which
        // is most real picks. The scope ends when this method returns, so the bytes are copied into
        // our own container rather than held by URL until submit uploads them.
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let points = try parser.parse(data).points

            let local = FileManager.default.temporaryDirectory
                .appending(path: "\(UUID().uuidString).gpx")
            try data.write(to: local)

            discardCopiedGPX()
            route = RouteStats(points: points)
            gpxFileURL = local
        } catch {
            route = nil
            discardCopiedGPX()
            gpxError = APIError.classify(error)
        }
    }

    func removeGPX() {
        route = nil
        discardCopiedGPX()
        gpxError = nil
        action.clear()
    }

    private func discardCopiedGPX() {
        if let gpxFileURL { try? FileManager.default.removeItem(at: gpxFileURL) }
        gpxFileURL = nil
    }

    func submit() async {
        guard canSubmit,
              let date,
              let fee = Int(feePHP.trimmed),
              let capacity = Int(capacity.trimmed),
              let joinURL = URL(string: joinURLText.trimmed),
              let meetingCoordinate else { return }

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
        let route = self.route
        let gpxFileURL = self.gpxFileURL

        let created = await action.run { [events] in
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

            return created
        }

        guard created != nil else { return }

        didSubmit = true
        alert = .notice(
            String(localized: "Submitted", comment: "Title confirming an event was submitted"),
            String(
                localized: "Your event is pending review before it appears publicly.",
                comment: "Shown after an organizer submits a new event"
            )
        )
    }
}

private extension String {

    // A link the app can actually open: a web scheme with somewhere to go, not just anything
    // URL(string:) will parse.
    var isFullLink: Bool {
        guard let url = URL(string: self), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && !(url.host?.isEmpty ?? true)
    }
}
