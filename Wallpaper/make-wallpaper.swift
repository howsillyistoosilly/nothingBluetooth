// Renders the red and black abstract artwork used behind the glass UI.
// Run from the repo root: swiftc -parse-as-library Wallpaper/make-wallpaper.swift -o /tmp/mkwall && /tmp/mkwall
// Writes Wallpaper/NothingController-wallpaper.png (3840x2160) and the in-app backgrounds in the asset catalog.
import AppKit
import SwiftUI

let red = Color(red: 0.843, green: 0.098, blue: 0.129)

struct Artwork: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = max(w, h)
            ZStack {
                Color.black

                // Crescent: a red disc with a black disc biting into it.
                Circle().fill(red).frame(width: unit * 0.70).position(x: w * 0.95, y: h * 0.12)
                Circle().fill(Color.black).frame(width: unit * 0.56).position(x: w * 0.83, y: h * 0.0)

                // Concentric rings, bottom left.
                ForEach(0..<7, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14 - Double(ring) * 0.012), lineWidth: 1)
                        .frame(width: unit * (0.22 + 0.13 * CGFloat(ring)))
                        .position(x: w * 0.04, y: h * 0.98)
                }

                // Diagonal red bar.
                Rectangle().fill(red.opacity(0.85))
                    .frame(width: unit * 0.9, height: unit * 0.018)
                    .rotationEffect(.degrees(-32))
                    .position(x: w * 0.62, y: h * 0.82)

                // Red dot field.
                Canvas { context, size in
                    let pitch: CGFloat = max(10, unit * 0.011)
                    var y = pitch / 2
                    while y < size.height {
                        var x = pitch / 2
                        while x < size.width {
                            context.fill(Path(ellipseIn: CGRect(x: x - pitch * 0.11, y: y - pitch * 0.11, width: pitch * 0.22, height: pitch * 0.22)),
                                         with: .color(red.opacity(0.75)))
                            x += pitch
                        }
                        y += pitch
                    }
                }
                .frame(width: unit * 0.22, height: unit * 0.14)
                .position(x: w > h ? w * 0.30 : w * 0.80, y: w > h ? h * 0.24 : h * 0.60)
            }
        }
    }
}

@MainActor func export(width: CGFloat, height: CGFloat, scale: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: Artwork().frame(width: width, height: height))
    renderer.scale = scale
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { print("failed", path); return }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote", path, Int(width * scale), "x", Int(height * scale))
}

@main struct Main {
    @MainActor static func main() {
        let catalog = "Sources/CMFControl/Resources/Assets.xcassets"
        export(width: 1920, height: 1080, scale: 2, to: "Wallpaper/NothingController-wallpaper.png")
        for (name, w, h, scale) in [("bg-wide", 1280.0, 900.0, 1.5), ("bg-tall", 400.0, 660.0, 2.0)] {
            let dir = "\(catalog)/\(name).imageset"
            export(width: w, height: h, scale: scale, to: "\(dir)/\(name).png")
            let json = "{\"images\":[{\"filename\":\"\(name).png\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}\n"
            try? json.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
        }
    }
}
