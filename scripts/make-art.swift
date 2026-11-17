#!/usr/bin/env swift
// Draws the app icon (Resources/AppIcon.icns) and the README banner (docs/banner.png).
// Run from the repository root: swift scripts/make-art.swift
import AppKit

let indigo = NSColor(srgbRed: 0.38, green: 0.36, blue: 0.98, alpha: 1)
let pink = NSColor(srgbRed: 0.85, green: 0.32, blue: 0.78, alpha: 1)
let gradient = NSGradient(starting: indigo, ending: pink)!

func render(width: Int, height: Int, _ draw: (CGRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func symbol(_ name: String, pointSize: CGFloat) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

func drawCentered(_ image: NSImage, in rect: CGRect) {
    let size = image.size
    image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
}

/// macOS icon: rounded square with margins, gradient, soft shadow, white hand.
func drawIcon(in canvas: CGRect) {
    let side = canvas.width
    let tile = canvas.insetBy(dx: side * 0.1, dy: side * 0.1)
    let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = side * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.01)
    shadow.set()
    indigo.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    gradient.draw(in: path, angle: -45)
    // Light sheen on the top half.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    drawCentered(symbol("hand.tap.fill", pointSize: side * 0.4), in: tile.offsetBy(dx: 0, dy: -side * 0.01))
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default

// App icon.
let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        writePNG(render(width: px, height: px, drawIcon), to: "\(iconset)/\(name)")
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()

// README banner, 2x for retina.
try! fm.createDirectory(atPath: "docs", withIntermediateDirectories: true)
let banner = render(width: 2560, height: 800) { rect in
    gradient.draw(in: rect, angle: -20)
    // Faint finger dots, like touches on a trackpad.
    for (x, y, r) in [(0.07, 0.78, 60.0), (0.16, 0.86, 44.0), (0.88, 0.2, 70.0), (0.95, 0.38, 46.0), (0.80, 0.08, 38.0)] {
        NSColor.white.withAlphaComponent(0.1).setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.width * x - r, y: rect.height * y - r, width: r * 2, height: r * 2)).fill()
    }
    let iconRect = CGRect(x: 240, y: 160, width: 480, height: 480)
    drawIcon(in: iconRect)

    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 8
    NSAttributedString(string: "FingerTap", attributes: [
        .font: NSFont.systemFont(ofSize: 190, weight: .heavy), .foregroundColor: NSColor.white,
    ]).draw(at: CGPoint(x: 800, y: 380))
    NSAttributedString(string: "Trackpad gestures → keyboard shortcuts,\nper app, right from your menu bar.", attributes: [
        .font: NSFont.systemFont(ofSize: 72, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.88), .paragraphStyle: paragraph,
    ]).draw(at: CGPoint(x: 806, y: 180))
}
writePNG(banner, to: "docs/banner.png")
print("OK: Resources/AppIcon.icns, docs/banner.png")
