import SwiftUI
import AppKit

func log(_ s: String) { FileHandle.standardError.write(Data("[cubby] \(s)\n".utf8)) }

@main
struct CubbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @AppStorage("cubby.showScores") private var showScores = false

    var body: some Scene {
        MenuBarExtra("Cubby", systemImage: "eyes") {
            Toggle("Show Scores tab", isOn: $showScores)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuild),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        Services.shared.start()
        rebuild()
    }

    @objc func rebuild() { Services.shared.rebuildWindow() }
}

// Orchestration : modèles + fenêtre encoche.
@MainActor
final class Services {
    static let shared = Services()

    let music = MusicModel()
    let match = MatchModel()
    private var windowController: NotchWindowController?

    func start() {
        music.start()   // poll continu → alimente l'onglet ET l'épingle latérale
        match.start()   // scores en continu → onglet + épingle
        log("services démarrés")
    }

    func rebuildWindow() {
        windowController?.destroy()
        let screen = NSScreen.builtin ?? NSScreen.main
        guard let screen else { return }
        windowController = NotchWindowController(screen: screen, music: music, match: match)
    }
}
