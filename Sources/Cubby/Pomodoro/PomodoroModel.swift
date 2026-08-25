import SwiftUI
import AppKit

// Pilote une session Pomodoro. Toute la logique de cycle vit dans `PomodoroCycle`
// (pure, testée) ; ce modèle n'ajoute que le temps qui passe et le son de fin.
@MainActor
final class PomodoroModel: ObservableObject {
    static let shared = PomodoroModel()

    @Published private(set) var cycle = PomodoroCycle()
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var running = false

    // Appelé quand une phase arrive à son terme. Câblé par NotchWindowController
    // pour ouvrir l'encoche : le modèle n'a pas à connaître le shell.
    var onPhaseEnded: (() -> Void)?

    private var endsAt: Date?
    private var timer: Timer?

    private init() {
        remaining = PomodoroCycle().duration(in: PomodoroSettings.current)
    }

    var settings: PomodoroSettings { .current }
    var phaseDuration: TimeInterval { cycle.duration(in: settings) }
    var progress: Double {
        let total = phaseDuration
        return total > 0 ? 1 - (remaining / total) : 0
    }

    // mm:ss — arrondi au supérieur pour que le compte à rebours affiche « 25:00 »
    // à l'instant du départ, et non « 24:59 ».
    var clock: String {
        let s = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func start() {
        guard !running else { return }
        endsAt = Date().addingTimeInterval(remaining)
        running = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        guard running else { return }
        tick()                 // fige le restant à l'instant du clic
        stopTimer()
    }

    // Repart au début de la phase courante, sans toucher au décompte de sessions.
    func reset() {
        stopTimer()
        remaining = phaseDuration
    }

    // Passe à la phase suivante sans attendre la fin de celle-ci.
    func skip() {
        stopTimer()
        cycle.advance(settings: settings)
        remaining = phaseDuration
    }

    // Les réglages ont changé : la phase en cours repart sur la nouvelle durée.
    func settingsChanged() {
        guard !running else { return }
        remaining = phaseDuration
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        endsAt = nil
        running = false
    }

    private func tick() {
        guard let endsAt else { return }
        remaining = PomodoroCycle.remaining(until: endsAt, now: Date())
        guard remaining <= 0 else { return }

        stopTimer()
        cycle.advance(settings: settings)
        remaining = phaseDuration
        NSSound(named: "Glass")?.play()
        onPhaseEnded?()
    }
}

// Réglages persistés — mêmes clés que les Steppers de l'onglet Réglages.
extension PomodoroSettings {
    static var current: PomodoroSettings {
        let d = UserDefaults.standard
        func minutes(_ key: String, _ fallback: Double) -> TimeInterval {
            let v = d.double(forKey: key)
            return (v > 0 ? v : fallback) * 60
        }
        let sessions = d.integer(forKey: Keys.sessions)
        return PomodoroSettings(
            work: minutes(Keys.work, 25),
            shortBreak: minutes(Keys.shortBreak, 5),
            longBreak: minutes(Keys.longBreak, 15),
            sessionsBeforeLongBreak: sessions > 0 ? sessions : 4
        )
    }

    enum Keys {
        // même clé que MarketModel.wiredFlags["pomodoro"] : installer l'extension, c'est
        // basculer ce booléen.
        static let installed = "cubby.showPomodoro"
        static let work = "cubby.pomodoro.work"
        static let shortBreak = "cubby.pomodoro.shortBreak"
        static let longBreak = "cubby.pomodoro.longBreak"
        static let sessions = "cubby.pomodoro.sessions"
    }
}

extension PomodoroPhase {
    var icon: String {
        switch self {
        case .work: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }
    @MainActor func title(_ loc: Loc) -> String {
        switch self {
        case .work: return loc.s("Focus", "Concentration")
        case .shortBreak: return loc.s("Short break", "Pause courte")
        case .longBreak: return loc.s("Long break", "Pause longue")
        }
    }
}
