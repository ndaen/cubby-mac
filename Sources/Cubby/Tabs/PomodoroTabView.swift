import SwiftUI

struct PomodoroTabView: View {
    @ObservedObject var pomo: PomodoroModel
    @ObservedObject private var loc = Loc.shared

    var body: some View {
        HStack(spacing: 22) {
            dial
            VStack(alignment: .leading, spacing: 10) {
                Label(pomo.cycle.phase.title(loc), systemImage: pomo.cycle.phase.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(sessionsLine).font(.caption).foregroundStyle(.secondary)
                controls
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var sessionsLine: String {
        let n = pomo.cycle.completedWorkSessions
        return n == 1 ? loc.s("1 session done", "1 session faite")
                      : loc.s("\(n) sessions done", "\(n) sessions faites")
    }

    private var dial: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(pomo.progress, 0.001))
                .stroke(Color.cubby, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: pomo.progress)
            Text(pomo.clock)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
        }
        .frame(width: 108, height: 108)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(pomo.running ? loc.s("Pause", "Pause") : loc.s("Start", "Démarrer")) {
                pomo.running ? pomo.pause() : pomo.start()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .glassBG(Capsule(), tint: .cubby.opacity(0.28), interactive: true)

            iconButton("arrow.counterclockwise", loc.s("Reset", "Réinitialiser")) { pomo.reset() }
            iconButton("forward.end.fill", loc.s("Skip", "Passer")) { pomo.skip() }
        }
    }

    private func iconButton(_ symbol: String, _ help: String,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .padding(7)
                .glassBG(Circle(), interactive: true)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
