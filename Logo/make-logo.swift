// Renders the NothingController logo: a banner over the red and black artwork, and transparent white / black wordmarks.
// Run from the repo root: swiftc -parse-as-library Logo/make-logo.swift -o /tmp/mklogo && /tmp/mklogo
import AppKit
import SwiftUI

let red = Color(red: 0.843, green: 0.098, blue: 0.129)

// 5x7 dot-matrix glyphs for the letters in the name.
let glyphs: [Character: [String]] = [
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"]
]

struct DotWord: View {
    let text: String
    let pitch: CGFloat
    var color: Color = .white
    var width: CGFloat { CGFloat(text.count) * 6 * pitch - pitch }
    var height: CGFloat { 7 * pitch - pitch * 0.3 }

    var body: some View {
        Canvas { context, _ in
            let dot = pitch * 0.72
            for (index, character) in text.enumerated() {
                guard let rows = glyphs[character] else { continue }
                for (row, pattern) in rows.enumerated() {
                    for (column, bit) in pattern.enumerated() where bit == "1" {
                        let rect = CGRect(x: CGFloat(index) * 6 * pitch + CGFloat(column) * pitch,
                                          y: CGFloat(row) * pitch, width: dot, height: dot)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: width, height: height)
    }
}

/// The wordmark: NOTHING large, CONTROLLER smaller beneath it, and the red dot.
struct Wordmark: View {
    var color: Color = .white
    var scale: CGFloat = 1

    var body: some View {
        let big: CGFloat = 34 * scale
        let small: CGFloat = big * 41 / 59   // makes CONTROLLER exactly as wide as NOTHING
        VStack(alignment: .leading, spacing: 30 * scale) {
            ZStack(alignment: .topTrailing) {
                DotWord(text: "NOTHING", pitch: big, color: color)
                Circle().fill(red).frame(width: big * 0.9, height: big * 0.9)
                    .offset(x: big * 1.5, y: -big * 0.2)
            }
            // CONTROLLER spans the same width as NOTHING.
            DotWord(text: "CONTROLLER", pitch: small, color: color.opacity(0.85))
        }
    }
}

struct Artwork: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = max(w, h)
            ZStack {
                Color.black
                Circle().fill(red).frame(width: unit * 0.50).position(x: w * 0.97, y: h * 0.10)
                Circle().fill(Color.black).frame(width: unit * 0.40).position(x: w * 0.89, y: h * -0.06)
                ForEach(0..<7, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14 - Double(ring) * 0.012), lineWidth: 1.5)
                        .frame(width: unit * (0.14 + 0.09 * CGFloat(ring)))
                        .position(x: w * 0.03, y: h * 1.0)
                }
                Rectangle().fill(red.opacity(0.85))
                    .frame(width: unit * 0.7, height: unit * 0.013)
                    .rotationEffect(.degrees(-24))
                    .position(x: w * 0.74, y: h * 0.86)
            }
        }
    }
}

@MainActor func export<V: View>(_ view: V, width: CGFloat, height: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 1
    renderer.isOpaque = false
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { print("failed", path); return }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote", path, Int(width), "x", Int(height))
}

@main struct Main {
    @MainActor static func main() {
        // Banner: wordmark centred over the artwork.
        export(ZStack { Artwork(); Wordmark().offset(x: -30) }, width: 2400, height: 900, to: "Logo/NothingController-banner.png")
        // Transparent wordmarks, with room for the red dot.
        export(Wordmark(color: .white).padding(80), width: 1600, height: 600, to: "Logo/NothingController-logo-white.png")
        export(Wordmark(color: .black).padding(80), width: 1600, height: 600, to: "Logo/NothingController-logo-black.png")
    }
}
