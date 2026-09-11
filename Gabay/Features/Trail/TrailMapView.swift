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

    func makeUIView(context: Context) -> RouteMapView {
        context.coordinator.askForLocation()

        let view = RouteMapView()
        view.delegate = context.coordinator
        view.showsUserLocation = true

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
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(points: points, isFollowing: $isFollowing)
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
        view.routeToFrame = route.boundingMapRect
    }

    final class Coordinator: NSObject, MKMapViewDelegate {

        var points: [TrackPoint]

        @Binding private var isFollowing: Bool

        // Held for the life of the screen: a manager that goes out of scope
        // never delivers its answer.
        private let locations = CLLocationManager()

        init(points: [TrackPoint], isFollowing: Binding<Bool>) {
            self.points = points
            _isFollowing = isFollowing
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

        // The first fix usually lands after the route is drawn, so the frame is
        // widened then rather than at load.
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let view = mapView as? RouteMapView, let coordinate = userLocation.location?.coordinate else {
                return
            }
            view.widenFrame(toInclude: coordinate)
        }
    }
}

// The wider line drawn underneath the route.
final class RouteCasing: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect on a
// zero sized view does nothing, and that is the state at make time.
final class RouteMapView: MKMapView {

    // Far enough away and the walker is not at this trail at all: framing both
    // would zoom out to an ocean. Twenty five kilometres is a drive, not a walk.
    private static let joinableDistance: CLLocationDistance = 25_000

    private static let padding = UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40)

    // The route usually arrives after the first layout, because reading the
    // file is asynchronous, so framing has to be driven from both sides.
    var routeToFrame: MKMapRect? {
        didSet { frameRouteIfPossible() }
    }

    private var route: MKMapRect?
    private var hasFramedWithUser = false

    override func layoutSubviews() {
        super.layoutSubviews()
        frameRouteIfPossible()
    }

    private func frameRouteIfPossible() {
        guard let rect = routeToFrame, bounds.width > 0 else { return }
        routeToFrame = nil
        route = rect

        setVisibleMapRect(rect, edgePadding: Self.padding, animated: false)
    }

    // Opens showing both the trail and the walker, so the first question,
    // "where am I relative to this", is answered without touching anything.
    func widenFrame(toInclude coordinate: CLLocationCoordinate2D) {
        guard !hasFramedWithUser, let route, bounds.width > 0 else { return }

        let walker = MKMapPoint(coordinate)
        let reach = route.insetBy(
            dx: -Self.joinableDistance * MKMapPointsPerMeterAtLatitude(coordinate.latitude),
            dy: -Self.joinableDistance * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        )
        guard reach.contains(walker) else { return }

        hasFramedWithUser = true
        setVisibleMapRect(
            route.union(MKMapRect(origin: walker, size: MKMapSize(width: 0, height: 0))),
            edgePadding: Self.padding,
            animated: true
        )
    }
}
