//
//  TrailMapView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

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
        let view = RouteMapView()
        view.delegate = context.coordinator
        view.showsUserLocation = true
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

        init(points: [TrackPoint], isFollowing: Binding<Bool>) {
            self.points = points
            _isFollowing = isFollowing
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
    }
}

// The wider line drawn underneath the route.
final class RouteCasing: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect on a
// zero sized view does nothing, and that is the state at make time.
final class RouteMapView: MKMapView {

    // The route usually arrives after the first layout, because reading the
    // file is asynchronous, so framing has to be driven from both sides.
    var routeToFrame: MKMapRect? {
        didSet { frameRouteIfPossible() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        frameRouteIfPossible()
    }

    private func frameRouteIfPossible() {
        guard let rect = routeToFrame, bounds.width > 0 else { return }
        routeToFrame = nil

        setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 180, right: 40),
            animated: false
        )
    }
}
