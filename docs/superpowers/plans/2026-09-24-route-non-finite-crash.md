# Route Non-Finite Crash Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop a GPX file containing `nan`, `inf` or an out-of-range coordinate from crashing the app, by rejecting such points where they enter and guarding the arithmetic that consumes them.

**Architecture:** Validation happens once, at the parser boundary, through a factory on `TrackPoint` that returns nil for a point the rest of the app cannot do arithmetic on. Everything downstream keeps its current shape. The two consumers that convert a `Double` into a trapping type, `RouteStats` and the map's framing call, gain a guard as defense in depth, because both take `[TrackPoint]` from any caller and not only from the parser.

**Tech Stack:** Swift 6 strict concurrency, `XMLParser`, CoreLocation, MapKit, Swift Testing.

**Scope:** This is audit finding C1, pulled out of Slice 4 and scheduled ahead of it. It touches none of the code Slices 2 and 3 replace, so it can land before, during or after them.

## The crash, concretely

`Double.init(String)` accepts more than decimal numbers. `Double("nan")`, `Double("inf")`, `Double("-inf")` and `Double("1e400")` all succeed, the last one yielding infinity. Swift's `Double` also happily holds a latitude of 9999.

Three things follow, in order:

1. `Gabay/Core/Route/GPXParser.swift:100` builds a point from `Double(attributes["lat"] ?? "")` with no range or finiteness check. `GPXParser.swift:128` does the same for `<ele>`.
2. `TrackPoint.distance(to:)` hands those to `CLLocation.distance(from:)`, and `[TrackPoint].distance` sums the results, so the total becomes NaN.
3. `Gabay/Core/Route/RouteStats.swift:31` evaluates `Int((seconds / 60).rounded())`. **`Int(Double.nan)` traps at runtime, and so does `Int(Double.infinity)` and `Int` of anything past `Int.max`.** The app does not throw; it dies, with:

```
Fatal error: Double value cannot be converted to Int because it is either infinite or NaN
```

That message and every claim in the paragraph above were verified against Swift 6.3.3 while writing this plan, not assumed. `Double("nan")`, `Double("inf")`, `Double("-inf")`, `Double("infinity")` and `Double("1e400")` all parse successfully, the last three yielding infinity, and `Double("9999")` yields a perfectly finite but impossible latitude. `(-90...90).contains(Double.nan)` is `false`, so the range check alone would catch NaN, but not infinity's intent, which is why the fix tests both.

Both entry points are real. An organizer picks the file themselves through `fileImporter` in `PostEventView`, and a hiker's device downloads and parses backend-supplied GPX in `EventDetailView`. A malformed or hostile file crashes either one.

A related non-finite value reaches `MKPolyline.boundingMapRect` and then `setVisibleMapRect`, which is the `RoutePreviewMap` path the audit also named.

## Global Constraints

- **No em dashes** anywhere: code, comments, user-facing strings, commit messages, report prose. Use a comma or a period.
- **Never run `xcodebuild` or `xcrun simctl`.** The user runs all builds and tests personally. Report the command and the expected result. Do not treat the inability to build as a blocker; it is the normal working mode here.
- **Swift 6 strict concurrency, satisfied honestly.** No `@unchecked Sendable`, `nonisolated(unsafe)`, force unwraps or `fatalError`. Note that removing a trap is the entire point of this plan, so adding one would be self-defeating.
- **Never edit `Gabay.xcodeproj/project.pbxproj`.** Files under `Gabay/` and `GabayTests/` are auto-included by `PBXFileSystemSynchronizedRootGroup`.
- **Never hand-edit or commit `Gabay/Resources/Localizable.xcstrings`.** It is dirty in the working tree and stays that way. Use targeted `git add`, never `git add -A`.
- **Do not change any behavior for well-formed input.** Every existing test in `GabayTests/GPXParserTests.swift` and `GabayTests/RouteStatsTests.swift` must still pass unchanged. If one of them has to change, stop and report; it means the fix altered valid-input behavior, which is not the intent.
- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- **No tests for pure UI views.** `RoutePreviewMap` is a `UIViewRepresentable`; its guard is not unit tested, and Task 2 says so explicitly rather than adding a test that asserts nothing.

## Design decision: what "invalid" costs

Two rules, and they differ on purpose:

**A bad coordinate drops the point.** A point whose latitude or longitude is not finite, or is outside the valid range, carries no usable position, and keeping it would corrupt every distance that touches it. It is dropped from the track.

**A bad elevation drops only the elevation.** A point with a good position and `<ele>nan</ele>` still tells you where the route goes. Dropping the whole point would lose geometry over a field that is optional to begin with, since `TrackPoint.elevation` is already `Double?` and hand-drawn routes omit it. So a non-finite elevation is treated as absent.

This is a deliberate reading of the spec, whose sentence on the subject can be read either way. If you disagree after seeing the code, say so in your report rather than implementing the other reading silently.

A file in which *every* point is invalid ends up with no points, and `GPXParser.parse(_:)` already throws `GPXError.noPoints` for that. No new error case is needed, and the organizer already sees the "could not be read" inline message that Slice 1 wired up.

## File Structure

| File | Change |
| --- | --- |
| `Gabay/Core/Route/TrackPoint.swift` | Gains a validating factory. The memberwise initializer stays, because tests construct deliberately invalid points with it. |
| `Gabay/Core/Route/GPXParser.swift` | Its `append(_:)` routes through the factory. |
| `Gabay/Core/Route/RouteStats.swift` | Guards the two `Double` values it derives before converting to `Int`. |
| `Gabay/Features/Route/RoutePreviewMap.swift` | `FramedMapView.frame(route:)` rejects a non-finite rect. |
| `GabayTests/GPXParserTests.swift` | New cases for rejected points. |
| `GabayTests/RouteStatsTests.swift` | New cases for non-finite input reaching the consumer directly. |

---

### Task 1: Reject unusable points at the parser boundary

**Files:**
- Modify: `Gabay/Core/Route/TrackPoint.swift`
- Modify: `Gabay/Core/Route/GPXParser.swift`
- Test: `GabayTests/GPXParserTests.swift`

**Interfaces produced,** relied on by Task 2's reasoning and by any future caller that builds points from untrusted input:

`TrackPoint.validated(latitude:longitude:elevation:time:) -> TrackPoint?`

- [ ] **Step 1: Write the failing tests**

Append to `GabayTests/GPXParserTests.swift`, inside the existing suite that holds `readsATrack`. Match the file's existing style: it builds GPX as a string literal and calls `GPXParser().parse(Data(xml.utf8))`. Read `readsCoordinatesElevationAndTime` for the exact idiom before writing these.

```swift
    @Test func dropsAPointWithANonNumericLatitude() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.82" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 2)
        #expect(document.points.allSatisfy { $0.latitude.isFinite })
    }

    @Test func dropsAPointWithAnInfiniteCoordinate() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="inf" lon="123.38"/>
        <trkpt lat="9.82" lon="-inf"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 1)
    }

    @Test func dropsAPointOutsideTheCoordinateRange() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="91" lon="123.38"/>
        <trkpt lat="9.82" lon="181"/>
        <trkpt lat="-90.5" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 1)
    }

    @Test func keepsTheExtremesOfTheCoordinateRange() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="90" lon="180"/>
        <trkpt lat="-90" lon="-180"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.count == 2)
    }

    @Test func keepsTheOrderOfTheSurvivingPoints() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"/>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.83" lon="123.38"/>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        #expect(document.points.map(\.latitude) == [9.81, 9.83])
    }

    @Test func keepsAPointWhoseElevationIsNotFinite() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="9.81" lon="123.38"><ele>nan</ele></trkpt>
        <trkpt lat="9.82" lon="123.38"><ele>120</ele></trkpt>
        </trkseg></trk></gpx>
        """

        let document = try GPXParser().parse(Data(xml.utf8))

        // The position is usable, so the point survives; only the climb is lost.
        #expect(document.points.count == 2)
        #expect(document.points.first?.elevation == nil)
        #expect(document.points.last?.elevation == 120)
    }

    @Test func refusesAFileWhereEveryPointIsUnusable() throws {
        let xml = """
        <gpx><trk><trkseg>
        <trkpt lat="nan" lon="123.38"/>
        <trkpt lat="9.81" lon="inf"/>
        </trkseg></trk></gpx>
        """

        #expect(throws: GPXError.noPoints) {
            try GPXParser().parse(Data(xml.utf8))
        }
    }
```

- [ ] **Step 2: Report that the tests should fail**

Do not run them. Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/GPXParserTests
```

Expected before the fix: the new cases fail, because every point currently survives parsing. `refusesAFileWhereEveryPointIsUnusable` fails by not throwing.

- [ ] **Step 3: Add the validating factory**

Append to `Gabay/Core/Route/TrackPoint.swift`, after the `TrackPoint` declaration and before `struct Track`:

```swift
extension TrackPoint {

    // Builds a point only when its position can be used for arithmetic.
    // Double("nan"), Double("inf") and Double("1e400") all succeed, so a
    // GPX attribute reaches the parser looking like a number and then
    // traps much later, in the Int conversion inside RouteStats.
    static func validated(
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        time: Date? = nil
    ) -> TrackPoint? {
        guard latitude.isFinite, (-90...90).contains(latitude),
              longitude.isFinite, (-180...180).contains(longitude) else { return nil }

        // A bad elevation costs the climb for this point, not the point.
        // Elevation is optional anyway: hand drawn routes carry none.
        let usableElevation = elevation.flatMap { $0.isFinite ? $0 : nil }

        return TrackPoint(
            latitude: latitude,
            longitude: longitude,
            elevation: usableElevation,
            time: time
        )
    }
}
```

On the two `isFinite` checks for latitude and longitude: they are logically redundant with the range checks that follow, since a comparison against NaN is always false and both infinities fall outside any finite closed range. They are kept deliberately, to state the intent and to make the infinity case obvious to the next reader. The `isFinite` check on elevation is not redundant, because no range check accompanies it.

Leave the memberwise initializer alone. Task 2's tests need to construct deliberately invalid points, and both existing test files already use it.

- [ ] **Step 4: Route the parser through it**

In `Gabay/Core/Route/GPXParser.swift`, replace the body of `private func append(_ point: PartialPoint?)`:

```swift
        private func append(_ point: PartialPoint?) {
            guard let point,
                  let track = TrackPoint.validated(
                      latitude: point.latitude,
                      longitude: point.longitude,
                      elevation: point.elevation,
                      time: point.time
                  )
            else { return }

            // Points outside any track still count: some writers omit <trk>.
            if currentTrack == nil { currentTrack = Track(name: nil, points: []) }
            currentTrack?.points.append(track)
        }
```

Note what this deliberately does not do: it does not create an empty `currentTrack` for a rejected point. A file whose only points are invalid therefore produces no tracks at all, `finishedTracks()` filters nothing extra, and `parse(_:)` throws `GPXError.noPoints` through the guard it already has. That is the behavior `refusesAFileWhereEveryPointIsUnusable` pins.

Do not add a check in `didStartElement`. Validating in one place is the point; adding a second copy at the attribute site is the duplication this fix exists to avoid.

- [ ] **Step 5: Report the verification command**

Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/GPXParserTests
```

Expected: every case passes, including the twelve that were there before. Do not run it.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Route/TrackPoint.swift Gabay/Core/Route/GPXParser.swift GabayTests/GPXParserTests.swift
git commit -m "Reject GPX points that carry an unusable position"
```

---

### Task 2: Guard the consumers

Task 1 stops bad points entering through the parser. This task stops the two places that convert a `Double` into something that traps from doing so, whatever the source. Both take `[TrackPoint]` from any caller, so neither can assume the parser ran.

**Files:**
- Modify: `Gabay/Core/Route/RouteStats.swift`
- Modify: `Gabay/Features/Route/RoutePreviewMap.swift`
- Test: `GabayTests/RouteStatsTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `GabayTests/RouteStatsTests.swift`, inside the existing `RouteStatsTests` suite. It already has a `points(_:)` helper that builds valid points from a list of elevations; these tests need invalid ones, so they construct `TrackPoint` directly with the memberwise initializer.

**Before the fix, these tests do not fail with a wrong value. They crash the test process.** That is expected and is the whole point: a trap is not a catchable error, so there is no way to assert against it other than by fixing it. Say so in your report.

```swift
    @Test func survivesANonFiniteCoordinate() {
        let broken = [
            TrackPoint(latitude: .nan, longitude: 123.3878, elevation: nil, time: nil),
            TrackPoint(latitude: 9.8127, longitude: 123.3878, elevation: nil, time: nil)
        ]

        let stats = RouteStats(points: broken)

        #expect(stats.estimatedMinutes == 0)
        #expect(stats.distanceM.isFinite)
    }

    @Test func survivesAnInfiniteCoordinate() {
        let broken = [
            TrackPoint(latitude: .infinity, longitude: 123.3878, elevation: nil, time: nil),
            TrackPoint(latitude: 9.8127, longitude: 123.3878, elevation: nil, time: nil)
        ]

        let stats = RouteStats(points: broken)

        #expect(stats.estimatedMinutes == 0)
        #expect(stats.distanceM.isFinite)
    }

    @Test func survivesANonFiniteElevation() {
        let broken = [
            TrackPoint(latitude: 9.8127, longitude: 123.3878, elevation: .nan, time: nil),
            TrackPoint(latitude: 9.8137, longitude: 123.3878, elevation: .infinity, time: nil)
        ]

        let stats = RouteStats(points: broken)

        #expect(stats.estimatedMinutes >= 0)
        #expect(stats.ascentM == nil || stats.ascentM?.isFinite == true)
    }

    @Test func leavesAWellFormedRouteUnchanged() {
        // A regression guard: the new arithmetic must not alter a valid route.
        let stats = RouteStats(points: points([100, 150, 200]))

        #expect(stats.distanceM.isFinite)
        #expect(stats.ascentM == 100)
        #expect(stats.estimatedMinutes > 0)
    }
```

- [ ] **Step 2: Report that the tests should crash**

Do not run them. Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/RouteStatsTests
```

Expected before the fix: the process crashes in `Int(_:)` rather than reporting a failure, which is exactly the bug.

- [ ] **Step 3: Guard `RouteStats`**

Replace the initializer in `Gabay/Core/Route/RouteStats.swift`:

```swift
    init(points: [TrackPoint]) {
        // A single non-finite coordinate makes the whole sum non-finite, and
        // Int(_:) traps on NaN, on infinity, and on anything past Int.max.
        // Points normally arrive validated from GPXParser, but this type is
        // constructible from anywhere, so it does not assume that.
        let distance = points.distance
        distanceM = distance.isFinite && distance >= 0 ? distance : 0

        let hasElevation = points.contains { $0.elevation != nil }
        let ascent = hasElevation ? points.ascent() : nil
        ascentM = ascent.flatMap { $0.isFinite ? $0 : nil }

        // Naismith's rule: 4 km an hour, plus an hour per 600 m climbed.
        let seconds = distanceM / 4000 * 3600 + (ascentM ?? 0) / 600 * 3600
        let minutes = (seconds / 60).rounded()
        estimatedMinutes = minutes.isFinite && minutes >= 0 && minutes < Double(Int.max)
            ? Int(minutes)
            : 0
    }
```

Three changes worth noticing, so you can confirm each landed:

1. `distanceM` is clamped to a finite non-negative value, so the stored property can never carry NaN into a view that formats it.
2. `ascentM` now reads through `flatMap`, so a non-finite ascent becomes nil, which the type already means as "the file carried no elevation". The downstream formatter already handles nil.
3. The `seconds` expression now reads `ascentM` rather than the local `ascent`, so it uses the guarded value. This is the easiest line in the task to leave pointing at the old local by accident.

- [ ] **Step 4: Guard the map framing**

In `Gabay/Features/Route/RoutePreviewMap.swift`, replace `FramedMapView.frame(route:)`:

```swift
    func frame(route rect: MKMapRect) {
        // MKPolyline over non-finite coordinates yields a non-finite rect,
        // and setVisibleMapRect with one leaves the map in a broken state.
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.size.width.isFinite, rect.size.height.isFinite else { return }

        pending = rect
        applyPendingFrame()
    }
```

Put the guard here rather than at the `draw(on:)` call site, so it covers every caller of the view rather than the one that exists today. The map then simply keeps its default region instead of framing a route it cannot measure.

**No test for this.** `FramedMapView` is a `MKMapView` subclass inside a `UIViewRepresentable`, and the project does not unit test pure UI views. State that in your report rather than adding a test that constructs a map view and asserts nothing useful.

- [ ] **Step 5: Report the verification command**

Record that the user should run the full suite, since this task touches a type used across several files:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)'
```

Expected: everything passes, including the four existing `RouteStatsTests` cases, which must be unchanged. Do not run it.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Route/RouteStats.swift Gabay/Features/Route/RoutePreviewMap.swift GabayTests/RouteStatsTests.swift
git commit -m "Guard route arithmetic against non-finite values"
```

---

## What this plan does not fix

- The rest of audit finding C1's neighbourhood stays in Slice 4: the missing `startAccessingSecurityScopedResource()` in `PostEventViewModel.pickGPX(at:)`, `EventDetailView`'s `URLSession.shared` fetch and main-actor parse, the `OneShotLocator` continuation leak, the shared `StubURLProtocol` state, `MyEventsView`'s empty state, and the duplicated `routeSummary`.
- `routeSummary` still renders 45 minutes as "~0h 45m" and still hardcodes English. Untouched here on purpose: it is duplicated in two files, and fixing one copy would put them out of step before Slice 4 merges them.
- Nothing in Slices 2 or 3. This plan shares no files with either.

## Self-Review

**Coverage of the finding.** The audit named three code sites: `RouteStats.swift:31`, `GPXParser.swift:100`, and a non-finite `MKMapRect` in `RoutePreviewMap`. Task 1 covers the parser, including the `<ele>` path at `GPXParser.swift:128` that the audit's one-line summary did not name but which has the same defect. Task 2 covers the other two. The spec's stated fix, rejecting a point whose latitude is not finite or outside -90 to 90 or whose longitude is not finite or outside -180 to 180, and guarding `RouteStats` before the `Int` conversion, is implemented literally.

**Placeholder scan.** No "TBD", "handle edge cases" or "similar to Task N". Every code step carries the full replacement text for the function it changes.

**Type consistency.** `TrackPoint.validated(latitude:longitude:elevation:time:)` is defined in Task 1 Step 3 with `elevation` and `time` defaulted, and called in Task 1 Step 4 with all four arguments in declaration order. `RouteStats`'s stored properties keep their existing names and types, so no caller changes: `PostEventView`, `EventDetailView` and `PostEventViewModel` all continue to read `distanceM`, `ascentM` and `estimatedMinutes` exactly as before.

**One thing the implementer should expect to feel wrong.** Task 2's tests crash the process before the fix rather than failing. That is not a broken test; a Swift trap cannot be caught and asserted against. The TDD cycle still holds, but the "watch it fail" step produces a crash log rather than a red test, and the report should say so.
