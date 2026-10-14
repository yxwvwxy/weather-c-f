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
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
guard let data = ctx.data else { exit(1) }
let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

// Temperature bar yellow in the card: rgb(0.98, 0.86, 0.45)
let barR: Float = 0.98
let barG: Float = 0.86
let barB: Float = 0.45

struct Pix { var r, g, b, a: Float }
var srcPx = [Pix](repeating: Pix(r: 0, g: 0, b: 0, a: 0), count: width * height)
var sun = [Bool](repeating: false, count: width * height)
var cx = 0.0, cy = 0.0, count = 0.0

for i in 0..<(width * height) {
    let o = i * 4
    let a = Float(pixels[o + 3]) / 255
    let r = a > 0.01 ? Float(pixels[o]) / 255 / a : 0
    let g = a > 0.01 ? Float(pixels[o + 1]) / 255 / a : 0
    let b = a > 0.01 ? Float(pixels[o + 2]) / 255 / a : 0
    srcPx[i] = Pix(r: r, g: g, b: b, a: a)
    let disc = a > 0.9 && r > 0.84 && g > 0.70 && b < 0.58 && r > b + 0.28
    sun[i] = disc
    if disc {
        let x = Double(i % width)
        let y = Double(i / width)
        cx += x
        cy += y
        count += 1
    }
}
guard count > 100 else {
    fputs("Sun disc not found\n", stderr)
    exit(1)
}
cx /= count
cy /= count

var maxDist = 1.0
for i in 0..<sun.count where sun[i] {
    let x = Double(i % width)
    let y = Double(i / width)
    maxDist = max(maxDist, hypot(x - cx, y - cy))
}

for i in 0..<srcPx.count {
    let a = srcPx[i].a
    guard a > 0.05 else { continue }
    let x = Double(i % width)
    let y = Double(i / width)
    let dist = hypot(x - cx, y - cy)
    let o = i * 4
    if sun[i] {
        let t = Float(min(dist / maxDist, 1))
        // Exact bar yellow at the center. Darken only the rim so the disc stays round
        // and does not wash out toward white or gray.
        let shade: Float = 1 - 0.10 * t
        let r = barR * shade
        let g = barG * shade
        let b = barB * shade
        pixels[o] = UInt8(r * a * 255)
        pixels[o + 1] = UInt8(g * a * 255)
        pixels[o + 2] = UInt8(b * a * 255)
    } else if dist < maxDist * 1.45 && a > 0.85 {
        let p = srcPx[i]
        let warm = p.r > 0.45 && p.g > 0.45 && p.g < 0.90 && p.r + p.g > p.b * 1.7 && p.b < 0.85
        if warm {
            let mix = Float(max(0, 1 - dist / (maxDist * 1.45))) * 0.85
            let r = p.r * (1 - mix) + barR * mix
            let g = p.g * (1 - mix) + barG * mix
            let b = p.b * (1 - mix) + barB * mix
            pixels[o] = UInt8(min(1, r) * a * 255)
            pixels[o + 1] = UInt8(min(1, g) * a * 255)
            pixels[o + 2] = UInt8(min(1, b) * a * 255)
        }
    }
}

guard let image = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: dstPath))
print("sun center", Int(cx), Int(cy), "pixels", Int(count))
