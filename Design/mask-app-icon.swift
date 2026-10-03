import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
guard let src = NSImage(contentsOf: URL(fileURLWithPath: srcPath)),
      let tiff = src.tiffRepresentation,
      let incoming = NSBitmapImageRep(data: tiff) else {
    fputs("Could not read source image\n", stderr)
    exit(1)
}

let size = 1024
let inset: CGFloat = 70
let iconRect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let corner = iconRect.width * 0.223

let out = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
out.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.current?.shouldAntialias = true

NSColor.clear.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let clip = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner)
clip.addClip()
src.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()

guard let png = out.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: dstPath))
