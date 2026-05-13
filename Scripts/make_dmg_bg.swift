#!/usr/bin/env swift
// Generates DMG background: pkg-focused layout with gradient + instructions.
// Usage: swift Scripts/make_dmg_bg.swift <output.png> [width] [height]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg_bg.png"
let W: CGFloat = CommandLine.arguments.count > 2 ? CGFloat(Double(CommandLine.arguments[2]) ?? 540) : 540
let H: CGFloat = CommandLine.arguments.count > 3 ? CGFloat(Double(CommandLine.arguments[3]) ?? 360) : 360

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(W), height: Int(H),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

// ── Background gradient ───────────────────────────────────────────────────────
let gradColors = [
    CGColor(colorSpace: cs, components: [0.09, 0.09, 0.13, 1.0])!,
    CGColor(colorSpace: cs, components: [0.13, 0.13, 0.19, 1.0])!,
]
let grad = CGGradient(colorsSpace: cs, colors: gradColors as CFArray, locations: [0, 1] as [CGFloat])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

// ── Dot grid ─────────────────────────────────────────────────────────────────
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.035])!)
let spacing: CGFloat = 24
var gx: CGFloat = spacing
while gx < W {
    var gy: CGFloat = spacing
    while gy < H {
        ctx.fillEllipse(in: CGRect(x: gx - 1, y: gy - 1, width: 2, height: 2))
        gy += spacing
    }
    gx += spacing
}

// ── Helper: draw horizontally centered text ───────────────────────────────────
func drawText(_ text: String, cx: CGFloat, cy: CGFloat,
              size: CGFloat, alpha: CGFloat, bold: Bool = false) {
    let fontName = bold ? "Helvetica-Bold" : "Helvetica" as CFString
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(colorSpace: cs, components: [1, 1, 1, alpha])!,
    ]
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!)
    let b = CTLineGetBoundsWithOptions(line, [])
    ctx.textPosition = CGPoint(x: cx - b.width / 2, y: H - cy - b.height / 2)
    CTLineDraw(line, ctx)
}

// ── Title area (top) ──────────────────────────────────────────────────────────
// Subtle top separator
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.05])!)
ctx.fill(CGRect(x: 0, y: H - 72, width: W, height: 72))
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.10])!)
ctx.setLineWidth(0.5)
ctx.move(to: CGPoint(x: 0, y: H - 72)); ctx.addLine(to: CGPoint(x: W, y: H - 72))
ctx.strokePath()

drawText("Clipboard Manager", cx: W / 2, cy: 28, size: 20, alpha: 0.88, bold: true)
drawText("macOS clipboard history — menu bar app", cx: W / 2, cy: 52, size: 12, alpha: 0.40)

// ── Pkg icon placeholder (rounded rect) ──────────────────────────────────────
let pkgX: CGFloat = W / 2 - 44
let pkgY: CGFloat = 110   // from top in "screen" coords
let pkgW: CGFloat = 88
let pkgH: CGFloat = 88

// Shadow
ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 12,
    color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.5])!)
// Box (installer box look: dark blue-grey)
let pkgRect = CGRect(x: pkgX, y: H - pkgY - pkgH, width: pkgW, height: pkgH)
let pkgPath = CGPath(roundedRect: pkgRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
let pkgFill = CGGradient(colorsSpace: cs, colors: [
    CGColor(colorSpace: cs, components: [0.25, 0.45, 0.85, 1.0])!,
    CGColor(colorSpace: cs, components: [0.15, 0.30, 0.65, 1.0])!,
] as CFArray, locations: [0, 1] as [CGFloat])!
ctx.saveGState()
ctx.addPath(pkgPath); ctx.clip()
ctx.drawLinearGradient(pkgFill,
    start: CGPoint(x: pkgX, y: H - pkgY),
    end: CGPoint(x: pkgX, y: H - pkgY - pkgH), options: [])
ctx.restoreGState()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// "PKG" label on icon
drawText("PKG", cx: W / 2, cy: pkgY + 30, size: 16, alpha: 0.90, bold: true)
// Clipboard icon lines (decorative)
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.35])!)
ctx.setLineWidth(1.5)
let lx = W / 2 - 14
let ly0 = H - pkgY - 58
for i in 0..<3 {
    let y = ly0 - CGFloat(i) * 8
    ctx.move(to: CGPoint(x: lx, y: y))
    ctx.addLine(to: CGPoint(x: lx + 28, y: y))
    ctx.strokePath()
}

// ── Install instruction ───────────────────────────────────────────────────────
drawText("Double-click to install", cx: W / 2, cy: pkgY + pkgH + 22, size: 13, alpha: 0.75, bold: true)
drawText("Installs to /Applications automatically", cx: W / 2, cy: pkgY + pkgH + 42, size: 11, alpha: 0.35)

// ── Bottom hint ───────────────────────────────────────────────────────────────
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.03])!)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: 40))
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.07])!)
ctx.setLineWidth(0.5)
ctx.move(to: CGPoint(x: 0, y: 40)); ctx.addLine(to: CGPoint(x: W, y: 40))
ctx.strokePath()
drawText("Requires macOS 14 Sonoma or later", cx: W / 2, cy: H - 20, size: 10, alpha: 0.25)

// ── Write PNG ─────────────────────────────────────────────────────────────────
guard let img = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("Background written to \(outputPath)")
