// Adapté de NotchDrop (MIT).
import AppKit
import SwiftUI

@MainActor
final class NotchWindowController: NSWindowController {
    let shell: NotchShellModel
    private let stripHeight: CGFloat = 300

    init(screen: NSScreen, music: MusicModel, match: MatchModel) {
        var notch = screen.notchSize
        let inset: CGFloat = (notch == .zero) ? 0 : -4
        let shellModel = NotchShellModel(inset: inset)
        shell = shellModel
        shellModel.resolveOpenTab = { [weak shellModel] in
            guard let shellModel else { return nil }
            return resolvePinTab(shell: shellModel, music: music, match: match)
        }

        let win = NotchWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: win)

        let root = NotchRootView(shell: shell, music: music, match: match)
        let host = NSHostingView(rootView: root)
        win.contentView = host

        // bande en haut de l'écran, pleine largeur
        let frame = CGRect(x: screen.frame.minX,
                           y: screen.frame.maxY - stripHeight,
                           width: screen.frame.width,
                           height: stripHeight)
        win.setFrame(frame, display: true)

        // zone de l'encoche (coords écran) pour le hit-test souris
        if notch == .zero { notch = CGSize(width: 180, height: 32) }
        shell.deviceNotchRect = CGRect(
            x: screen.frame.minX + (screen.frame.width - notch.width) / 2,
            y: screen.frame.minY + screen.frame.height - notch.height,
            width: notch.width, height: notch.height
        )
        shell.screenRect = screen.frame

        win.orderFrontRegardless()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func destroy() {
        window?.close()
        window = nil
    }
}
