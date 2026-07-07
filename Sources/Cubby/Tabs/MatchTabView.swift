import SwiftUI

// MARK: - Modèles API worldcup26.ir (tous les champs arrivent en String)

struct WCGame: Decodable, Identifiable, Equatable {
    let id: String
    let home_team_id: String
    let away_team_id: String
    let home_score: String
    let away_score: String
    let group: String
    let matchday: String
    let local_date: String
    let type: String
    let finished: String
    let time_elapsed: String
    let home_team_name_en: String?
    let away_team_name_en: String?
    let home_team_label: String?
    let away_team_label: String?

    var homeGoals: Int { Int(home_score) ?? 0 }
    var awayGoals: Int { Int(away_score) ?? 0 }
    var isFinished: Bool { finished.uppercased() == "TRUE" }
    var isLive: Bool {
        !isFinished && (time_elapsed.lowercased() == "live" || Int(time_elapsed) != nil)
    }
    var hasScore: Bool { isLive || isFinished }

    var minuteText: String? {
        if time_elapsed.lowercased() == "live" { return "LIVE" }
        if let m = Int(time_elapsed) { return "\(m)′" }
        return nil
    }
    func name(home: Bool) -> String {
        let n = (home ? home_team_name_en : away_team_name_en) ?? ""
        if !n.isEmpty { return n }
        return (home ? home_team_label : away_team_label) ?? "TBD"
    }
    func teamId(home: Bool) -> String { home ? home_team_id : away_team_id }
}
private struct GamesResponse: Decodable { let games: [WCGame] }

// Émis quand un score augmente entre deux rafraîchissements (déclenche la célébration).
struct GoalFlash: Equatable { let id: Int; let gameId: String; let home: Bool }

struct WCTeam: Decodable { let id: String; let name_en: String; let flag: String; let fifa_code: String; let iso2: String }
private struct TeamsResponse: Decodable { let teams: [WCTeam] }

// suivi de l'offset de défilement de la liste des matchs (pour replier la carte)
private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Modèle (partagé, démarré par Services pour alimenter aussi l'épingle)

@MainActor
final class MatchModel: ObservableObject {
    @Published var games: [WCGame] = []
    @Published var teamsById: [String: WCTeam] = [:]
    @Published var available = false   // a déjà des données (cache compris)
    @Published var loading = false
    @Published var lastError: String?
    @Published var selectedId: String?   // match choisi manuellement comme « en avant »
    @Published var lastGoal: GoalFlash?  // dernier but détecté

    private var lastScores: [String: (Int, Int)] = [:]
    private var goalCounter = 0

    private var timer: Timer?
    private let base = "https://worldcup26.ir"

    func start() {
        Task { await loadTeams(); await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    // drapeau emoji depuis le code ISO-2 (pas de chargement d'image réseau)
    func flagEmoji(forTeamId id: String) -> String {
        guard let iso = teamsById[id]?.iso2, iso.count == 2 else { return "🏳️" }
        return iso.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value).map { String($0) } }
            .joined()
    }
    func code(forTeamId id: String) -> String { teamsById[id]?.fifa_code ?? "" }

    var liveGame: WCGame? { games.first(where: { $0.isLive }) }

    var upcoming: [WCGame] {
        games.filter { !$0.isFinished && !$0.isLive }
            .sorted { (parseDate($0.local_date) ?? .distantFuture) < (parseDate($1.local_date) ?? .distantFuture) }
    }

    // match mis en avant : choix manuel > live > prochain à venir > dernier terminé
    var featured: WCGame? {
        // épinglage manuel honoré tant que le match n'est pas terminé → sinon on retombe
        // sur le prochain match automatiquement (plus de match de la veille collé en haut)
        if let sid = selectedId, let g = games.first(where: { $0.id == sid }), !g.isFinished { return g }
        if let live = liveGame { return live }
        if let next = upcoming.first { return next }
        return games.filter { $0.isFinished }
            .sorted { (parseDate($0.local_date) ?? .distantPast) > (parseDate($1.local_date) ?? .distantPast) }
            .first
    }

    func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM/dd/yyyy HH:mm"
        return f.date(from: s)
    }

    private func loadTeams() async {
        guard let url = URL(string: base + "/get/teams") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(TeamsResponse.self, from: data)
            var map: [String: WCTeam] = [:]
            for t in resp.teams { map[t.id] = t }
            teamsById = map
        } catch { log("WC teams: \(error.localizedDescription)") }
    }

    func refresh() async {
        guard let url = URL(string: base + "/get/games") else { return }
        loading = true
        defer { loading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(GamesResponse.self, from: data)
            games = resp.games
            available = true
            lastError = nil
            detectGoals()
        } catch {
            // fallback : on conserve les dernières données connues
            lastError = error.localizedDescription
            log("WC games: \(error.localizedDescription)")
        }
    }

    // compare les scores au dernier poll ; émet un GoalFlash si une équipe vient de marquer
    private func detectGoals() {
        var map: [String: (Int, Int)] = [:]
        let firstLoad = lastScores.isEmpty
        var fired: (String, Bool)?
        for g in games {
            let h = g.homeGoals, a = g.awayGoals
            map[g.id] = (h, a)
            if let prev = lastScores[g.id] {
                if h > prev.0 { fired = (g.id, true) }
                else if a > prev.1 { fired = (g.id, false) }
            }
        }
        lastScores = map
        guard !firstLoad, let f = fired else { return }
        goalCounter += 1
        lastGoal = GoalFlash(id: goalCounter, gameId: f.0, home: f.1)
    }
}

// MARK: - Vue de l'onglet

struct MatchTabView: View {
    @ObservedObject var match: MatchModel
    @State private var scrollY: CGFloat = 0

    @AppStorage("cubby.matchParticles") private var particlesOn = true
    @State private var goalSide: Bool? = nil   // côté qui célèbre (nil = aucun)
    @State private var goalAnimId = 0          // identité pour relancer l'explosion

    // 0 = carte pleine, 1 = carte réduite (selon le défilement de la liste)
    private var collapse: CGFloat { min(max(-scrollY / 46, 0), 1) }

    var body: some View {
        Group {
            if let g = match.featured {
                VStack(spacing: 6) {
                    featured(g)
                    matchList(excluding: g)
                }
            } else if match.available {
                centered("No matches", "sportscourt")
            } else {
                offline
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: match.lastGoal) { _, goal in
            guard let goal, goal.gameId == match.featured?.id else { return }
            celebrate(home: goal.home)
        }
    }

    // lance la célébration pour un côté, puis l'éteint après l'animation
    private func celebrate(home: Bool) {
        goalAnimId += 1
        goalSide = home
        let id = goalAnimId
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if goalAnimId == id { goalSide = nil }
        }
    }

    // Carte du match en avant — se replie quand on scrolle la liste
    private func featured(_ g: WCGame) -> some View {
        ZStack {
            featuredFull(g).opacity(1 - min(collapse * 1.6, 1))
            featuredMini(g).opacity(collapse)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78 - 40 * collapse)
        .padding(.horizontal, 12)
        .glassBG(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.12), value: collapse)
    }

    private func featuredFull(_ g: WCGame) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                statusBadge(g)
                Spacer()
                Text(stageLabel(g)).font(.caption2).foregroundStyle(.secondary)
                Button { particlesOn.toggle() } label: {
                    Image(systemName: "sparkles").font(.caption2)
                        .foregroundStyle(particlesOn ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(particlesOn ? "Goal particles: on" : "Goal particles: off")
            }
            HStack(alignment: .center, spacing: 10) {
                teamBlock(g, home: true)
                centerScore(g)
                teamBlock(g, home: false)
            }
        }
        .padding(.vertical, 7)
    }

    // Version repliée : une seule ligne (drapeaux + codes + score + minute)
    private func featuredMini(_ g: WCGame) -> some View {
        HStack(spacing: 8) {
            Text(match.flagEmoji(forTeamId: g.teamId(home: true)))
            Text(match.code(forTeamId: g.teamId(home: true))).font(.system(size: 13, weight: .semibold))
            if g.hasScore {
                Text("\(g.homeGoals) – \(g.awayGoals)").font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(g.isLive ? .red : .primary)
            } else {
                Text(timeOnly(g)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(match.code(forTeamId: g.teamId(home: false))).font(.system(size: 13, weight: .semibold))
            Text(match.flagEmoji(forTeamId: g.teamId(home: false)))
            if g.isLive, let m = g.minuteText {
                Text(m).font(.caption2.weight(.bold)).foregroundStyle(.red)
            }
        }
        .lineLimit(1)
    }

    private func statusBadge(_ g: WCGame) -> some View {
        Group {
            if g.isLive {
                HStack(spacing: 5) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text(g.minuteText ?? "LIVE").font(.caption2.weight(.bold))
                }
                .foregroundStyle(.red)
            } else if g.isFinished {
                Text("Full time").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                Text(dateLabel(g)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private func teamBlock(_ g: WCGame, home: Bool) -> some View {
        let flag = match.flagEmoji(forTeamId: g.teamId(home: home))
        let celeb = goalSide == home
        return VStack(spacing: 3) {
            ZStack {
                Text(flag).font(.system(size: 27))
                    .scaleEffect(celeb ? 1.55 : 1)
                    .animation(.spring(response: 0.32, dampingFraction: 0.45), value: celeb)
                if celeb && particlesOn {
                    FlagParticles(flag: flag).id(goalAnimId).allowsHitTesting(false)
                }
            }
            .frame(height: 30)
            Text(g.name(home: home)).font(.system(size: 11, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func centerScore(_ g: WCGame) -> some View {
        Group {
            if g.hasScore {
                Text("\(g.homeGoals) – \(g.awayGoals)")
                    .font(.system(size: 24, weight: .bold).monospacedDigit())
            } else {
                Text(timeOnly(g)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }

    // Liste scrollable de tous les autres matchs : à venir/live d'abord, puis terminés récents
    private func matchList(excluding featured: WCGame) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(listGames(excluding: featured)) { g in
                    row(g)
                        .contentShape(Rectangle())
                        .onTapGesture { match.selectedId = g.id }   // mettre ce match en avant
                }
            }
            .padding(.horizontal, 2)
            .background(GeometryReader { p in
                Color.clear.preference(key: ScrollOffsetKey.self,
                                       value: p.frame(in: .named("matchScroll")).minY)
            })
        }
        .coordinateSpace(name: "matchScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { scrollY = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.never)
    }

    private func listGames(excluding f: WCGame) -> [WCGame] {
        let toCome = match.games.filter { $0.id != f.id && !$0.isFinished }
            .sorted { (match.parseDate($0.local_date) ?? .distantFuture) < (match.parseDate($1.local_date) ?? .distantFuture) }
        let done = match.games.filter { $0.id != f.id && $0.isFinished }
            .sorted { (match.parseDate($0.local_date) ?? .distantPast) > (match.parseDate($1.local_date) ?? .distantPast) }
        return toCome + done
    }

    private func row(_ g: WCGame) -> some View {
        HStack(spacing: 6) {
            Text(match.flagEmoji(forTeamId: g.teamId(home: true)))
            Text(match.code(forTeamId: g.teamId(home: true))).frame(width: 36, alignment: .leading)
            Spacer(minLength: 4)
            rowCenter(g).frame(minWidth: 92)
            Spacer(minLength: 4)
            Text(match.code(forTeamId: g.teamId(home: false))).frame(width: 36, alignment: .trailing)
            Text(match.flagEmoji(forTeamId: g.teamId(home: false)))
        }
        .font(.system(size: 11))
        .padding(.vertical, 3).padding(.horizontal, 6)
        .background(g.isLive ? Color.red.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder private func rowCenter(_ g: WCGame) -> some View {
        if g.isLive {
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 5, height: 5)
                Text("\(g.homeGoals)–\(g.awayGoals)").font(.system(size: 11, weight: .bold).monospacedDigit())
            }.foregroundStyle(.red)
        } else if g.isFinished {
            Text("\(g.homeGoals)–\(g.awayGoals)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
        } else {
            Text(dateLabel(g)).foregroundStyle(.secondary)
        }
    }

    private var offline: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash").font(.title).foregroundStyle(.secondary)
            Text("World Cup unavailable").foregroundStyle(.secondary)
            Button("Retry") { Task { await match.refresh() } }.controlSize(.small).glassButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centered(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title).foregroundStyle(.secondary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: helpers d'affichage

    private func stageLabel(_ g: WCGame) -> String {
        switch g.type.lowercased() {
        case "group": return "Group \(g.group) · MD\(g.matchday)"
        case "r32": return "Round of 32"
        case "r16": return "Round of 16"
        case "qf": return "Quarter-finals"
        case "sf": return "Semi-finals"
        case "third": return "Third-place play-off"
        case "final": return "Final"
        default: return g.group
        }
    }

    private func fmt(_ g: WCGame, _ pattern: String) -> String {
        guard let d = match.parseDate(g.local_date) else { return g.local_date }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = pattern
        return f.string(from: d)
    }
    private func dateLabel(_ g: WCGame) -> String { fmt(g, "EEE d MMM HH:mm") }
    private func timeOnly(_ g: WCGame) -> String { fmt(g, "HH:mm") }
}

// MARK: - Explosion de drapeaux quand un pays marque

private struct FlagParticles: View {
    let flag: String
    let count: Int

    // direction, distance, rotation et taille tirées au hasard pour chaque particule
    private let seeds: [(angle: Double, dist: Double, rot: Double, size: Double)]
    @State private var go = false

    init(flag: String, count: Int = 16) {
        self.flag = flag
        self.count = count
        seeds = (0..<count).map { _ in
            (.random(in: 0 ..< 2 * .pi), .random(in: 34...100), .random(in: -240...240), .random(in: 11...20))
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let s = seeds[i]
                Text(flag)
                    .font(.system(size: s.size))
                    .offset(x: go ? cos(s.angle) * s.dist : 0,
                            y: go ? sin(s.angle) * s.dist - 8 : 0)   // léger biais vers le haut
                    .rotationEffect(.degrees(go ? s.rot : 0))
                    .scaleEffect(go ? 0.35 : 0.9)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.15)) { go = true } }
    }
}
