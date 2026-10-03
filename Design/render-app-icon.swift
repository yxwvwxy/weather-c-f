import AppKit

let canvas: CGFloat = 1024
let inset: CGFloat = 96
let iconRect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let corner = iconRect.width * 0.223

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocusFlipped(false)

NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.current?.shouldAntialias = true

NSColor.clear.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvas, height: canvas)).fill()

let squircle = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner)
squircle.addClip()

NSGradient(colors: [
    NSColor(srgbRed: 0.10, green: 0.77, blue: 0.98, alpha: 1),
    NSColor(srgbRed: 0.11, green: 0.61, blue: 0.96, alpha: 1),
    NSColor(srgbRed: 0.11, green: 0.44, blue: 0.95, alpha: 1)
])!.draw(in: iconRect, angle: 270)

let cream = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.96, alpha: 1)
let mercury = NSColor(srgbRed: 1.00, green: 0.67, blue: 0.32, alpha: 1)
let mercuryDeep = NSColor(srgbRed: 1.00, green: 0.48, blue: 0.18, alpha: 1)

let cx = iconRect.midX
let glassW: CGFloat = 70
let mercuryW: CGFloat = 38
let bulbR: CGFloat = 86
let tubeTop = iconRect.maxY - 210
let bulbY = iconRect.minY + 248
let tubeBottom = bulbY + 36
let mercuryTop = tubeBottom + (tubeTop - tubeBottom) * 0.46

let glass = NSBezierPath(roundedRect: NSRect(
    x: cx - glassW / 2,
    y: tubeBottom,
    width: glassW,
    height: tubeTop - tubeBottom + glassW / 2
), xRadius: glassW / 2, yRadius: glassW / 2)
cream.setFill()
glass.fill()

let mercuryCol = NSBezierPath(roundedRect: NSRect(
    x: cx - mercuryW / 2,
    y: bulbY,
    width: mercuryW,
    height: mercuryTop - bulbY
), xRadius: mercuryW / 2, yRadius: mercuryW / 2)
NSGradient(colors: [mercury, mercuryDeep])!.draw(in: mercuryCol, angle: 270)

let bulbOuter = NSBezierPath(ovalIn: NSRect(x: cx - bulbR, y: bulbY - bulbR, width: bulbR * 2, height: bulbR * 2))
cream.setFill()
bulbOuter.fill()

let innerR: CGFloat = 58
let bulbInner = NSBezierPath(ovalIn: NSRect(x: cx - innerR, y: bulbY - innerR, width: innerR * 2, height: innerR * 2))
NSGradient(colors: [mercury, mercuryDeep])!.draw(in: bulbInner, angle: 270)

func drawTicks(offsetX: CGFloat) {
    let top = tubeTop - 18
    let bottom = tubeBottom + 28
    let count = 9
    for i in 0..<count {
        let t = CGFloat(i) / CGFloat(count - 1)
        let y = top - (top - bottom) * t
        let major = i % 2 == 0
        let length: CGFloat = major ? 34 : 20
        let path = NSBezierPath()
        path.lineWidth = major ? 5 : 3.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: cx + offsetX, y: y))
        path.line(to: NSPoint(x: cx + offsetX + (offsetX < 0 ? -length : length), y: y))
        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.stroke()
    }
}

drawTicks(offsetX: -58)
drawTicks(offsetX: 58)

func drawLabel(_ text: String, x: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 58, weight: .semibold),
        .foregroundColor: NSColor.white
    ]
    let size = (text as NSString).size(withAttributes: attrs)
    (text as NSString).draw(at: NSPoint(x: x - size.width / 2, y: y), withAttributes: attrs)
}

drawLabel("°C", x: cx - 148, y: tubeTop + 22)
drawLabel("°F", x: cx + 148, y: tubeTop + 22)

image.unlockFocus()

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: 1024, height: 1024)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: url)
