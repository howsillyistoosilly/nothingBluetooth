# CMFControl Design

## Intent

Build a native macOS 14+ menu bar utility that can inspect and control Nothing / CMF headphones over Bluetooth Classic RFCOMM. The app should provide a polished mock mode and a clear path for model-specific protocol profiles, without presenting guessed command IDs or payload layouts as verified device support.

## Goals

- A Swift Package executable that can be bundled as a menu bar `.app`, with `LSUIElement`, Bluetooth usage text, no third-party packages, and ad-hoc signing in `build.sh`.
- A testable protocol layer for MODBUS CRC-16, frame encoding, fragmented/coalesced stream parsing, strongly typed settings, and raw TX/RX logging.
- A SwiftUI `MenuBarExtra` for battery, firmware, noise control, EQ/bass, and feature toggles, plus simulated state when hardware is unavailable.
- An IOBluetooth manager that finds paired Nothing/CMF audio devices, resolves RFCOMM channel IDs from SDP with channel 15 fallback, opens asynchronously, reconnects, and updates observable UI state on the main actor.

## Non-goals

- Claiming compatibility with an untested headphone model or firmware.
- Inventing vendor command IDs, payload layouts, or an SDP UUID and treating them as confirmed.
- Bluetooth LE control, firmware updates, or persistent configuration storage.

## Constraints and assumptions

- Minimum deployment target is macOS 14. Use Swift, SwiftUI, Observation, Foundation, and IOBluetooth only.
- The user-provided `55 60 01` request prefix and two-byte little-endian command ID map to the public Nothing/CMF SPP frame layout: `55 | control(2 LE) | command(2 LE) | payload length(2 LE) | operation/sequence | payload | optional CRC-16/MODBUS(2 LE)`. Requests use control `0x0160`; observed responses can vary the control field and omit CRC when its flag is clear.
- A public protocol write-up documents common Nothing Ear / CMF Buds command IDs and the SPP service UUID, with CMF Buds 2 Plus hardware verification. The app uses these values for common controls. Commands whose payload semantics remain unclear, including dual-connection writes, stay unavailable until verified for a model.
- SDP lookup uses the documented Nothing SPP service UUID; known model fallbacks are channel 15 for Nothing Ear, 28 for CMF Headphone Pro, and 16 for CMF Buds 2.
- RFCOMM delegate work is serialized away from SwiftUI state; observable state mutations are marshalled to `MainActor`.
- The app is packaged by `swift build` plus a generated `.app` bundle and `codesign -s -`; the package executable links system frameworks and does not enable App Sandbox.
- The repository is currently empty and not initialized as a Git repository.

## Approaches

1. **Profile-based app (recommended/default):** deliver the complete menu bar UI, mock mode, transport, framing/parser, logging, and profile interface. Unknown hardware commands remain disabled until verified. This gives a useful app and discovery surface while avoiding incorrect writes.
2. **Discovery tool first:** build only scanning, RFCOMM, packet inspection, and mock fixtures, then add the full controls after capturing one specific headset. This reduces assumptions but postpones the requested control UI.
3. **Guessed universal commands:** hard-code guessed command values and payloads to attempt control immediately. This is quick but risks silently mapping controls incorrectly and is not selected.

The default is approach 1 because it implements the requested app shape while isolating the missing model-specific facts in profiles.

## Architecture

- `Sources/CMFControl/Protocol/CRC16.swift`: MODBUS CRC implementation.
- `Sources/CMFControl/Protocol/NothingPacket.swift`: Nothing SPP packet model, encoder, and bounded stream parser that resynchronizes on the frame header and rejects invalid length/CRC.
- `Sources/CMFControl/Protocol/CMFCommands.swift`: typed settings, common Nothing / CMF Buds command values, battery/status parsers, and a profile-driven command encoder. Unknown command semantics remain unavailable rather than guessed.
- `Sources/CMFControl/Bluetooth/CMFBluetoothManager.swift`: `@Observable @MainActor` state facade and IOBluetooth transport/delegate bridge, with discovery, SDP/channel resolution, reconnect, sync queue, send methods, and mock mode.
- `Sources/CMFControl/UI/MenuBarView.swift` and `UI/Components/`: monochrome menu bar interface and reusable controls.
- `Sources/CMFControl/App.swift`: app entry point and menu bar scene.
- `Package.swift`, `Info.plist`, and `build.sh`: package metadata, app privacy/agent keys, bundle creation, framework linking, and signing.

## Open protocol facts

The common profile has published Nothing/CMF Buds command values but is not a promise that every CMF over-ear model implements them. Confirm feature support against the selected headset; add or disable profile values where model behavior differs. Dual-connection write semantics remain unresolved and are disabled for real hardware.

## Acceptance

- `swift build` builds the app executable on macOS 14+.
- `./build.sh` produces a launchable `CMFControl.app` with the required Info.plist values and ad-hoc signature.
- Mock mode can exercise the complete control UI and packet log without connected hardware.
- The parser tolerates arbitrary RFCOMM chunk boundaries and does not emit frames with bad CRC.
- Real writes are enabled only by a profile that supplies verified commands and payload mappings.
