//
//  Recorder.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import Foundation

// A walk in progress: what has been covered, and the file it is going into.
@Observable
@MainActor
final class Recorder {

    enum Phase: Equatable {
        case idle
        case recording
        case paused
    }

    // Wobbles under this are GPS drift, not climbing.
    private static let realClimb: Double = 3

    private(set) var phase: Phase = .idle

    // Kept in memory as well as on disk, because the map draws them.
    private(set) var points: [TrackPoint] = []

    private(set) var distance: Double = 0

    // Nil until a fix carries a height worth trusting.
    private(set) var ascent: Double?

    private(set) var elapsed: TimeInterval = 0

    // False until the first usable fix, so the Record tab can say so.
    private(set) var hasFix = false

    @ObservationIgnored private let store: any ActivityStoring
    @ObservationIgnored private let locations: any LocationStreaming

    @ObservationIgnored private var draft: Activity?
    @ObservationIgnored private var writer: GPXWriter?
    @ObservationIgnored private var reader: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    @ObservationIgnored private var climbReference: Double?
    @ObservationIgnored private var runningSince: Date?
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var now: @Sendable () -> Date

    init(
        store: any ActivityStoring,
        locations: any LocationStreaming,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.locations = locations
        self.now = now
    }

    var isRecording: Bool { phase != .idle }

    // The trail being followed, so a saved walk can point back at it.
    private(set) var trail: Trail?

    func start(following trail: Trail? = nil) throws {
        guard phase == .idle else { return }

        let started = now()
        let activity = Activity(
            id: UUID().uuidString,
            name: Activity.defaultName(for: trail?.name, at: started),
            kind: ActivityStore.startingKind,
            startedAt: started,
            distance: 0,
            ascent: nil,
            duration: 0,
            trailID: trail?.id
        )

        writer = try store.beginWriting(activity)
        draft = activity
        self.trail = trail

        runningSince = started
        phase = .recording
        listen()
        tick()
    }

    func pause() {
        guard phase == .recording else { return }

        accumulated = elapsedNow()
        runningSince = nil
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }

        runningSince = now()
        phase = .recording
    }

    // Closes the file and hands back the walk, unsaved.
    func finish() async -> Activity? {
        guard let draft else { return nil }

        accumulated = elapsedNow()
        runningSince = nil
        reader?.cancel()
        ticker?.cancel()
        await writer?.finish()

        let walked = Activity(
            id: draft.id,
            name: draft.name,
            kind: draft.kind,
            startedAt: draft.startedAt,
            distance: distance,
            ascent: ascent,
            duration: accumulated,
            trailID: draft.trailID
        )

        phase = .idle
        writer = nil
        return walked
    }

    // What the walk was started under, which is what the file still says.
    var startingLabels: (name: String, kind: Activity.Kind) {
        (draft?.name ?? "", ActivityStore.startingKind)
    }

    func save(_ activity: Activity) throws {
        try store.save(activity, startedAs: startingLabels)
        reset()
    }

    func discard(_ activity: Activity) {
        store.discard(activity)
        reset()
    }

    private func reset() {
        points = []
        distance = 0
        ascent = nil
        elapsed = 0
        accumulated = 0
        climbReference = nil
        hasFix = false
        draft = nil
        trail = nil
    }

    private func listen() {
        reader = Task { [weak self, locations] in
            for await fix in locations.fixes() {
                guard let self else { return }
                self.record(fix)
            }
        }
    }

    private func tick() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.elapsed = self.elapsedNow()
            }
        }
    }

    private func elapsedNow() -> TimeInterval {
        guard let runningSince else { return accumulated }
        return accumulated + now().timeIntervalSince(runningSince)
    }

    // Paused means paused: a fix that arrives now is not part of the walk.
    private func record(_ fix: Fix) {
        hasFix = true
        guard phase == .recording else { return }

        let point = fix.point
        if let last = points.last { distance += last.distance(to: point) }
        climb(to: point.elevation)

        points.append(point)
        elapsed = elapsedNow()

        Task { [writer] in await writer?.append(point) }
    }

    private func climb(to elevation: Double?) {
        guard let elevation else { return }
        guard let reference = climbReference else {
            climbReference = elevation
            ascent = 0
            return
        }

        let change = elevation - reference
        if change >= Self.realClimb {
            ascent = (ascent ?? 0) + change
            climbReference = elevation
        } else if change <= -Self.realClimb {
            climbReference = elevation
        }
    }
}
