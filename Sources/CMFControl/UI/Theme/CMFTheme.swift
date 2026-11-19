import SwiftUI

/// Nothing-style palette: true black, flat grey cards, white ink and a single red accent.
enum CMFTheme {
    static let background = Color.black
    static let surface = Color(white: 0.085)
    static let raised = Color(white: 0.135)
    static let ink = Color.white
    static let muted = Color(white: 0.5)
    static let dim = Color(white: 0.22)
    static let red = Color(red: 0.843, green: 0.098, blue: 0.129)
    static let tile = Color(white: 0.05)
    static let line = Color.white.opacity(0.1)
    static let lineStrong = Color.white.opacity(0.22)
}

/// 5x7 dot-matrix glyphs, drawn locally so the app needs no bundled font.
enum DotFont {
    static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
        "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
        "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
        "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
        "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
        ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
        ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
        "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
        "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
        ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"]
    ]
}

/// Text rendered as a 5x7 dot matrix, the signature Nothing typographic look.
struct DotText: View {
    let text: String
    var dot: CGFloat = 2.4
    var gap: CGFloat = 1.2
    var color: Color = CMFTheme.ink

    private var pitch: CGFloat { dot + gap }
    private var characters: [Character] { Array(text.uppercased()) }
    private var width: CGFloat { max(0, CGFloat(characters.count) * 6 * pitch - pitch) }

    var body: some View {
        Canvas { context, _ in
            for (index, character) in characters.enumerated() {
                guard let rows = DotFont.glyphs[character] else { continue }
                let xOrigin = CGFloat(index) * 6 * pitch
                for (row, pattern) in rows.enumerated() {
                    for (column, bit) in pattern.enumerated() where bit == "1" {
                        let rect = CGRect(x: xOrigin + CGFloat(column) * pitch,
                                          y: CGFloat(row) * pitch,
                                          width: dot, height: dot)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: width, height: 7 * pitch - gap)
        .accessibilityLabel(text)
    }
}

/// Faint dot grid used as a backdrop texture on hero surfaces.
struct DotGrid: View {
    var pitch: CGFloat = 10
    var dot: CGFloat = 1.6
    var color: Color = .white.opacity(0.1)

    var body: some View {
        Canvas { context, size in
            var y = pitch / 2
            while y < size.height {
                var x = pitch / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)),
                                 with: .color(color))
                    x += pitch
                }
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }
}
