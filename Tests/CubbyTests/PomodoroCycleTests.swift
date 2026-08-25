import XCTest
@testable import Cubby

final class PomodoroCycleTests: XCTestCase {
    // Une phase de travail achevée mène à une pause courte et compte une session.
    func testWorkAdvancesToShortBreakAndCountsTheSession() {
        var cycle = PomodoroCycle()
        cycle.advance(settings: .defaults)
        XCTAssertEqual(cycle.phase, .shortBreak)
        XCTAssertEqual(cycle.completedWorkSessions, 1)
    }

    // Une pause achevée ramène au travail, sans toucher au compteur de sessions.
    func testBreakAdvancesBackToWork() {
        var cycle = PomodoroCycle()
        cycle.advance(settings: .defaults)   // travail → pause courte
        cycle.advance(settings: .defaults)   // pause courte → travail
        XCTAssertEqual(cycle.phase, .work)
        XCTAssertEqual(cycle.completedWorkSessions, 1)
    }

    // La dernière session avant le seuil ouvre une pause longue, pas une courte.
    func testWorkSessionAtThresholdAdvancesToLongBreak() {
        var cycle = PomodoroCycle()
        let settings = PomodoroSettings.defaults   // seuil = 4 sessions
        for _ in 0..<3 {
            cycle.advance(settings: settings)      // travail → pause courte
            cycle.advance(settings: settings)      // pause courte → travail
        }
        cycle.advance(settings: settings)          // 4e session de travail
        XCTAssertEqual(cycle.phase, .longBreak)
        XCTAssertEqual(cycle.completedWorkSessions, 4)
    }

    // Le seuil vient d'un réglage utilisateur : à zéro, il ne doit pas faire de modulo par zéro.
    func testZeroThresholdDoesNotTrap() {
        var cycle = PomodoroCycle()
        var settings = PomodoroSettings.defaults
        settings.sessionsBeforeLongBreak = 0
        cycle.advance(settings: settings)
        XCTAssertEqual(cycle.phase, .longBreak)
    }

    // Chaque phase tire sa durée des réglages.
    func testDurationFollowsThePhase() {
        var settings = PomodoroSettings.defaults
        settings.work = 30 * 60
        settings.shortBreak = 4 * 60
        settings.longBreak = 20 * 60

        var cycle = PomodoroCycle()
        XCTAssertEqual(cycle.duration(in: settings), 30 * 60)
        cycle.advance(settings: settings)
        XCTAssertEqual(cycle.duration(in: settings), 4 * 60)
    }

    // Le restant se déduit d'une date de fin : après une veille, il ne reste rien
    // à rattraper — et il ne descend jamais sous zéro.
    func testRemainingIsDerivedFromTheEndDateAndFloorsAtZero() {
        let end = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertEqual(PomodoroCycle.remaining(until: end,
                                               now: Date(timeIntervalSinceReferenceDate: 940)), 60)
        XCTAssertEqual(PomodoroCycle.remaining(until: end,
                                               now: Date(timeIntervalSinceReferenceDate: 50_000)), 0)
    }
}
