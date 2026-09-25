//
//  LocationPicker.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import CoreLocation
import MapKit
import SwiftUI
import os

// Pin-drop for a meeting point: opens on the organizer's current location if they allow it,
// otherwise a fixed region around Cebu, tap anywhere to move the pin.
struct LocationPicker: View {

    @Binding var coordinate: Coordinate?

    @Environment(\.dismiss) private var dismiss

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.3157, longitude: 123.8854),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pin: CLLocationCoordinate2D?
    @State private var locator = OneShotLocator()

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin {
                        Marker(
                            "Meeting point",
                            coordinate: pin
                        )
                    }
                }
                .onTapGesture { point in
                    guard let tapped = proxy.convert(point, from: .local) else { return }
                    pin = tapped
                }
            }
            .navigationTitle(Text("Drop a pin", comment: "Title of the meeting-point picker"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the picker without setting a pin")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let pin {
                            coordinate = Coordinate(latitude: pin.latitude, longitude: pin.longitude)
                        }
                        dismiss()
                    } label: {
                        Text("Set", comment: "Confirms the dropped pin as the meeting point")
                    }
                    .disabled(pin == nil)
                }
            }
            .task {
                if let here = await locator.currentLocation() {
                    position = .region(
                        MKCoordinateRegion(center: here, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    )
                    pin = here
                }
            }
        }
    }
}

// One current-location read, nothing held past it: no background mode, no continuous updates,
// just "where am I right now."
//
// Not @MainActor: CLLocationManagerDelegate is a non-isolated protocol and Swift 6 refuses a
// main-actor-isolated conformance to it. The continuation is guarded by a lock instead, because
// an authorization change and a location fix arrive through different callbacks and nothing
// promises they are serialized.
final class OneShotLocator: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let pending = OSAllocatedUnfairLock(initialState: Pending())

    private struct Pending {
        var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
        var didRequestFix = false
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .denied, .restricted: return nil
        default: break
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let isBusy = pending.withLock { state in
                    guard state.continuation == nil else { return true }
                    state.continuation = continuation
                    return false
                }

                // One read at a time per instance: a second caller gets nothing rather than
                // displacing the first one's continuation, which would leak it unresumed.
                guard !isBusy else {
                    continuation.resume(returning: nil)
                    return
                }

                if manager.authorizationStatus == .notDetermined {
                    // Asking for a fix before the answer arrives only produces a failure, so let
                    // `locationManagerDidChangeAuthorization` ask once the answer is in.
                    manager.requestWhenInUseAuthorization()
                } else {
                    requestFix()
                }
            }
        } onCancel: {
            // Nothing else would ever resume this: if the permission dialog is dismissed without
            // an answer, no callback fires at all.
            finish(with: nil)
        }
    }

    private func requestFix() {
        let shouldRequest = pending.withLock { state in
            guard state.continuation != nil, !state.didRequestFix else { return false }
            state.didRequestFix = true
            return true
        }
        // Outside the lock: never call into CoreLocation while holding it.
        if shouldRequest { manager.requestLocation() }
    }

    // The one place a continuation is resumed, and it resumes at most once.
    private func finish(with coordinate: CLLocationCoordinate2D?) {
        let continuation = pending.withLock { state in
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume(returning: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        finish(with: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix()
        case .denied, .restricted:
            finish(with: nil)
        default:
            break
        }
    }
}
