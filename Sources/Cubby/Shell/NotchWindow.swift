// Adapté de NotchDrop (github.com/Lakr233/NotchDrop, licence MIT).
import Cocoa

extension NSScreen {
    // Taille réelle de l'encoche (0 si l'écran n'en a pas).
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0 else { return .zero }
        let h = safeAreaInsets.top
        let left = auxiliaryTopLeftArea?.width ?? 0
        let right = auxiliaryTopRightArea?.width ?? 0
        guard left > 0, right > 0 else { return .zero }
        return CGSize(width: frame.width - left - right, height: h)
    }

    var isBuiltinDisplay: Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let id = deviceDescription[key], let rid = (id as? NSNumber)?.uint32Value else { return false }
        return CGDisplayIsBuiltin(rid) == 1
    }

    static var builtin: NSScreen? { screens.first { $0.isBuiltinDisplay } }
}

final class NotchWindow: NSWindow {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask,
                  backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        isOpaque = false
        alphaValue = 1
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        level = .statusBar + 8
        hasShadow = false
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
