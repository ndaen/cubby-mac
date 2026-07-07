import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

@MainActor
final class FileShelf: ObservableObject {
    static let shared = FileShelf()
    @Published var items: [ShelfItem] = []

    func add(_ urls: [URL]) {
        for u in urls where !items.contains(where: { $0.url == u }) {
            items.append(ShelfItem(url: u))
        }
    }
    func remove(_ item: ShelfItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }
}

struct BacTabView: View {
    @StateObject private var shelf = FileShelf.shared
    @State private var targeted = false

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                emptyZone
            } else {
                filledZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(targeted ? Color.blue.opacity(0.12) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            for p in providers where p.canLoadObject(ofClass: URL.self) {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in shelf.add([url.standardizedFileURL]) }
                }
            }
            return true
        }
    }

    private var emptyZone: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            .foregroundStyle(targeted ? Color.blue : Color.secondary)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.title)
                    Text(targeted ? "Drop here" : "Drag files here").font(.subheadline)
                    Text("they stay within reach — drag them out anywhere you like").font(.caption2).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
            }
    }

    private var filledZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(shelf.items.count) file\(shelf.items.count > 1 ? "s" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { shelf.clear() }.controlSize(.small).glassButton()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shelf.items) { item in
                        FileChip(item: item) { shelf.remove(item) }
                    }
                }
            }
        }
    }
}

struct FileChip: View {
    let item: ShelfItem
    let onRemove: () -> Void

    private var icon: NSImage { NSWorkspace.shared.icon(forFile: item.url.path) }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable().frame(width: 44, height: 44)
            Text(item.url.lastPathComponent)
                .font(.caption2).lineLimit(1).truncationMode(.middle)
                .frame(width: 72)
        }
        .padding(8)
        .glassBG(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    .frame(width: 10, height: 10)
            }
            .glassButton()
            .padding(2)
        }
        // glisser le fichier VERS une autre app (Finder, Mail…)
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
    }
}
