import SwiftUI

extension View {
    // Fond « Liquid Glass » (macOS 26), repli matériel sinon.
    @ViewBuilder
    func glassBG<S: Shape>(_ shape: S, active: Bool = true, tint: Color? = nil) -> some View {
        if active {
            if #available(macOS 26.0, *) {
                self.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
            } else {
                self.background(.ultraThinMaterial, in: shape)
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
