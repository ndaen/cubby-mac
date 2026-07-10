import SwiftUI
import AppKit

// Racine de la fenêtre de réglages : 3 onglets natifs.
struct SettingsRoot: View {
    @ObservedObject private var loc = Loc.shared

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(loc.s("General", "Général"), systemImage: "gearshape") }
            MarketplaceView()
                .tabItem { Label(loc.s("Marketplace", "Marché"), systemImage: "bag.fill") }
            DevelopView()
                .tabItem { Label(loc.s("Develop", "Développer"), systemImage: "hammer.fill") }
        }
        .frame(width: 500, height: 580)
    }
}

// ── Général : langue ──────────────────────────────────────────────
private struct GeneralSettings: View {
    @ObservedObject private var loc = Loc.shared

    var body: some View {
        Form {
            Section(loc.s("Language", "Langue")) {
                Picker(selection: $loc.lang) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                } label: { Text(loc.s("Interface language", "Langue de l'interface")) }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}

// ── Marché : catalogue distant d'extensions ───────────────────────
private struct MarketplaceView: View {
    @ObservedObject private var loc = Loc.shared
    @ObservedObject private var market = MarketModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill").font(.title3).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc.s("Extensions", "Extensions")).font(.headline)
                        Text(loc.s("Add modules to your notch", "Ajoutez des modules à votre encoche"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                ForEach(market.extensions) { ext in
                    ExtensionRow(ext: ext)
                }
            }
            .padding(20)
        }
        .onAppear { market.refresh() }
    }
}

private struct ExtensionRow: View {
    let ext: Extension
    @ObservedObject private var loc = Loc.shared
    @ObservedObject private var market = MarketModel.shared

    private var installed: Bool { market.isInstalled(ext) }

    var body: some View {
        HStack(spacing: 12) {
            Text(ext.emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.s(ext.nameEn, ext.nameFr)).font(.system(size: 13, weight: .semibold))
                Text(loc.s(ext.descEn, ext.descFr))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if market.canInstall(ext) {
                Button(installed ? loc.s("Remove", "Retirer") : loc.s("Get", "Obtenir")) {
                    market.toggle(ext)
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(installed ? .secondary : .accentColor)
            } else {
                Text(loc.s("Coming soon", "Bientôt"))
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.25)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(installed ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}

// ── Développer : proposer / contribuer une extension ──────────────
private struct DevelopView: View {
    @ObservedObject private var loc = Loc.shared

    private let repo = "https://github.com/ndaen/cubby-mac"
    private let newIssue = "https://github.com/ndaen/cubby-mac/issues/new"

    private let schema = """
    {
      "id": "my-extension",
      "emoji": "✨",
      "nameEn": "My Extension",  "nameFr": "Mon extension",
      "descEn": "What it does",  "descFr": "Ce qu'elle fait",
      "available": false
    }
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.s("Build an extension", "Créer une extension"))
                        .font(.title2.bold())
                    Text(loc.s(
                        "Cubby extensions are lightweight modules shown as tabs in the notch. The catalog is open source — propose an idea or contribute one on GitHub.",
                        "Les extensions Cubby sont des modules légers affichés en onglets dans l'encoche. Le catalogue est open source — propose une idée ou contribue sur GitHub."))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.s("Catalog entry format", "Format d'une entrée du catalogue"))
                        .font(.subheadline.weight(.semibold))
                    Text("catalog.json").font(.caption).foregroundStyle(.tertiary)
                    Text(schema)
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
                }

                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.open(URL(string: newIssue)!)
                    } label: {
                        Label(loc.s("Propose an extension", "Proposer une extension"),
                              systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        NSWorkspace.shared.open(URL(string: repo)!)
                    } label: {
                        Label(loc.s("View on GitHub", "Voir sur GitHub"), systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
