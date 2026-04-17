#!/usr/bin/env swift
import AppKit

// Generates the KeyWidget app icon PNGs into the target directory.
// Design: Apple macOS "materials" style — squircle with soft vertical
// gradient, frosted-glass rim, and a bold "?" glyph with subtle depth.
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

    // Apple macOS icon grid: ~100px padding in 1024, radius ~18% of full side.
    let inset = side * 0.098
    let radius = side * 0.18
    let bgRect = NSRect(x: inset, y: inset, width: side - 2*inset, height: side - 2*inset)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

    // Soft outer drop shadow (simulated by drawing a slightly offset dark
    // squircle behind the body).
    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow()
    bodyShadow.shadowOffset = NSSize(width: 0, height: -side * 0.012)
    bodyShadow.shadowBlurRadius = side * 0.02
    bodyShadow.shadowColor = NSColor(white: 0, alpha: 0.25)
    bodyShadow.set()
    NSColor.white.setFill()
    bgPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Vertical frosted-glass gradient.
    let gradient = NSGradient(colors: [
        NSColor(red: 246/255, green: 248/255, blue: 252/255, alpha: 1.0),
        NSColor(red: 205/255, green: 214/255, blue: 226/255, alpha: 1.0),
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Top highlight band — a light arc in the upper ~30% of the body.
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    let highlightRect = NSRect(
        x: bgRect.minX,
        y: bgRect.minY + bgRect.height * 0.55,
        width: bgRect.width,
        height: bgRect.height * 0.5
    )
    let highlight = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.0),
        NSColor(white: 1.0, alpha: 0.35),
    ])!
    highlight.draw(in: highlightRect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Inner rim stroke (bright) and outer rim stroke (subtle definition).
    let innerRim = NSColor(white: 1.0, alpha: 0.85)
    innerRim.setStroke()
    bgPath.lineWidth = max(1, side * 0.006)
    bgPath.stroke()

    let outerStrokePath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    NSColor(red: 140/255, green: 150/255, blue: 165/255, alpha: 0.35).setStroke()
    outerStrokePath.lineWidth = max(0.5, side * 0.002)
    outerStrokePath.stroke()

    // "?" glyph with subtle drop shadow for depth.
    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowOffset = NSSize(width: 0, height: -side * 0.005)
    glyphShadow.shadowBlurRadius = side * 0.015
    glyphShadow.shadowColor = NSColor(white: 0, alpha: 0.25)
    glyphShadow.set()

    let fontSize = side * 0.62
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let color = NSColor(red: 42/255, green: 48/255, blue: 60/255, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let text = "?" as NSString
    let tsz = text.size(withAttributes: attrs)
    let pt = NSPoint(
        x: (side - tsz.width) / 2,
        y: (side - tsz.height) / 2 - side * 0.02
    )
    text.draw(at: pt, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

for (filename, pixels) in sizes {
    guard let data = drawIcon(pixels: pixels) else { continue }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
    try? data.write(to: url)
    print("wrote \(filename) (\(pixels)x\(pixels))")
}
