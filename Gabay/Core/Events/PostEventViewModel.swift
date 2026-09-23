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
    var date = Date()
    var meetingPoint = ""
    var meetingCoordinate: Coordinate?
    var feePHP = ""
    var capacity = ""
    var joinURLText = ""
    var eventDescription = ""
    var photoURLText = ""

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

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    var isShowingConfirmation: Bool {
        get { didSubmit }
        set { if !newValue { didSubmit = false } }
    }

    var isShowingGPXFailure: Bool {
        get { gpxError != nil }
        set { if !newValue { gpxError = nil } }
    }

    // No image upload endpoint exists yet, so a photo is an already-hosted
    // link (the organizer's own upload elsewhere) rather than a picked
    // file, unlike the GPX, which does upload.
    var canSubmit: Bool {
        !isSubmitting
            && !title.trimmed.isEmpty
            && !cause.trimmed.isEmpty
            && !meetingPoint.trimmed.isEmpty
            && meetingCoordinate != nil
            && !eventDescription.trimmed.isEmpty
            && Int(feePHP) != nil
            && (Int(capacity) ?? 0) > 0
            && URL(string: joinURLText)?.scheme != nil
            && (photoURLText.trimmed.isEmpty || URL(string: photoURLText.trimmed)?.scheme != nil)
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
              let fee = Int(feePHP),
              let capacity = Int(capacity),
              let joinURL = URL(string: joinURLText),
              let meetingCoordinate else { return }

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
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
