import AppKit

// Génère l'icône .app de Cubby : le « regard » (deux yeux dans une fente noire)
// posé sur un squircle miel. Aucune dépendance externe — dessin AppKit pur.
//
// Usage :
//   swift make-icon.swift [dossier_sortie]
//   iconutil -c icns <dossier_sortie>/Cubby.iconset -o <dossier_sortie>/Cubby.icns

_ = NSApplication.shared

let amberTop = NSColor(srgbRed: 0.949, green: 0.698, blue: 0.290, alpha: 1) // #F2B24A
let amberBot = NSColor(srgbRed: 0.760, green: 0.443, blue: 0.102, alpha: 1) // #C2711A
let ink      = NSColor(srgbRed: 0.039, green: 0.039, blue: 0.043, alpha: 1) // #0A0A0B

func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)).fill()
}

func render(_ px: Int) -> Data {
    let S = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // squircle miel (dégradé haut → bas)
    let pad = S * 0.095
    let rect = CGRect(x: pad, y: pad, width: S - 2 * pad, height: S - 2 * pad)
    let squircle = NSBezierPath(roundedRect: rect,
                                xRadius: rect.width * 0.2237,
                                yRadius: rect.height * 0.2237)
    if let g = NSGradient(starting: amberTop, ending: amberBot) {
        g.draw(in: squircle, angle: -90)
    }

    // fente noire — le « cubby » où vit le regard
    let slotW = S * 0.40, slotH = S * 0.34
    let slot = CGRect(x: (S - slotW) / 2, y: S * 0.47 - slotH / 2, width: slotW, height: slotH)
    ink.setFill()
    NSBezierPath(roundedRect: slot, xRadius: S * 0.11, yRadius: S * 0.11).fill()

    // le regard : deux yeux blancs, pupilles, reflets
    let cx = S * 0.5, cy = S * 0.49
    let eyeDX = S * 0.096, eyeR = S * 0.060, pupilR = S * 0.027
    fillCircle(cx - eyeDX, cy, eyeR, .white)
    fillCircle(cx + eyeDX, cy, eyeR, .white)
    fillCircle(cx - eyeDX + S * 0.006, cy - S * 0.012, pupilR, ink)
    fillCircle(cx + eyeDX + S * 0.006, cy - S * 0.012, pupilR, ink)
    fillCircle(cx - eyeDX - S * 0.014, cy + S * 0.020, S * 0.012, .white)
    fillCircle(cx + eyeDX - S * 0.014, cy + S * 0.020, S * 0.012, .white)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let base = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let out = "\(base)/Cubby.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: out)
try! fm.createDirectory(atPath: out, withIntermediateDirectories: true)

// (pixels, [noms de fichiers de l'iconset])
let map: [(Int, [String])] = [
    (16,   ["icon_16x16.png"]),
    (32,   ["icon_16x16@2x.png", "icon_32x32.png"]),
    (64,   ["icon_32x32@2x.png"]),
    (128,  ["icon_128x128.png"]),
    (256,  ["icon_128x128@2x.png", "icon_256x256.png"]),
    (512,  ["icon_256x256@2x.png", "icon_512x512.png"]),
    (1024, ["icon_512x512@2x.png"]),
]
for (px, names) in map {
    let data = render(px)
    for n in names { try! data.write(to: URL(fileURLWithPath: "\(out)/\(n)")) }
}
print("iconset écrit : \(out)")
