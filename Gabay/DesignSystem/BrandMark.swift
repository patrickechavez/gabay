//
//  BrandMark.swift
//  Gabay
//

import SwiftUI

// The app icon's heart, drawn rather than shipped as an image. An app icon is compiled into the
// bundle's icon slot and cannot be loaded as a named image, and drawing it lets both halves take
// their colour from the theme, so the mark follows the app into dark mode on its own.
struct BrandMark: View {

    // Stroke width as a fraction of the mark's side, matching the 9 in 100 of the design grid the
    // curves below are written on. Scaled here because a fixed width would not follow the frame.
    private static let strokeRatio: CGFloat = 0.09

    // Defaults suit a light page. On the brand colour itself the trailing half would be invisible,
    // so a screen painted in it passes its own pair.
    var leadingColor: Color = Theme.Color.routeLine
    var trailingColor: Color = Theme.Color.brand

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let style = StrokeStyle(
                lineWidth: side * Self.strokeRatio,
                lineCap: .round,
                lineJoin: .round
            )

            ZStack {
                HeartHalf(isTrailing: false).stroke(leadingColor, style: style)
                HeartHalf(isTrailing: true).stroke(trailingColor, style: style)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// One lobe of the heart. The shape is symmetric about its centre line, so the trailing half is the
// leading half with its x coordinates reflected, which keeps the two in step if either is retuned.
private struct HeartHalf: Shape {

    let isTrailing: Bool

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100

        func point(_ gridX: CGFloat, _ gridY: CGFloat) -> CGPoint {
            CGPoint(x: (isTrailing ? 100 - gridX : gridX) * scale, y: gridY * scale)
        }

        var path = Path()
        path.move(to: point(50, 80))
        path.addCurve(to: point(34, 29), control1: point(21, 58), control2: point(20, 36))
        path.addCurve(to: point(50, 37), control1: point(43, 24), control2: point(50, 31))
        return path
    }
}
