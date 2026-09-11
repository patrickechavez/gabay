//
//  TrailMapView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import CoreLocation
import MapKit
import SwiftUI

// The route and where you are on it.
//
// Apple serves the basemap, so it goes grey with no signal. The line and the
// position do not: both are drawn from data already on the phone, which is the
// half that answers "am I still on the trail".
struct TrailMapView: UIViewRepresentable {

    let points: [TrackPoint]

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

        // The dot takes the app tint, which would make the walker the same
        // colour as the route. Blue for you, magenta for the trail.
        view.tintColor = .systemBlue
        view.showsCompass = true
        view.pointOfInterestFilter = .excludingAll

        draw(on: view)
        return view
    }

    func updateUIView(_ view: RouteMapView, context: Context) {
        if context.coordinator.points != points {
            context.coordinator.points = points
            draw(on: view)
        }

        let mode: MKUserTrackingMode = isFollowing ? .follow : .none
        if view.userTrackingMode != mode {
            view.setUserTrackingMode(mode, animated: true)

            // Letting go of the walker means going back to the trail, rather
            // than leaving the map wherever they happened to be.
            if mode == .none { view.frameRouteAgain() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(points: points, isFollowing: $isFollowing, position: $position)
    }

    private func draw(on view: RouteMapView) {
        view.removeOverlays(view.overlays)
        guard points.count > 1 else { return }

        let coordinates = points.map(\.coordinate)
        let route = MKPolyline(coordinates: coordinates, count: coordinates.count)

        // A white casing under the line, so it reads against forest, rock and
        // whatever else is on the basemap.
        view.addOverlay(RouteCasing(coordinates: coordinates, count: coordinates.count))
        view.addOverlay(route)
        view.frame(route: route.boundingMapRect)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {

        var points: [TrackPoint]

        @Binding private var isFollowing: Bool

        @Binding private var position: CLLocationCoordinate2D?

        // Held for the life of the screen: a manager that goes out of scope
        // never delivers its answer.
        private let locations = CLLocationManager()

        // Held so the cone can be turned as the compass moves. The manager
        // stops on its own when the coordinator goes.
        private weak var walker: WalkerAnnotationView?

        init(
            points: [TrackPoint],
            isFollowing: Binding<Bool>,
            position: Binding<CLLocationCoordinate2D?>
        ) {
            self.points = points
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

            // Named rather than converted from Color.accentColor, which
            // resolves to the system accent instead of the asset.
            renderer.strokeColor = isCasing ? .white : UIColor(named: "AccentColor")
            renderer.lineWidth = isCasing ? 9 : 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        // Panning by hand means the walker wants to look around, so stop
        // dragging the map back under them.
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard mapView.userTrackingMode == .none, isFollowing else { return }
            isFollowing = false
        }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
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

        // The cone points at the world, so it turns with the map as well as
        // with the walker.
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            walker?.mapHeading = mapView.camera.heading
        }

    }
}

// The wider line drawn underneath the route.
final class RouteCasing: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect on a
// zero sized view does nothing, and that is the state at make time.
final class RouteMapView: MKMapView {

    private static let padding = UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40)

    private var route: MKMapRect?
    private var pending: MKMapRect?

    // The whole route, every time the screen opens. Predictable, and the shape
    // of the walk is the information. Where the walker is belongs to the
    // button, not to the camera.
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
