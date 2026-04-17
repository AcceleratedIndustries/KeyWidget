#!/usr/bin/env swift
import AppKit

// Generates the app icon PNGs into the target directory.
// Usage: swift scripts/gen-icon.swift <output-dir>

guard CommandLine.arguments.count == 2 else {
    print("Usage: gen-icon.swift <output-dir>")
    exit(1)
}
let outputDir = CommandLine.arguments[1]

let sizes: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func drawIcon(pixels: Int) -> Data? {
    let side = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Rounded squircle background (iA Writer warm paper)
    let inset = side * 0.08
    let radius = side * 0.22
    let bgRect = NSRect(x: inset, y: inset, width: side - 2*inset, height: side - 2*inset)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    NSColor(red: 247/255, green: 243/255, blue: 236/255, alpha: 1.0).setFill()
    bgPath.fill()

    // Hairline border
    NSColor(red: 221/255, green: 210/255, blue: 189/255, alpha: 1.0).setStroke()
    bgPath.lineWidth = max(1, side * 0.004)
    bgPath.stroke()

    // ⌘ glyph
    let fontSize = side * 0.52
    let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
    let color = NSColor(red: 176/255, green: 107/255, blue: 53/255, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let text = "⌘" as NSString
    let tsz = text.size(withAttributes: attrs)
    let pt = NSPoint(x: (side - tsz.width) / 2, y: (side - tsz.height) / 2 - side*0.03)
    text.draw(at: pt, withAttributes: attrs)

    return rep.representation(using: .png, properties: [:])
}

for (filename, pixels) in sizes {
    guard let data = drawIcon(pixels: pixels) else { continue }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
    try? data.write(to: url)
    print("wrote \(filename) (\(pixels)x\(pixels))")
}
