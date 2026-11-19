// Renders Icon/AppIcon.icns: a macOS squircle with a dot-matrix N and the Nothing red dot.
// Run: swift Icon/make-icon.swift
import AppKit

let canvas: CGFloat = 1024
let body: CGFloat = 824
let glyph = ["10001", "11001", "10101", "10101", "10011", "10001", "10001"]  // dot-matrix N

func render() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let origin = (canvas - body) / 2
    let rect = CGRect(x: origin, y: origin, width: body, height: body)
    let path = NSBezierPath(roundedRect: rect, xRadius: body * 0.2237, yRadius: body * 0.2237)

    // Soft drop shadow under the squircle.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    NSColor.black.setFill()
    path.fill()
    ctx.restoreGState()

    // Body gradient.
    ctx.saveGState()
    path.addClip()
    let gradient = NSGradient(colors: [NSColor(white: 0.17, alpha: 1), NSColor(white: 0.03, alpha: 1)])!
    gradient.draw(in: rect, angle: -90)
    // Subtle top sheen.
    let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
    sheen.draw(in: CGRect(x: origin, y: origin + body * 0.55, width: body, height: body * 0.45), angle: -90)
    ctx.restoreGState()

    // Hairline inner border.
    NSColor.white.withAlphaComponent(0.14).setStroke()
    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: body * 0.2237, yRadius: body * 0.2237)
    inner.lineWidth = 3
    inner.stroke()

    // Dot-matrix N.
    let pitch: CGFloat = 76
    let dot: CGFloat = 54
    let gridW = pitch * 4 + dot
    let gridH = pitch * 6 + dot
    let gx = (canvas - gridW) / 2
    let gy = (canvas - gridH) / 2 - 6
    for (row, line) in glyph.enumerated() {
        for (col, bit) in line.enumerated() {
            let x = gx + CGFloat(col) * pitch
            let y = gy + CGFloat(6 - row) * pitch
            let on = bit == "1"
            let circle = NSBezierPath(ovalIn: CGRect(x: x, y: y, width: dot, height: dot))
            if on {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: 14, color: NSColor.white.withAlphaComponent(0.35).cgColor)
                NSColor.white.setFill()
                circle.fill()
                ctx.restoreGState()
            } else {
                NSColor.white.withAlphaComponent(0.07).setFill()
                circle.fill()
            }
        }
    }

    // The red dot, top right.
    let red = NSBezierPath(ovalIn: CGRect(x: origin + body * 0.77, y: origin + body * 0.77, width: 62, height: 62))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 22, color: NSColor(red: 0.843, green: 0.098, blue: 0.129, alpha: 0.7).cgColor)
    NSColor(red: 0.843, green: 0.098, blue: 0.129, alpha: 1).setFill()
    red.fill()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Icon")
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = render()
let sizes: [(Int, String)] = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"), (256, "128x128@2x"),
                              (256, "256x256"), (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]
let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.addRepresentation(master)
for (px, name) in sizes {
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try out.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
print("iconset written")
