import SwiftUI
import AppKit

// Résout l'onglet dont l'épingle s'affiche sur les flancs de l'encoche fermée.
//   1. onglet épinglé manuellement (shell.pinnedTab) s'il a un contenu latéral ;
//   2. sinon priorité auto : Musique.
@MainActor
func resolvePinTab(shell: NotchShellModel, music: MusicModel) -> HubTab? {
    if let p = shell.pinnedTab {
        switch p {
        case .music: return music.available ? .music : nil
        case .bac: return nil
        }
    }
    if music.available { return .music }
    return nil
}

// Contenu des épingles posé dans les marges noires latérales dessinées par
// NotchRootView (la masse noire s'élargit, ici on ne rend que le contenu).
struct SidePins: View {
    @ObservedObject var shell: NotchShellModel
    @ObservedObject var music: MusicModel
    let pinTab: HubTab?
    let notchWidth: CGFloat   // largeur intérieure de l'encoche
    let earW: CGFloat         // largeur d'une marge latérale
    let notchHeight: CGFloat

    private var hovered: Bool { shell.status == .popping }
    // centre horizontal d'une oreille = bord de l'encoche + demi-marge
    private var centerX: CGFloat { notchWidth / 2 + earW / 2 }

    var body: some View {
        ZStack(alignment: .top) {
            leadingContent.offset(x: -centerX)
            trailingContent.offset(x: centerX)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: notchHeight)
        .opacity(pinTab == nil ? 0 : (hovered ? 1 : 0.95))
        .allowsHitTesting(pinTab != nil)
        .animation(.easeOut(duration: 0.2), value: pinTab)
    }

    // MARK: - Contenu par onglet

    @ViewBuilder private var leadingContent: some View {
        switch pinTab {
        case .music: musicArtwork
        default: Color.clear.frame(width: earW, height: notchHeight)
        }
    }

    @ViewBuilder private var trailingContent: some View {
        switch pinTab {
        case .music: musicPlayPause
        default: Color.clear.frame(width: earW, height: notchHeight)
        }
    }

    // MARK: - Musique

    private var artSize: CGFloat { min(notchHeight - 8, earW - 6) }

    private var musicArtwork: some View {
        Group {
            if let art = music.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.06))
            }
        }
        .frame(width: artSize, height: artSize)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .frame(width: earW, height: notchHeight)
    }

    private var musicPlayPause: some View {
        Button { music.playPause() } label: {
            Image(systemName: music.playing ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: earW, height: notchHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
