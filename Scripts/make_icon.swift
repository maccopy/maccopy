#!/usr/bin/env swift
// Generates AppIcon.icns for Clipboard Manager using CoreGraphics (no display needed)
import AppKit
import Foundation

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Background rounded rect
    let inset = s * 0.04
    let radius = s * 0.22
    let bgRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Gradient: indigo-blue top to deep-blue bottom
    let colors = [
        CGColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.10, green: 0.22, blue: 0.90, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: 0, y: 0),
                           options: [])
    ctx.resetClip()

    // --- Clipboard body ---
    let cInset = s * 0.18
    let cW = s - cInset * 2
    let cH = s * 0.60
    let cX = cInset
    let cY = s * 0.13
    let cR = s * 0.06
    let bodyRect = CGRect(x: cX, y: cY, width: cW, height: cH)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: cR, cornerHeight: cR, transform: nil)
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
    ctx.fillPath()

    // --- Clip (top part of clipboard) ---
    let clipW = cW * 0.36
    let clipH = s * 0.11
    let clipX = cX + (cW - clipW) / 2
    let clipY = cY + cH - clipH * 0.45
    let clipR = s * 0.04
    let clipRect = CGRect(x: clipX, y: clipY, width: clipW, height: clipH)
    let clipPath = CGPath(roundedRect: clipRect, cornerWidth: clipR, cornerHeight: clipR, transform: nil)
    ctx.addPath(clipPath)
    ctx.setFillColor(CGColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1.0))
    ctx.fillPath()

    // Small circle hole in clip
    let holeR = clipH * 0.28
    let holeRect = CGRect(x: clipX + clipW / 2 - holeR, y: clipY + clipH / 2 - holeR,
                          width: holeR * 2, height: holeR * 2)
    ctx.addEllipse(in: holeRect)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
    ctx.fillPath()

    // --- Text lines on clipboard ---
    let lineColor = CGColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 0.28)
    let lH = s * 0.044
    let lR = lH / 2
    let lX = cX + cW * 0.13
    let lStartY = cY + cH * 0.17
    let lSpacing = lH + s * 0.078
    let lWidths: [CGFloat] = [0.72, 0.72, 0.50]
    for (i, widthFactor) in lWidths.enumerated() {
        let lY = lStartY + CGFloat(i) * lSpacing
        let lW = cW * widthFactor
        let lineRect = CGRect(x: lX, y: lY, width: lW, height: lH)
        ctx.addPath(CGPath(roundedRect: lineRect, cornerWidth: lR, cornerHeight: lR, transform: nil))
        ctx.setFillColor(lineColor)
        ctx.fillPath()
    }

    guard let cgImage = ctx.makeImage() else { return nil }
    let bmi = NSBitmapImageRep(cgImage: cgImage)
    return bmi.representation(using: .png, properties: [:])
}

// Iconset mapping: (pixel size, filename)
let entries: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let outputArg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let icnsURL = URL(fileURLWithPath: outputArg)
let iconsetURL = icnsURL.deletingPathExtension().appendingPathExtension("iconset")

do {
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    for (size, name) in entries {
        guard let data = renderIcon(size: size) else {
            fputs("Failed to render \(name)\n", stderr)
            exit(1)
        }
        try data.write(to: iconsetURL.appendingPathComponent(name))
        print("  \(name)")
    }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
    try proc.run()
    proc.waitUntilExit()

    try? FileManager.default.removeItem(at: iconsetURL)

    if proc.terminationStatus == 0 {
        print("Icon created: \(icnsURL.path)")
    } else {
        fputs("iconutil failed\n", stderr)
        exit(1)
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
