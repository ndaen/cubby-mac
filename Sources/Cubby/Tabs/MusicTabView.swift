import SwiftUI
import AppKit

@MainActor
final class MusicModel: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var playing = false
    @Published var available = false
    @Published var artwork: NSImage?

    // position lue au dernier poll + date de ce poll → interpolation fluide
    @Published var basePosition: Double = 0
    @Published var duration: Double = 0
    private(set) var baseDate = Date()
    private var trackKey = ""

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    // position affichée, interpolée entre deux polls
    func displayPosition(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        let p = playing ? basePosition + date.timeIntervalSince(baseDate) : basePosition
        return min(max(p, 0), duration)
    }

    @discardableResult
    private func run(_ src: String) -> String? {
        var err: NSDictionary?
        let out = NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err { log("AppleScript: \(err[NSAppleScript.errorMessage] ?? "?")"); return nil }
        return out?.stringValue
    }

    func playPause() { run(#"tell application "Music" to playpause"#); bump() }
    func next()      { run(#"tell application "Music" to next track"#); bump() }
    func previous()  { run(#"tell application "Music" to previous track"#); bump() }
    func openMusic() { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app")) }

    func seek(to seconds: Double) {
        // 1) maj optimiste immédiate → l'UI réagit tout de suite, pas de lag
        basePosition = min(max(seconds, 0), duration)
        baseDate = Date()
        // 2) envoi AppleScript en arrière-plan → ne bloque pas le thread principal
        let s = Int(seconds)
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            NSAppleScript(source: "tell application \"Music\" to set player position to \(s)")?
                .executeAndReturnError(&err)
        }
    }

    private func bump() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    private func refresh() {
        let script = """
        if application "Music" is running then
          tell application "Music"
            set ps to player state as text
            if ps is "playing" or ps is "paused" then
              set pos to 0
              set dur to 0
              try
                set pos to (player position as integer)
              end try
              try
                set dur to ((duration of current track) as integer)
              end try
              return ps & "|" & (name of current track) & "|" & (artist of current track) & "|" & (pos as text) & "|" & (dur as text)
            end if
            return ps & "||||"
          end tell
        else
          return "notrunning||||"
        end if
        """
        guard let res = run(script) else { available = false; return }
        let parts = res.components(separatedBy: "|")
        let state = parts.first ?? ""
        if state == "notrunning" {
            available = false; playing = false; title = ""; artist = ""; artwork = nil
            return
        }
        available = true
        playing = (state == "playing")
        let newTitle = parts.count > 1 ? parts[1] : ""
        title = newTitle
        artist = parts.count > 2 ? parts[2] : ""
        basePosition = parts.count > 3 ? (Double(parts[3]) ?? 0) : 0
        duration = parts.count > 4 ? (Double(parts[4]) ?? 0) : 0
        baseDate = Date()

        let key = newTitle + "|" + artist
        if key != trackKey { trackKey = key; fetchArtwork() }
    }

    private func fetchArtwork() {
        let src = """
        if application "Music" is running then
          tell application "Music"
            try
              return (data of artwork 1 of current track)
            end try
          end tell
        end if
        """
        var err: NSDictionary?
        guard let desc = NSAppleScript(source: src)?.executeAndReturnError(&err) else { artwork = nil; return }
        let data = desc.data
        artwork = data.isEmpty ? nil : NSImage(data: data)
    }
}

struct MusicTabView: View {
    // Modèle partagé, démarré au lancement par Services — il vit en continu
    // pour alimenter aussi l'épingle latérale quand l'encoche est fermée.
    @ObservedObject var music: MusicModel
    @ObservedObject private var loc = Loc.shared

    var body: some View {
        Group {
            if music.available { player } else { notRunning }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var player: some View {
        HStack(spacing: 14) {
            artworkView
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(music.title.isEmpty ? "—" : music.title).font(.headline).lineLimit(1)
                        Text(music.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    // ouvre / ramène Apple Music au premier plan
                    Button { music.openMusic() } label: {
                        Image(systemName: "arrow.up.forward.app.fill").font(.system(size: 14))
                            .frame(width: 16, height: 16)
                    }
                    .glassButton()
                    .help(loc.s("Open Apple Music", "Ouvrir Apple Music"))
                }
                scrubber
                HStack(spacing: 8) {
                    Spacer()
                    ctrl("backward.fill") { music.previous() }
                    ctrl(music.playing ? "pause.fill" : "play.fill", big: true) { music.playPause() }
                    ctrl("forward.fill") { music.next() }
                    Spacer()
                }
            }
        }
    }

    private var artworkView: some View {
        Group {
            if let art = music.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassBG(Rectangle())
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // tap sur la pochette → ouvre / ramène Apple Music au premier plan
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(4)
        }
        .onTapGesture { music.openMusic() }
        .help(loc.s("Open Apple Music", "Ouvrir Apple Music"))
    }

    private var scrubber: some View {
        TimelineView(.animation(minimumInterval: 0.03, paused: !music.playing)) { ctx in
            let pos = music.displayPosition(at: ctx.date)
            VStack(spacing: 2) {
                Scrubber(position: pos, duration: music.duration) { music.seek(to: $0) }
                HStack {
                    Text(timeStr(pos)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Text(timeStr(music.duration)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func ctrl(_ name: String, big: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: big ? 18 : 13))
                .frame(width: big ? 20 : 14, height: big ? 20 : 14)
        }
        .glassButton()
    }

    private var notRunning: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
            Text(loc.s("Apple Music isn’t open", "Apple Music n’est pas ouvert")).foregroundStyle(.secondary)
            Button(loc.s("Open Music", "Ouvrir Music")) { music.openMusic() }.controlSize(.small).glassButton()
        }
    }

    private func timeStr(_ s: Double) -> String {
        let t = Int(s); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

struct Scrubber: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void

    // fraction en cours de drag : tant qu'elle est non nil, l'UI la suit
    @State private var dragFrac: Double? = nil

    private let barHeight: CGFloat = 6
    private let knobW: CGFloat = 16
    private let knobH: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let liveFrac = duration > 0 ? min(max(position / duration, 0), 1) : 0
            let frac = dragFrac ?? liveFrac
            let dragging = dragFrac != nil
            let x = w * frac

            ZStack(alignment: .leading) {
                // piste
                Capsule().fill(.clear).glassBG(Capsule())
                    .frame(height: barHeight)
                // remplissage
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: max(0, x), height: barHeight)
                // poignée : capsule blanche au repos → glass quand on l'attrape
                Capsule()
                    .fill(dragging ? Color.clear : Color.white)
                    .glassBG(Capsule(), active: dragging)
                    .frame(width: knobW, height: knobH)
                    .shadow(color: .black.opacity(0.3), radius: dragging ? 3 : 1, y: 0.5)
                    .scaleEffect(dragging ? 1.2 : 1)
                    .offset(x: min(max(x - knobW / 2, 0), w - knobW))
                    .animation(.easeOut(duration: 0.12), value: dragging)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard duration > 0, w > 0 else { return }
                        dragFrac = min(max(v.location.x / w, 0), 1)   // suit le doigt en direct
                    }
                    .onEnded { v in
                        guard duration > 0, w > 0 else { dragFrac = nil; return }
                        let f = min(max(v.location.x / w, 0), 1)
                        dragFrac = f
                        onSeek(f * duration)
                        // garde la valeur posée le temps que le modèle rattrape → pas de retour en arrière
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dragFrac = nil }
                    }
            )
        }
        .frame(height: 18)
    }
}
