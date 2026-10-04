import AppKit

let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
guard let src = NSImage(contentsOf: URL(fileURLWithPath: srcPath)) else {
    fputs("Could not read source image\n", stderr)
    exit(1)
}

let size = 1024
let contentInset: CGFloat = 108
let content = CGFloat(size) - contentInset * 2
let scale = CGFloat(size) / content
let drawRect = NSRect(
    x: -contentInset * scale,
    y: -contentInset * scale,
    width: CGFloat(size) * scale,
    height: CGFloat(size) * scale
)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fputs("Could not create context\n", stderr)
    exit(1)
}

ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.61, blue: 0.96, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let colors = [
    CGColor(srgbRed: 0.10, green: 0.77, blue: 0.98, alpha: 1),
    CGColor(srgbRed: 0.11, green: 0.44, blue: 0.95, alpha: 1)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current?.imageInterpolation = .high
src.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else {
    fputs("Could not export image\n", stderr)
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: dstPath))
