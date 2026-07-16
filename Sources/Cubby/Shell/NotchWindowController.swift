// Adapté de NotchDrop (MIT).
import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController: NSWindowController {
    let shell: NotchShellModel
    private let stripHeight: CGFloat = 300
    private var cancellables: Set<AnyCancellable> = []

    init(screen: NSScreen, music: MusicModel, match: MatchModel) {
        var notch = screen.notchSize
        let inset: CGFloat = (notch == .zero) ? 0 : 4
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

        // Le clic "ouvre" est détecté par un moniteur global (NotchShellModel),
        // donc la fenêtre n'a besoin de capter les clics AppKit que pendant
        // qu'elle est visible — sinon elle vole le focus sur toute la bande.
        win.ignoresMouseEvents = true
        shell.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak win] status in
                win?.ignoresMouseEvents = (status == .closed)
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func destroy() {
        window?.close()
        window = nil
    }
}
