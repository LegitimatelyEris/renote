import AppKit
import CoreGraphics

// Renote app icon: the "r" stroke from the site logo, white on a black rounded square
// with the site's soft corner light and a faint orange glow.
let size: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Work in y-down coordinates like SVG.
ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1)

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow under the tile
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
ctx.addPath(shape); ctx.setFillColor(CGColor(gray: 0.02, alpha: 1)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()
// Base: near-black vertical gradient
let base = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 0.11, alpha: 1), CGColor(gray: 0.015, alpha: 1)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(base, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
// Soft white light from the top-left, like the site
let light = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 1, alpha: 0.16), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(light, startCenter: CGPoint(x: 140, y: 120), startRadius: 0, endCenter: CGPoint(x: 140, y: 120), endRadius: 640, options: [])
// Faint orange glow bottom-right
let glow = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 0.22), CGColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 860, y: 900), startRadius: 0, endCenter: CGPoint(x: 860, y: 900), endRadius: 520, options: [])
ctx.restoreGState()

// Hairline edge
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 184, cornerHeight: 184, transform: nil))
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.12)); ctx.setLineWidth(4); ctx.strokePath()

// The logo path, from viewBox 0 0 24 24: M6 5 h8 a5 5 0 0 1 0 10 h-3 l5 5
let unit: CGFloat = 25            // px per viewBox unit
let center = CGPoint(x: 12.5, y: 12.5)
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + (x - center.x) * unit, y: 512 + (y - center.y) * unit) }
let k: CGFloat = 5 * 0.5523
let r = CGMutablePath()
r.move(to: p(6, 5))
r.addLine(to: p(14, 5))
r.addCurve(to: p(19, 10), control1: p(14 + k, 5), control2: p(19, 10 - k))
r.addCurve(to: p(14, 15), control1: p(19, 10 + k), control2: p(14 + k, 15))
r.addLine(to: p(11, 15))
r.addLine(to: p(16, 20))
ctx.addPath(r)
ctx.setLineWidth(2.6 * unit)
ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
ctx.setShadow(offset: .zero, blur: 40, color: CGColor(gray: 1, alpha: 0.18))
ctx.strokePath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
