//
//  ActivityStoreTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct ActivityStoreTests {

    private func makeStore() -> ActivityStore {
        ActivityStore(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
    }

    private func makeActivity(
        name: String = "Spartan Trail",
        kind: Activity.Kind = .hike,
        distance: Double = 1000,
        duration: TimeInterval = 600
    ) -> Activity {
        Activity(
            id: UUID().uuidString,
            name: name,
            kind: kind,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            distance: distance,
            ascent: 40,
            duration: duration
        )
    }

    private func walk(from activity: Activity, points: Int = 3) -> [TrackPoint] {
        (0..<points).map { step in
            TrackPoint(
                latitude: 10.30 + Double(step) * 0.001,
                longitude: 123.87,
                elevation: 25 + Double(step) * 10,
                time: activity.startedAt.addingTimeInterval(Double(step) * 10)
            )
        }
    }

    @Test func startsEmpty() throws {
        #expect(try makeStore().activities().isEmpty)
    }

    // What the writer writes, the parser reads. Anything else is a broken export.
    @Test func writesAWalkTheParserCanReadBack() async throws {
        let store = makeStore()
        let activity = makeActivity()

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }
        await writer.finish()
        try store.save(activity, startedAs: (activity.name, ActivityStore.startingKind))

        let read = try store.points(of: activity)

        #expect(read.count == 3)
        #expect(read.first?.elevation == 25)
        #expect(read.first?.time == activity.startedAt)
    }

    @Test func listsASavedWalk() async throws {
        let store = makeStore()
        let activity = makeActivity()

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }
        await writer.finish()
        try store.save(activity, startedAs: (activity.name, ActivityStore.startingKind))

        let saved = try #require(try store.activities().first)
        #expect(saved.name == "Spartan Trail")
        #expect(saved.kind == .hike)
        #expect(saved.distance == 1000)
    }

    // The name and type are chosen after the walk, so the file has to catch up.
    @Test func stampsTheChosenNameAndTypeOnTheFile() async throws {
        let store = makeStore()
        var activity = makeActivity(name: "Morning walk")

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }
        await writer.finish()

        activity.name = "Osmeña Peak"
        activity.kind = .hike
        try store.save(activity, startedAs: ("Morning walk", ActivityStore.startingKind))

        let text = try String(contentsOf: store.file(of: activity), encoding: .utf8)
        #expect(text.contains("<name>Osmeña Peak</name>"))
        #expect(text.contains("<type>hiking</type>"))
    }

    // A crash leaves a file with no closing tags and no sidecar.
    @Test func recoversAWalkThatWasNeverFinished() async throws {
        let store = makeStore()
        let activity = makeActivity(name: "Morning walk")

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }

        let recovered = try #require(try store.activities().first)
        #expect(recovered.id == activity.id)
        #expect(recovered.name == "Morning walk")
        #expect(recovered.distance > 0)
        #expect(recovered.duration == 20)
    }

    @Test func removesAWalkAndItsSidecar() async throws {
        let store = makeStore()
        let activity = makeActivity()

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }
        await writer.finish()
        try store.save(activity, startedAs: (activity.name, ActivityStore.startingKind))

        try store.remove(activity)

        #expect(try store.activities().isEmpty)
    }

    @Test func sortsNewestFirst() async throws {
        let store = makeStore()

        for offset in [0.0, 3600.0] {
            var activity = makeActivity(name: "Walk \(Int(offset))")
            activity = Activity(
                id: activity.id,
                name: activity.name,
                kind: .walk,
                startedAt: Date(timeIntervalSince1970: 1_800_000_000 + offset),
                distance: 100,
                ascent: nil,
                duration: 60
            )

            let writer = try store.beginWriting(activity)
            await writer.append(TrackPoint(latitude: 10, longitude: 123, elevation: nil, time: activity.startedAt))
            await writer.finish()
            try store.save(activity, startedAs: (activity.name, ActivityStore.startingKind))
        }

        #expect(try store.activities().map(\.name) == ["Walk 3600", "Walk 0"])
    }

    // A file the walker never kept must leave nothing behind.
    @Test func discardsAWalkEntirely() async throws {
        let store = makeStore()
        let activity = makeActivity()

        let writer = try store.beginWriting(activity)
        for point in walk(from: activity) { await writer.append(point) }
        await writer.finish()

        store.discard(activity)

        #expect(try store.activities().isEmpty)
    }
}

struct ActivityTests {

    @Test func namesAWalkForTheTimeOfDayWhenThereIsNoTrail() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 12
        components.hour = 7

        let calendar = Calendar(identifier: .gregorian)
        let morning = try #require(calendar.date(from: components))

        #expect(Activity.defaultName(for: nil, at: morning, calendar: calendar) == "Morning walk")
        #expect(Activity.defaultName(for: "Spartan Trail", at: morning, calendar: calendar) == "Spartan Trail")
    }

    @Test func showsPaceOnlyOnceTheWalkIsWorthMeasuring() {
        let short = Activity(id: "a", name: "a", kind: .walk, startedAt: .now,
                             distance: 50, ascent: nil, duration: 60)
        let real = Activity(id: "b", name: "b", kind: .walk, startedAt: .now,
                            distance: 1000, ascent: nil, duration: 600)

        #expect(short.formattedPace == nil)
        #expect(real.formattedPace == "10:00/km")
    }
}
