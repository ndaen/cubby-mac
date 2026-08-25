import Foundation

enum PomodoroPhase: Equatable {
    case work, shortBreak, longBreak
}

struct PomodoroSettings: Equatable {
    var work: TimeInterval
    var shortBreak: TimeInterval
    var longBreak: TimeInterval
    var sessionsBeforeLongBreak: Int

    static let defaults = PomodoroSettings(work: 25 * 60, shortBreak: 5 * 60,
                                           longBreak: 15 * 60, sessionsBeforeLongBreak: 4)
}

struct PomodoroCycle: Equatable {
    private(set) var phase: PomodoroPhase = .work
    private(set) var completedWorkSessions: Int = 0

    func duration(in settings: PomodoroSettings) -> TimeInterval {
        switch phase {
        case .work: return settings.work
        case .shortBreak: return settings.shortBreak
        case .longBreak: return settings.longBreak
        }
    }

    // Le restant se déduit de la date de fin plutôt que d'un compteur décrémenté :
    // un compteur dérive, et se fige pendant que le Mac dort.
    static func remaining(until endsAt: Date, now: Date) -> TimeInterval {
        max(endsAt.timeIntervalSince(now), 0)
    }

    mutating func advance(settings: PomodoroSettings) {
        switch phase {
        case .work:
            completedWorkSessions += 1
            let threshold = max(settings.sessionsBeforeLongBreak, 1)   // un seuil à 0 = pause longue à chaque session
            phase = completedWorkSessions % threshold == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
    }
}
