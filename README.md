# CMFControl

A native macOS menu bar app for Nothing and CMF headphones, styled after the Nothing X app: true black, flat grey cards, a dot-matrix typeface and a single red accent. It targets macOS 14 and uses SwiftUI and Apple's IOBluetooth framework.

## Features

- **Home**: product photo for the connected model, battery dials (headset, left/right buds, case) and noise control (ANC low/mid/high/adaptive, transparency, off).
- **Sound**: equaliser with a live curve and presets (Balanced, Voice, More Bass, More Treble, Custom), a 3-band custom editor, Bass Enhance and Spatial Audio.
- **Control**: Low Lag Mode, Dual Connection and in-ear / wear detection.
- **Device**: model, firmware, demo mode and a raw packet inspector.

Not every feature is verified on every model. Custom EQ band values are a preview only (the band payload is not documented), in-ear detection is experimental, and Dual Connection writes are not mapped. See `docs/NOTHING-PROTOCOL.md`.

## Product images

Product photos live in `Sources/CMFControl/Resources/Assets.xcassets` and are bundled into the app (nothing is fetched at runtime). They were taken from nothing.tech and remain Nothing's property. Models without a photo fall back to local vector artwork. The model-to-image mapping is in `ProductCatalog` in `DeviceArtwork.swift`.

## Build in Xcode

1. Open `CMFControl.xcodeproj`.
2. Select the `CMFControl` scheme and **My Mac**, then Build (⌘B) or Run (⌘R).

The app runs as a menu bar utility with App Sandbox disabled for RFCOMM access.

## Build from Terminal

Run `./build.sh`. It builds with SwiftPM and bundles the app, including product images, at `.build/CMFControl.app`.

## Dashboard, gestures and devices

- **Menu bar**: the icon shows battery as `L·R`, `AVG` or `MIN` (Device tab > Menu bar battery).
- **Dashboard**: the expand button in the popover header (or Device tab > Open dashboard) opens a full window with every panel. It shows in the Dock while open.
- **Equaliser**: Balanced, Voice, More Bass, More Treble and a 3-band Custom EQ that is written to the device. Custom curves can be saved, reloaded and deleted.
- **Gestures**: per-earbud double tap, triple tap and press-and-hold actions, including which noise modes the press cycles through. Only gestures the device reports are shown.
- **Find my buds**: rings the left, right or both earbuds.
- **My devices**: switch between paired Nothing / CMF devices or pair a new one. With nothing connected the app shows a scanning animation.
- Protocol details for custom EQ, gestures and ring were taken from the community `nothing-x-macos` project.
