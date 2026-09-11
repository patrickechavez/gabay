//
//  WalkerAnnotationView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import CoreLocation
import MapKit
import UIKit

// The walker: a dot, and a cone showing which way they are facing.
//
// MapKit only draws a heading cone in follow-with-heading mode, which also
// spins the whole map. A hiker reading a trail wants north up and still wants
// to know which way they are pointing, so the dot is drawn here instead.
final class WalkerAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "walker"

    // Wide enough to read at a glance, narrow enough to mean something. A
    // compass on a phone is not accurate enough to justify a thin beam.
    private static let spread: CGFloat = 60

    private static let reach: CGFloat = 46

    private let cone = CAShapeLayer()
    private let fade = CAGradientLayer()
    private let dot = CALayer()
    private let ring = CALayer()

    // Where the walker faces, and where the map faces, since the cone has to
    // account for both.
    var heading: CLLocationDirection? {
        didSet { turnCone() }
    }

    var mapHeading: CLLocationDirection = 0 {
        didSet { turnCone() }
    }

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        frame = CGRect(x: 0, y: 0, width: Self.reach * 2, height: Self.reach * 2)
        isEnabled = false
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func build() {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)

        // The cone is a gradient masked by the wedge, so it fades out with
        // distance rather than ending in a hard edge. Confidence in a heading
        // falls off the same way.
        cone.frame = bounds
        cone.path = conePath(from: centre)
        cone.fillColor = UIColor.black.cgColor

        fade.frame = bounds
        fade.type = .radial
        fade.colors = [
            UIColor.systemBlue.withAlphaComponent(0.55).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.0).cgColor
        ]
        fade.locations = [0, 1]
        fade.startPoint = CGPoint(x: 0.5, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 1)
        fade.mask = cone
        fade.isHidden = true
        layer.addSublayer(fade)

        ring.frame = CGRect(x: centre.x - 11, y: centre.y - 11, width: 22, height: 22)
        ring.cornerRadius = 11
        ring.backgroundColor = UIColor.white.cgColor
        ring.shadowColor = UIColor.black.cgColor
        ring.shadowOpacity = 0.25
        ring.shadowRadius = 3
        ring.shadowOffset = CGSize(width: 0, height: 1)
        layer.addSublayer(ring)

        dot.frame = CGRect(x: centre.x - 8, y: centre.y - 8, width: 16, height: 16)
        dot.cornerRadius = 8
        dot.backgroundColor = UIColor.systemBlue.cgColor
        layer.addSublayer(dot)
    }

    // A wedge pointing up, so rotating the layer points it wherever needed.
    private func conePath(from centre: CGPoint) -> CGPath {
        let half = Self.spread / 2 * .pi / 180
        let upwards = -CGFloat.pi / 2

        let path = UIBezierPath()
        path.move(to: centre)
        path.addArc(
            withCenter: centre,
            radius: Self.reach,
            startAngle: upwards - half,
            endAngle: upwards + half,
            clockwise: true
        )
        path.close()
        return path.cgPath
    }

    private func turnCone() {
        guard let heading, heading >= 0 else {
            fade.isHidden = true
            return
        }

        fade.isHidden = false

        // Rotations are not animated: the compass jitters, and a cone easing
        // between angles lags behind where the walker is actually looking.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.transform = CATransform3DMakeRotation((heading - mapHeading) * .pi / 180, 0, 0, 1)
        CATransaction.commit()
    }
}
