//
//  TrailMapView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import CoreLocation
import MapKit
import SwiftUI

// The route and where you are on it. Apple's basemap goes grey with no signal,
// the line and the dot do not.
struct TrailMapView: UIViewRepresentable {

    let points: [TrackPoint]

    // The walk being recorded, or the one being looked back at.
    var track: [TrackPoint] = []

    // Frames the track when there is no route to frame instead.
    var framesTrack = false

    // Keeps the map centred on the walker rather than the route.
    @Binding var isFollowing: Bool

    // Reported back so a screen can say how far the start is.
    @Binding var position: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> RouteMapView {
        context.coordinator.askForLocation()

        let view = RouteMapView()
        view.delegate = context.coordinator
        view.showsUserLocation = true
        view.register(
            WalkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: WalkerAnnotationView.reuseIdentifier
        )

        // Blue for you, magenta for the trail, or the tint makes them the same.
        view.tintColor = .systemBlue
        view.showsCompass = true
        view.pointOfInterestFilter = .excludingAll

        drawRoute(on: view)
        drawTrack(on: view)
        return view
    }

    func updateUIView(_ view: RouteMapView, context: Context) {
        if context.coordinator.points != points {
            context.coordinator.points = points
            drawRoute(on: view)
        }

        if context.coordinator.track != track {
            context.coordinator.track = track
            drawTrack(on: view)
        }

        let mode: MKUserTrackingMode = isFollowing ? .follow : .none
        if view.userTrackingMode != mode {
            view.setUserTrackingMode(mode, animated: true)

            // Letting go of the walker goes back to the trail.
            if mode == .none { view.frameRouteAgain() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(points: points, track: track, isFollowing: $isFollowing, position: $position)
    }

    private func drawRoute(on view: RouteMapView) {
        view.removeOverlays(view.overlays.filter { !($0 is RecordedTrack) })
        guard points.count > 1 else { return }

        let coordinates = points.map(\.coordinate)
        let route = MKPolyline(coordinates: coordinates, count: coordinates.count)

        // A white casing, so the line reads against forest and rock alike.
        view.addOverlay(RouteCasing(coordinates: coordinates, count: coordinates.count))
        view.addOverlay(route)
        view.frame(route: route.boundingMapRect)
    }

    // Drawn last, so where you have been sits over where you are going.
    private func drawTrack(on view: RouteMapView) {
        view.removeOverlays(view.overlays.filter { $0 is RecordedTrack })
        guard track.count > 1 else { return }

        let coordinates = track.map(\.coordinate)
        let walked = RecordedTrack(coordinates: coordinates, count: coordinates.count)
        view.addOverlay(walked)

        if framesTrack, points.isEmpty { view.frame(route: walked.boundingMapRect) }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {

        var points: [TrackPoint]

        var track: [TrackPoint]

        @Binding private var isFollowing: Bool

        @Binding private var position: CLLocationCoordinate2D?

        // Held for the screen's life: a manager that goes out of scope says nothing.
        private let locations = CLLocationManager()

        // Held so the cone can turn as the compass moves.
        private weak var walker: WalkerAnnotationView?

        init(
            points: [TrackPoint],
            track: [TrackPoint],
            isFollowing: Binding<Bool>,
            position: Binding<CLLocationCoordinate2D?>
        ) {
            self.points = points
            self.track = track
            _isFollowing = isFollowing
            _position = position
            super.init()

            locations.delegate = self
            locations.startUpdatingHeading()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
            // True north where the phone knows it, magnetic where it does not.
            walker?.heading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        }

        // The map shows the dot, but nothing shows it until somebody asks.
        func askForLocation() {
            guard locations.authorizationStatus == .notDetermined else { return }
            locations.requestWhenInUseAuthorization()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }

            let renderer = MKPolylineRenderer(polyline: line)
            let isCasing = overlay is RouteCasing

            // Blue for where you have been, to match the dot that made it.
            if overlay is RecordedTrack {
                renderer.strokeColor = .systemBlue
            } else {
                // Named: converting Color.accentColor gives the system accent instead.
                renderer.strokeColor = isCasing ? .white : UIColor(named: "AccentColor")
            }
            renderer.lineWidth = isCasing ? 9 : 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        // The only place following turns off by itself. Guessing from region
        // changes raced the animation and ate taps.
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            guard isFollowing != (mode != .none) else { return }
            isFollowing = mode != .none
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            position = userLocation.location?.coordinate
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKUserLocation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: WalkerAnnotationView.reuseIdentifier,
                for: annotation
            ) as? WalkerAnnotationView

            view?.mapHeading = mapView.camera.heading
            walker = view
            return view
        }

        // The cone points at the world, so it turns with the map too.
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            walker?.mapHeading = mapView.camera.heading
        }

    }
}

// The wider line drawn underneath the route.
final class RouteCasing: MKPolyline {}

// The walk itself, as opposed to the trail it followed.
final class RecordedTrack: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect on a
// zero sized view does nothing, and that is the state at make time.
final class RouteMapView: MKMapView {

    private static let padding = UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40)

    private var route: MKMapRect?
    private var pending: MKMapRect?

    // The whole route, every time. Where the walker is belongs to the button.
    func frame(route rect: MKMapRect) {
        route = rect
        pending = rect
        applyPendingFrame()
    }

    // Back from following the walker.
    func frameRouteAgain() {
        pending = route
        applyPendingFrame()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPendingFrame()
    }

    private func applyPendingFrame() {
        guard let rect = pending, bounds.width > 0 else { return }
        pending = nil

        setVisibleMapRect(rect, edgePadding: Self.padding, animated: false)
    }
}
