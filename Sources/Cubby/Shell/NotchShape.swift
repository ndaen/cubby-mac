import SwiftUI

// Forme « encoche » : bord supérieur pleine largeur qui s'évase (coins concaves)
// pour rejoindre le noir du haut de l'écran, et bas aux coins arrondis (convexes).
// La largeur utile (intérieure) = rect.width - 2*topRadius.
struct NotchShape: Shape {
    var topRadius: CGFloat = 12
    var bottomRadius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let tr = min(topRadius, w / 2)
        let br = min(bottomRadius, max(0, (w - 2 * tr) / 2), h)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        // coin haut-droit : concave (s'évase vers l'extérieur)
        p.addQuadCurve(to: CGPoint(x: w - tr, y: tr), control: CGPoint(x: w - tr, y: 0))
        p.addLine(to: CGPoint(x: w - tr, y: h - br))
        // coin bas-droit : convexe
        p.addQuadCurve(to: CGPoint(x: w - tr - br, y: h), control: CGPoint(x: w - tr, y: h))
        p.addLine(to: CGPoint(x: tr + br, y: h))
        // coin bas-gauche : convexe
        p.addQuadCurve(to: CGPoint(x: tr, y: h - br), control: CGPoint(x: tr, y: h))
        p.addLine(to: CGPoint(x: tr, y: tr))
        // coin haut-gauche : concave
        p.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: tr, y: 0))
        p.closeSubpath()
        return p
    }
}
