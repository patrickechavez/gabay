//
//  LocationStream.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import CoreLocation
import Foundation

// One position report, with enough to decide whether to trust it.
struct Fix: Equatable, Sendable {

    let latitude: Double

    let longitude: Double

    // Nil when the phone had no useful height, which is not the same as sea level.
    let altitude: Double?

    let horizontalAccuracy: Double

    let timestamp: Date

    var point: TrackPoint {
        TrackPoint(latitude: latitude, longitude: longitude, elevation: altitude, time: timestamp)
    }
}

// Where the walker is, for as long as somebody is listening.
protocol LocationStreaming: Sendable {

    func fixes() -> AsyncStream<Fix>
}

// The real GPS, configured to survive the screen locking.
struct LiveLocationStream: LocationStreaming {

    func fixes() -> AsyncStream<Fix> {
        AsyncStream { continuation in
            let driver = Driver(continuation: continuation)
            continuation.onTermination = { _ in driver.stop() }
            driver.start()
        }
    }
}

// Holds the manager: one that goes out of scope reports nothing.
private final class Driver: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    // Beyond this a fix is a guess, and a guess drawn on a map is a lie.
    private static let worstUsableAccuracy: CLLocationAccuracy = 30

    private let manager = CLLocationManager()
    private let continuation: AsyncStream<Fix>.Continuation

    init(continuation: AsyncStream<Fix>.Continuation) {
        self.continuation = continuation
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness

        // Left on, iOS decides you have stopped and ends the track for you.
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        continuation.finish()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy > 0
            && location.horizontalAccuracy <= Self.worstUsableAccuracy {

            continuation.yield(Fix(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.verticalAccuracy > 0 ? location.altitude : nil,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp
            ))
        }
    }
}
