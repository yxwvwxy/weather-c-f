import AppKit

let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
guard let src = NSImage(contentsOf: URL(fileURLWithPath: srcPath)),
      let cgSrc = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Could not read source image\n", stderr)
    exit(1)
}

let size = 1024
let inset: CGFloat = 80
let iconRect = CGRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let radius = iconRect.width * 0.223

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Could not create context\n", stderr)
    exit(1)
}

ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

let path = CGPath(roundedRect: iconRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()

let colors = [
    CGColor(srgbRed: 0.10, green: 0.77, blue: 0.98, alpha: 1),
    CGColor(srgbRed: 0.11, green: 0.61, blue: 0.96, alpha: 1),
    CGColor(srgbRed: 0.11, green: 0.44, blue: 0.95, alpha: 1)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.45, 1]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: iconRect.maxY),
        end: CGPoint(x: 0, y: iconRect.minY),
        options: []
    )
}

ctx.draw(cgSrc, in: iconRect)

guard let image = ctx.makeImage() else {
    fputs("Could not export image\n", stderr)
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: size, height: size)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: dstPath))
