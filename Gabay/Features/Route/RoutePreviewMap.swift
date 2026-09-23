//
//  RoutePreviewMap.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import MapKit
import SwiftUI

// A read-only drawing of a route: no live position, no following, no
// compass. Used both for an organizer confirming an upload and for a
// hiker deciding whether to show up. Named apart from the free-trail
// app's still-present TrailMapView/RouteMapView/RouteCasing, which share
// this target until Task 12 removes them.
struct RoutePreviewMap: UIViewRepresentable {

    let points: [TrackPoint]

    func makeUIView(context: Context) -> FramedMapView {
        let view = FramedMapView()
        view.delegate = context.coordinator

        // Blue would suggest a live position, which this view never has.
        view.tintColor = .systemGray
        view.showsCompass = false
        view.pointOfInterestFilter = .excludingAll

        draw(on: view)
        return view
    }

    func updateUIView(_ view: FramedMapView, context: Context) {
        // The route a screen shows never changes after it is first drawn.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func draw(on view: FramedMapView) {
        guard points.count > 1 else { return }

        let coordinates = points.map(\.coordinate)
        let route = MKPolyline(coordinates: coordinates, count: coordinates.count)

        // A white casing, so the line reads against forest and rock alike.
        view.addOverlay(RouteLineCasing(coordinates: coordinates, count: coordinates.count))
        view.addOverlay(route)
        view.frame(route: route.boundingMapRect)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }

            let renderer = MKPolylineRenderer(polyline: line)
            let isCasing = overlay is RouteLineCasing

            // Named: converting Color.accentColor gives the system accent instead.
            renderer.strokeColor = isCasing ? .white : UIColor(named: "AccentColor")
            renderer.lineWidth = isCasing ? 9 : 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

// The wider line drawn underneath the route.
final class RouteLineCasing: MKPolyline {}

// Frames the route the first time the map has a size. Setting a map rect
// on a zero sized view does nothing, and that is the state at make time.
final class FramedMapView: MKMapView {

    private static let padding = UIEdgeInsets(top: 40, left: 24, bottom: 40, right: 24)

    private var pending: MKMapRect?

    func frame(route rect: MKMapRect) {
        pending = rect
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
