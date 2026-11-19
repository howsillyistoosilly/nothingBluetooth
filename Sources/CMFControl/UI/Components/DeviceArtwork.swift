import AppKit
import SwiftUI

enum DeviceArtworkStyle: Equatable {
    case headphones
    case neckband
    case earbuds
    case unknown

    static func resolve(_ modelName: String) -> DeviceArtworkStyle {
        let name = modelName.lowercased()
        if name.contains("no nothing") || name.contains("no headphones") { return .unknown }
        if name.contains("headphone") { return .headphones }
        if name.contains("neckband") { return .neckband }
        if name.contains("buds") || name.contains("ear") { return .earbuds }
        return .unknown
    }

    var label: String {
        switch self {
        case .headphones: "Over-ear headphones"
        case .neckband: "Neckband earbuds"
        case .earbuds: "True wireless earbuds"
        case .unknown: "Waiting for device model"
        }
    }
}

/// Maps a reported model name to a product photo bundled in the asset catalog.
enum ProductCatalog {
    static func assetName(for modelName: String) -> String? {
        let name = modelName.lowercased()
        if name.contains("headphone") {
            if name.contains("(1)") || name.contains(" 1") { return name.contains("pro") ? "headphone-1-pro-black" : "headphone-1-white" }
            if name.contains("(a)") || name.hasSuffix(" a") { return "headphone-a-black" }
            return "cmf-headphone-pro-dark"
        }
        if name.contains("buds") {
            if name.contains("2a") { return "cmf-buds-2a" }
            if name.contains("pro 2") { return "cmf-buds-pro-2" }
            if name.contains("2 plus") || name.contains("2 +") { return "cmf-buds-2-plus" }
            if name.contains("buds 2") { return "cmf-buds-2" }
            return "cmf-buds"
        }
        if name.contains("ear") {
            if name.contains("open") { return "ear-open" }
            if name.contains("stick") { return "ear-stick" }
            if name.contains("(3)") || name.contains(" 3") { return "ear-3" }
            if name.contains("(2)") || name.contains(" 2") { return "ear-2" }
            if name.contains("(a)") { return "ear-a-white" }
            return "ear-3"
        }
        return nil
    }

    /// Photos live in `Resources/Assets.xcassets`, so they load from the package, the Xcode app and `build.sh` alike.
    static func image(named asset: String) -> NSImage? {
        #if SWIFT_PACKAGE
        Bundle.module.image(forResource: NSImage.Name(asset))
        #else
        NSImage(named: NSImage.Name(asset)) ?? siblingBundle?.image(forResource: NSImage.Name(asset))
        #endif
    }

    /// Resource bundle sitting beside the executable, for runs that are neither the package nor an app bundle.
    private static let siblingBundle: Bundle? = {
        let directory = Bundle.main.executableURL?.deletingLastPathComponent().path ?? ""
        return Bundle(path: directory + "/CMFControl_CMFControl.bundle")
    }()
}

/// Product photo for the connected model, falling back to local vector artwork.
struct DeviceArtwork: View {
    let modelName: String

    private var style: DeviceArtworkStyle { DeviceArtworkStyle.resolve(modelName) }

    var body: some View {
        if let asset = ProductCatalog.assetName(for: modelName), let image = ProductCatalog.image(named: asset) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .accessibilityLabel(modelName)
        } else {
            Canvas { context, size in
                let color = CMFTheme.ink
                switch style {
                case .headphones: drawHeadphones(in: &context, size: size, color: color)
                case .neckband: drawNeckband(in: &context, size: size, color: color)
                case .earbuds: drawEarbuds(in: &context, size: size, color: color)
                case .unknown: drawPlaceholder(in: &context, size: size, color: color)
                }
            }
            .aspectRatio(72.0 / 64.0, contentMode: .fit)
            .accessibilityHidden(true)
        }
    }

    private func drawHeadphones(in context: inout GraphicsContext, size: CGSize, color: Color) {
        var arch = Path()
        arch.move(to: CGPoint(x: 18, y: 37))
        arch.addCurve(to: CGPoint(x: 54, y: 37), control1: CGPoint(x: 18, y: 5), control2: CGPoint(x: 54, y: 5))
        context.stroke(arch, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let left = Path(roundedRect: CGRect(x: 14, y: 32, width: 12, height: 24), cornerRadius: 5)
        let right = Path(roundedRect: CGRect(x: 46, y: 32, width: 12, height: 24), cornerRadius: 5)
        context.fill(left, with: .color(color))
        context.fill(right, with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: 17, y: 37, width: 3, height: 14)), with: .color(CMFTheme.red))
        context.fill(Path(ellipseIn: CGRect(x: 52, y: 37, width: 3, height: 14)), with: .color(CMFTheme.red))
    }

    private func drawEarbuds(in context: inout GraphicsContext, size: CGSize, color: Color) {
        let caseBody = Path(roundedRect: CGRect(x: 15, y: 35, width: 42, height: 19), cornerRadius: 8)
        context.fill(caseBody, with: .color(color))
        var lid = Path()
        lid.move(to: CGPoint(x: 18, y: 39))
        lid.addLine(to: CGPoint(x: 54, y: 39))
        context.stroke(lid, with: .color(CMFTheme.background.opacity(0.65)), lineWidth: 1.5)
        var leftBud = Path()
        leftBud.move(to: CGPoint(x: 25, y: 29))
        leftBud.addCurve(to: CGPoint(x: 29, y: 18), control1: CGPoint(x: 20, y: 19), control2: CGPoint(x: 28, y: 16))
        leftBud.addLine(to: CGPoint(x: 31, y: 30))
        context.stroke(leftBud, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        var rightBud = Path()
        rightBud.move(to: CGPoint(x: 45, y: 29))
        rightBud.addCurve(to: CGPoint(x: 49, y: 18), control1: CGPoint(x: 40, y: 19), control2: CGPoint(x: 48, y: 16))
        rightBud.addLine(to: CGPoint(x: 51, y: 30))
        context.stroke(rightBud, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: 33, y: 43, width: 6, height: 3)), with: .color(CMFTheme.red))
    }

    private func drawNeckband(in context: inout GraphicsContext, size: CGSize, color: Color) {
        var band = Path()
        band.move(to: CGPoint(x: 18, y: 20))
        band.addCurve(to: CGPoint(x: 54, y: 20), control1: CGPoint(x: 12, y: 58), control2: CGPoint(x: 60, y: 58))
        context.stroke(band, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        for x in [16.0, 54.0] {
            context.fill(Path(roundedRect: CGRect(x: x - 4, y: 17, width: 8, height: 13), cornerRadius: 4), with: .color(color))
            context.stroke(Path(roundedRect: CGRect(x: x - 5, y: 29, width: 10, height: 17), cornerRadius: 5), with: .color(color), lineWidth: 3)
        }
        context.fill(Path(ellipseIn: CGRect(x: 34, y: 44, width: 5, height: 5)), with: .color(CMFTheme.red))
    }

    private func drawPlaceholder(in context: inout GraphicsContext, size: CGSize, color: Color) {
        let circle = Path(ellipseIn: CGRect(x: 23, y: 15, width: 26, height: 26))
        context.stroke(circle, with: .color(color.opacity(0.7)), lineWidth: 2)
        var glyph = Path()
        glyph.move(to: CGPoint(x: 36, y: 22))
        glyph.addLine(to: CGPoint(x: 36, y: 32))
        context.stroke(glyph, with: .color(CMFTheme.red), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 35, y: 35, width: 2, height: 2)), with: .color(CMFTheme.red))
    }
}
