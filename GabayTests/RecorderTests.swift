//
//  RecorderTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct RecorderTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRecorder(clock: Clock = Clock()) -> (Recorder, StubLocations, ActivityStore) {
        let store = ActivityStore(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let locations = StubLocations()
        clock.set(start)

        return (Recorder(store: store, locations: locations, now: { clock.read() }), locations, store)
    }

    // A straight climb: 0, 20, 40 metres apart, rising ten each time.
    private func fixes(_ count: Int, accuracy: Double = 5) -> [Fix] {
        (0..<count).map { step in
            Fix(
                latitude: 10.30 + Double(step) * 0.001,
                longitude: 123.87,
                altitude: 25 + Double(step) * 10,
                horizontalAccuracy: accuracy,
                timestamp: start.addingTimeInterval(Double(step) * 10)
            )
        }
    }

    // Waits for the recorder to have seen them, rather than hoping it has.
    private func send(_ fixes: [Fix], through locations: StubLocations, to recorder: Recorder) async {
        let target = recorder.fixesSeen + fixes.count
        await locations.send(fixes)

        for _ in 0..<10_000 where recorder.fixesSeen < target {
            await Task.yield()
        }
    }

    @Test func startsIdle() {
        let (recorder, _, _) = makeRecorder()

        #expect(recorder.phase == .idle)
        #expect(!recorder.isRecording)
    }

    @Test func collectsFixesIntoATrack() async throws {
        let (recorder, locations, _) = makeRecorder()
        try recorder.start()

        await send(fixes(3), through: locations, to: recorder)

        #expect(recorder.points.count == 3)
        #expect(recorder.distance > 0)
        #expect(recorder.ascent == 20)
    }

    // Paused means paused: a fix that arrives now is not part of the walk.
    @Test func ignoresFixesWhilePaused() async throws {
        let (recorder, locations, _) = makeRecorder()
        try recorder.start()
        await send(fixes(2), through: locations, to: recorder)

        recorder.pause()
        await send([fixes(4)[2]], through: locations, to: recorder)

        #expect(recorder.points.count == 2)

        recorder.resume()
        await send([fixes(4)[3]], through: locations, to: recorder)

        #expect(recorder.points.count == 3)
    }

    // Paused time is not walked time, or every break inflates the pace.
    @Test func leavesPausedTimeOutOfTheClock() async throws {
        let clock = Clock()
        let (recorder, _, _) = makeRecorder(clock: clock)
        try recorder.start()

        clock.advance(60)
        recorder.pause()
        clock.advance(600)
        recorder.resume()
        clock.advance(30)

        let walk = try #require(await recorder.finish())
        #expect(walk.duration == 90)
    }

    @Test func handsBackAWalkWithWhatWasMeasured() async throws {
        let (recorder, locations, _) = makeRecorder()
        try recorder.start(following: .osmena)
        await send(fixes(3), through: locations, to: recorder)

        let walk = try #require(await recorder.finish())

        #expect(walk.name == "Osmeña Peak")
        #expect(walk.trailID == "osmena-peak")
        #expect(walk.distance > 0)
        #expect(walk.ascent == 20)
        #expect(recorder.phase == .idle)
    }

    @Test func savingKeepsTheWalkAndClearsTheRecorder() async throws {
        let (recorder, locations, store) = makeRecorder()
        try recorder.start()
        await send(fixes(3), through: locations, to: recorder)

        var walk = try #require(await recorder.finish())
        walk.name = "Osmeña Peak"
        walk.kind = .hike
        try recorder.save(walk)

        #expect(try store.activities().count == 1)
        #expect(try store.activities().first?.name == "Osmeña Peak")
        #expect(recorder.points.isEmpty)
        #expect(recorder.distance == 0)
    }

    @Test func discardingLeavesNothingBehind() async throws {
        let (recorder, locations, store) = makeRecorder()
        try recorder.start()
        await send(fixes(3), through: locations, to: recorder)

        let walk = try #require(await recorder.finish())
        recorder.discard(walk)

        #expect(try store.activities().isEmpty)
        #expect(recorder.points.isEmpty)
    }

    // A walk with no trail is named for when it happened.
    @Test func namesAnUntrailedWalkForTheTimeOfDay() async throws {
        let clock = Clock()
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 12
        components.hour = 7
        clock.set(try #require(Calendar(identifier: .gregorian).date(from: components)))

        let store = ActivityStore(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let recorder = Recorder(store: store, locations: StubLocations(), now: { clock.read() })

        try recorder.start()
        let walk = try #require(await recorder.finish())

        #expect(walk.name == "Morning walk")
    }
}

// MARK: - Stubs

// Feeds fixes to whoever is listening.
private final class StubLocations: LocationStreaming, @unchecked Sendable {

    private var continuation: AsyncStream<Fix>.Continuation?

    func fixes() -> AsyncStream<Fix> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func send(_ fixes: [Fix]) async {
        // The stream is built on the first listen, which may not have run yet.
        while continuation == nil { await Task.yield() }

        for fix in fixes { continuation?.yield(fix) }
    }
}

// A clock the test moves, so no test waits for real seconds.
private final class Clock: @unchecked Sendable {

    private var date = Date()

    func set(_ date: Date) { self.date = date }

    func advance(_ seconds: TimeInterval) { date += seconds }

    func read() -> Date { date }
}

private extension Trail {

    static let osmena = Trail(
        id: "osmena-peak",
        name: "Osmeña Peak",
        region: "Cebu",
        distance: 5200,
        ascent: 388,
        difficulty: .moderate,
        source: .catalog,
        isOnDevice: true
    )
}
