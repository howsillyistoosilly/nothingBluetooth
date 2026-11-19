import AppKit
import SwiftUI

/// Menu bar item. In L·R mode earbuds show as two buds with their own charge, headphones as one
/// headset in the middle with left and right on either side; other modes show one icon and a figure.
struct MenuBarLabel: View {
    let manager: CMFBluetoothManager

    var body: some View {
        if let image = renderedImage() {
            Image(nsImage: image)
        } else {
            Image(systemName: "headphones")
        }
    }

    @MainActor private func renderedImage() -> NSImage? {
        let renderer = ImageRenderer(content: content.foregroundStyle(.black).environment(\.colorScheme, .light))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }

    private func figure(_ value: Int) -> some View {
        Text("\(value)").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
    }

    /// One bud and its charge; the glyph is a single earbud, left or right.
    private func bud(_ value: Int, side: EarSide) -> some View {
        HStack(spacing: 2) {
            Image(systemName: side == .left ? "earbud.left" : "earbud.right").font(.system(size: 13))
            figure(value)
        }
    }

    @ViewBuilder private var content: some View {
        let readings = manager.menuBarReadings
        if manager.batteryDisplay == .leftRight, let left = readings.left, let right = readings.right {
            if manager.isOverEar {
                HStack(spacing: 4) {
                    figure(left)
                    Image(systemName: "headphones").font(.system(size: 13))
                    figure(right)
                }
            } else {
                HStack(spacing: 7) {
                    bud(left, side: .left)
                    bud(right, side: .right)
                }
            }
        } else {
            HStack(spacing: 3) {
                Image(systemName: manager.isOverEar ? "headphones" : "earbuds.case").font(.system(size: 13))
                if let text = manager.menuBarBatteryText { Text(text).font(.system(size: 11, weight: .semibold)) }
            }
        }
    }
}
