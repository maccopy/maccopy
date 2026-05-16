#!/usr/bin/env swift
// Generates AppIcon.icns for Maccopy using CoreGraphics (no display needed)
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

    // Background rounded rect — orange-to-red gradient (matches website/app/icon.svg)
    let inset = s * 0.00
    let radius = s * 0.22
    let bgRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // #FF6B35 → #F05138  (top-left to bottom-right)
    let colors = [
        CGColor(red: 1.00, green: 0.42, blue: 0.21, alpha: 1.0),  // #FF6B35
        CGColor(red: 0.94, green: 0.32, blue: 0.22, alpha: 1.0),  // #F05138
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: s, y: 0),
                           options: [])
    ctx.resetClip()

    // Back page — semi-transparent white, offset right+down
    let backX = s * 0.35
    let backY = s * 0.13  // CGContext Y is bottom-up; top in SVG = low Y here
    let backW = s * 0.32
    let backH = s * 0.40
    let backR = s * 0.07
    let backPath = CGPath(roundedRect: CGRect(x: backX, y: backY, width: backW, height: backH),
                          cornerWidth: backR, cornerHeight: backR, transform: nil)
    ctx.addPath(backPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.45))
    ctx.fillPath()

    // Front page — solid white, offset left+up from back page
    let frontX = s * 0.27
    let frontY = s * 0.20
    let frontW = s * 0.32
    let frontH = s * 0.40
    let frontR = s * 0.07

    // Clip leaf cutout from top-right corner of front page, then draw page
    ctx.saveGState()
    let fullPagePath = CGPath(roundedRect: CGRect(x: frontX, y: frontY, width: frontW, height: frontH),
                               cornerWidth: frontR, cornerHeight: frontR, transform: nil)

    // Leaf bezier — mirrors SVG path (coordinate-flipped for CoreGraphics bottom-up)
    // SVG: M43,34 C43,26 47,18 53,15 C54,22 51,29 44,33 C43.5,33.5 43,34 43,34Z
    // Normalised to 100×100 SVG space then scaled
    let scale = s / 100.0
    let leafTx = CGAffineTransform(scaleX: scale, y: -scale)
        .translatedBy(x: 0, y: -100)
    let leafPath = CGMutablePath()
    leafPath.move(to: CGPoint(x: 43, y: 34), transform: leafTx)
    leafPath.addCurve(to: CGPoint(x: 53, y: 15), control1: CGPoint(x: 43, y: 26),
                      control2: CGPoint(x: 47, y: 18), transform: leafTx)
    leafPath.addCurve(to: CGPoint(x: 44, y: 33), control1: CGPoint(x: 54, y: 22),
                      control2: CGPoint(x: 51, y: 29), transform: leafTx)
    leafPath.addCurve(to: CGPoint(x: 43, y: 34), control1: CGPoint(x: 43.5, y: 33.5),
                      control2: CGPoint(x: 43, y: 34), transform: leafTx)
    leafPath.closeSubpath()

    // Clip = fullPage minus leaf area
    let combined = CGMutablePath()
    combined.addPath(fullPagePath)
    combined.addPath(leafPath)
    ctx.addPath(combined)
    ctx.clip(using: .evenOdd)

    ctx.addPath(fullPagePath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Leaf fill — white, drawn on top of back page / gradient
    ctx.addPath(leafPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillPath()

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
