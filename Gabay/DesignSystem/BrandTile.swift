//
//  BrandTile.swift
//  Gabay
//

import SwiftUI

// The app's mark: the icon's heart on its own pine tile. Carrying its background rather than
// adapting to the screen's is what lets it keep one pair of colours everywhere, since cream is
// invisible on a white page and pine is invisible on a pine one.
struct BrandTile: View {

    // iOS rounds an app icon at roughly 22.4% of its side. Matching that is what makes this read as
    // the icon the user tapped rather than as a generic rounded square.
    private static let cornerRatio: CGFloat = 0.224

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            RoundedRectangle(cornerRadius: side * Self.cornerRatio, style: .continuous)
                .fill(Theme.Color.brandSurface)
                .overlay { BrandMark() }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// Sized to its frame, with the same margin the icon artwork has, so the tile needs no inset.
private struct BrandMark: View {

    // Stroke width as a fraction of the mark's side, matching the 9 in 100 of the design grid the
    // curves below are written on. Scaled here because a fixed width would not follow the frame.
    private static let strokeRatio: CGFloat = 0.09

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let style = StrokeStyle(
                lineWidth: side * Self.strokeRatio,
                lineCap: .round,
                lineJoin: .round
            )

            ZStack {
                HeartHalf(isTrailing: false).stroke(Theme.Color.routeLine, style: style)
                HeartHalf(isTrailing: true).stroke(Theme.Color.onBrand, style: style)
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
