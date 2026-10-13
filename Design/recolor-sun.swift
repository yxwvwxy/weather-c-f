import AppKit

let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
guard let src = NSImage(contentsOf: URL(fileURLWithPath: srcPath)),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Could not read source\n", stderr)
    exit(1)
}

let width = cg.width
let height = cg.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fputs("Could not create context\n", stderr)
    exit(1)
}

ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
guard let data = ctx.data else { exit(1) }
let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

func hsv(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
    let maxV = max(r, g, b)
    let minV = min(r, g, b)
    let d = maxV - minV
    var h: Float = 0
    if d > 0.0001 {
        if maxV == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if maxV == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        if h < 0 { h += 6 }
        h *= 60
    }
    let s = maxV == 0 ? 0 : d / maxV
    return (h, s, maxV)
}

func rgb(_ h: Float, _ s: Float, _ v: Float) -> (Float, Float, Float) {
    let c = v * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = v - c
    let sector = Int(h / 60) % 6
    let (rp, gp, bp): (Float, Float, Float)
    switch sector {
    case 0: (rp, gp, bp) = (c, x, 0)
    case 1: (rp, gp, bp) = (x, c, 0)
    case 2: (rp, gp, bp) = (0, c, x)
    case 3: (rp, gp, bp) = (0, x, c)
    case 4: (rp, gp, bp) = (x, 0, c)
    default: (rp, gp, bp) = (c, 0, x)
    }
    return (rp + m, gp + m, bp + m)
}

// Temperature-bar yellow in WeatherCard: rgb(0.98, 0.86, 0.45), hue 46°.
let targetHue: Float = 46.4

for i in 0..<(width * height) {
    let o = i * 4
    let r = Float(pixels[o]) / 255
    let g = Float(pixels[o + 1]) / 255
    let b = Float(pixels[o + 2]) / 255
    let (h, s, v) = hsv(r, g, b)
    let warm = h >= 12 && h <= 80 && s >= 0.10 && v >= 0.35 && r > b + 0.03
    guard warm else { continue }
    let disc = s >= 0.22 && r > 0.55
    let newV: Float = disc ? (0.90 + 0.10 * min(v, 1)) : v
    let newS: Float = disc ? (0.46 + 0.08 * (1 - min(v, 1))) : min(s * 0.85, 0.35)
    let (nr, ng, nb) = rgb(targetHue, newS, newV)
    pixels[o] = UInt8(max(0, min(255, nr * 255)))
    pixels[o + 1] = UInt8(max(0, min(255, ng * 255)))
    pixels[o + 2] = UInt8(max(0, min(255, nb * 255)))
}

guard let image = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: dstPath))
