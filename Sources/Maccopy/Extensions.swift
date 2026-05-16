import AppKit
import Foundation

extension NSImage {
    func resized(maxDimension: CGFloat) -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard newSize.width > 0, newSize.height > 0 else { return nil }
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    var pngData: Data? {
        guard let tiff = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
