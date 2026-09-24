//
//  LocationPicker.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import CoreLocation
import MapKit
import SwiftUI

// Pin-drop for a meeting point: opens on the organizer's current location if they allow it, otherwise a fixed region around Cebu, tap anywhere to move the pin.
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
    private let locator = OneShotLocator()

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

// A single current-location read, nothing held past that: no background mode, no continuous updates, just "where am I right now."
//
// Not @MainActor: CLLocationManagerDelegate is a non-isolated protocol and Swift 6 refuses a main-actor-isolated
// conformance to it. @unchecked Sendable is safe since there's never more than one in-flight request per instance,
// the same escape hatch StubURLProtocol uses elsewhere in this codebase for the same kind of delegate bridging.
final class OneShotLocator: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // A permission decision made while a request is pending: ask again now that we know the answer, or give up if it was denied.
        guard continuation != nil else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(returning: nil)
            continuation = nil
        default:
            break
        }
    }
}
