import SwiftUI

// Compose le matériau : teinte (= prominence) et réaction au pointeur.
// Séparé de la vue car un @ViewBuilder n'accepte pas de statements.
@available(macOS 26.0, *)
private func cubbyGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    // Fond « Liquid Glass » (macOS 26), repli matériel sinon.
    // `interactive` : réservé aux vues cliquables — le verre se déforme et
    // s'illumine sous le pointeur, comme les contrôles système.
    @ViewBuilder
    func glassBG<S: Shape>(_ shape: S, active: Bool = true, tint: Color? = nil,
                           interactive: Bool = false) -> some View {
        if active {
            if #available(macOS 26.0, *) {
                self.glassEffect(cubbyGlass(tint: tint, interactive: interactive), in: shape)
            } else {
                self.background(.ultraThinMaterial, in: shape)
                    .background((tint ?? .clear).opacity(0.25), in: shape)
            }
        } else {
            self
        }
    }

    // Style de bouton « Liquid Glass » (macOS 26), repli sinon.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glassButtonProminent() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
