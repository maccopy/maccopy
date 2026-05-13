#!/usr/bin/env swift
// Generates the DMG background image: gradient + arrow + install instructions.
// Usage: swift Scripts/make_dmg_bg.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg_bg.png"

let W: CGFloat = 660
let H: CGFloat = 400

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(W), height: Int(H),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

// ── Background gradient ───────────────────────────────────────────────────────
let gradColors = [
    CGColor(colorSpace: cs, components: [0.10, 0.10, 0.14, 1.0])!,
    CGColor(colorSpace: cs, components: [0.14, 0.14, 0.20, 1.0])!,
]
let locs: [CGFloat] = [0, 1]
let grad = CGGradient(colorsSpace: cs, colors: gradColors as CFArray, locations: locs)!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: 0, y: H),
    end: CGPoint(x: W, y: 0),
    options: [])

// ── Subtle grid dots ──────────────────────────────────────────────────────────
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.04])!)
let spacing: CGFloat = 28
var x: CGFloat = spacing
while x < W {
    var y: CGFloat = spacing
    while y < H {
        ctx.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        y += spacing
    }
    x += spacing
}

// ── Arrow between icons ───────────────────────────────────────────────────────
// Icon positions (match osascript below): app at 165,185 — Applications at 495,185
// Arrow from ~230,185 → ~430,185
let arrowY: CGFloat = H - 185  // flip Y (CoreGraphics origin = bottom-left)
let ax1: CGFloat = 240, ax2: CGFloat = 420

ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.18])!)
ctx.setLineWidth(2)
ctx.setLineCap(.round)

// shaft
ctx.move(to: CGPoint(x: ax1, y: arrowY))
ctx.addLine(to: CGPoint(x: ax2 - 14, y: arrowY))
ctx.strokePath()

// arrowhead
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.18])!)
ctx.move(to: CGPoint(x: ax2, y: arrowY))
ctx.addLine(to: CGPoint(x: ax2 - 14, y: arrowY + 8))
ctx.addLine(to: CGPoint(x: ax2 - 14, y: arrowY - 8))
ctx.fillPath()

// ── Helper: draw centered text ────────────────────────────────────────────────
func drawText(_ text: String, x: CGFloat, y: CGFloat,
              size: CGFloat, alpha: CGFloat, weight: Bool = false) {
    let font = CTFontCreateWithName((weight ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(colorSpace: cs,
            components: [1, 1, 1, alpha])!,
    ]
    let str = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    ctx.textPosition = CGPoint(x: x - bounds.width / 2, y: H - y - bounds.height / 2)
    CTLineDraw(line, ctx)
}

// ── Labels ────────────────────────────────────────────────────────────────────
// "Clipboard Manager" title
drawText("Clipboard Manager", x: W / 2, y: 52, size: 22, alpha: 0.85, weight: true)
drawText("Drag to Applications to install", x: W / 2, y: 84, size: 13, alpha: 0.45)

// icon sub-labels (match positions)
drawText("ClipboardManager", x: 165, y: 248, size: 11, alpha: 0.35)
drawText("Applications", x: 495, y: 248, size: 11, alpha: 0.35)

// ── Thin top border line ──────────────────────────────────────────────────────
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.08])!)
ctx.setLineWidth(1)
ctx.move(to: CGPoint(x: 0, y: H - 110))
ctx.addLine(to: CGPoint(x: W, y: H - 110))
ctx.strokePath()

// ── Write PNG ─────────────────────────────────────────────────────────────────
guard let img = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("Background written to \(outputPath)")
