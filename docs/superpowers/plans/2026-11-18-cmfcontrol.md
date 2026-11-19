# CMFControl Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app for CMF/Nothing headphones with a profile-driven RFCOMM protocol layer, mockable settings UI, and a launchable signed app bundle.

**Architecture:** Swift Package executable, app bundle assembled by `build.sh`; protocol framing is isolated from command profiles; IOBluetooth delegate callbacks feed a main-actor observable manager; SwiftUI `MenuBarExtra` displays live or mock state.

**Tech Stack:** Swift 5.9+, SwiftUI, Observation, Foundation, IOBluetooth, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-11-18-cmfcontrol-design.md`

## Global Constraints

- macOS 14+ and no third-party dependencies.
- Use the Nothing SPP `55 | control(2 LE) | command(2 LE) | length(2 LE) | sequence | payload | CRC-16/MODBUS` frame and documented SPP UUID.
- Keep unsupported or unclear model commands unavailable, especially dual-connection writes.
- Keep mock mode capable of exercising all settings controls.
- Bundle with `LSUIElement = YES`, Bluetooth usage description, and ad-hoc signing; App Sandbox stays disabled.

## Review Focus

- Fragmented/coalesced input and invalid CRC must not corrupt later valid frames: inspect parser resynchronization and bounded buffering.
- Unknown command profiles must never transmit guessed settings: inspect command availability gates.
- Bluetooth callbacks must not mutate SwiftUI state off the main actor: inspect delegate bridge and observable manager boundaries.
- Bundle metadata must survive `build.sh`: inspect generated Info.plist and signature commands.
- Mock mode must remain usable with zero paired devices: inspect app startup and control flow.

---

### Task 1: Package, app entry, and bundle script

**Files:** `Package.swift`, `Sources/CMFControl/App.swift`, `Info.plist`, `build.sh`

**Interfaces:** Produces the executable target and metadata consumed by the remaining tasks.

- [ ] Create the macOS executable target with system framework links and app entry point.
- [ ] Add the app privacy and menu-bar-only Info.plist keys.
- [ ] Add `build.sh` to run `swift build`, assemble `CMFControl.app`, and ad-hoc sign it.
- [ ] Run `swift build`; expected: package compiles on macOS.
- [ ] Run `./build.sh`; expected: signed `CMFControl.app` is created.

### Task 2: Protocol and command profiles

**Files:** `Sources/CMFControl/Protocol/CRC16.swift`, `NothingPacket.swift`, `CMFCommands.swift`

**Interfaces:** `NothingPacket` exposes encoding and a streaming parser; command builders accept typed values and a verified profile, returning no command when unsupported.

- [ ] Implement MODBUS CRC-16 and packet encoder/parser with two-byte payload length, little-endian fields, and safe resynchronization.
- [ ] Add typed battery, ANC, EQ, bass, latency, spatial, dual-connection, firmware, and model values.
- [ ] Add documented Nothing / CMF Buds command mappings and payload parsers; leave unresolved dual-connection writes disabled.
- [ ] Run `swift build`; expected: protocol target compiles.

### Task 3: Bluetooth manager and menu UI

**Files:** `Sources/CMFControl/Bluetooth/CMFBluetoothManager.swift`, `Sources/CMFControl/UI/MenuBarView.swift`, `Sources/CMFControl/UI/Components/`

**Interfaces:** `CMFBluetoothManager` publishes connection, device, battery, firmware, settings, and packet-log state; view actions use async update methods.

- [ ] Add paired-device scanning, Nothing/CMF name matching, configured SDP discovery, channel-15 fallback, asynchronous RFCOMM open, reconnect notifications, and state sync.
- [ ] Serialize transport access and marshal callback state to `MainActor`; log raw TX/RX packets.
- [ ] Add mock mode with representative device and battery state.
- [ ] Build the high-contrast menu bar header, controls, toggles, and collapsible packet drawer.
- [ ] Run `swift build` and `./build.sh`; expected: executable and `.app` bundle compile successfully.

