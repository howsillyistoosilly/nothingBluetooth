# Nothing / CMF protocol notes

CMFControl uses the public reverse-engineered Nothing SPP findings as a starting profile. This is an undocumented vendor protocol, and community protocol tables can be incomplete or model-specific. The app logs raw packets (Device tab > Packet inspector) and leaves dual-connection writes disabled because the command is documented without a verified on/off payload.

## Frame

`55 | control (2-byte LE) | command (2-byte LE) | payload length (2-byte LE) | operation/sequence | payload | optional CRC-16/MODBUS (2-byte LE)`

**CRC, verified on a CMF Buds 2a:** requests checksum the whole frame (matches the Ear (2) captures). Replies from the device checksum the *payload only*. CMFControl accepts either form; rejecting replies on the whole-frame CRC made every reply look corrupt and is what kept battery from loading.

The request control field used by the documented Nothing profile is `0x0160`; its wire bytes are `60 01` and the `0x20` flag indicates a CRC footer. Some observed responses use other control values and omit the CRC. The RFCOMM service UUID is `aeac4a03-dff5-498f-843a-34487cf133eb`. SDP supplies the channel (channel 6 on the Buds 2a we tested); known fallbacks are 15 for Nothing Ear, 28 for CMF Headphone Pro, and 16 for CMF Buds 2. Call `IOBluetoothDevice.openConnection()` before opening RFCOMM; without it the open can hang forever. Writes use `writeSync`. A response commonly clears request command bit 15; unsolicited ANC and battery updates use commands `0xE003` and `0xE001`.

The channel sends device-info query `0xC006` first and waits up to 1.5 seconds before the regular state-sync queries, as some headsets ignore commands until that activation exchange completes.

## Common mapped commands

| Feature | Command | Payload |
| --- | --- | --- |
| Battery query | `0xC007` | none |
| ANC query / set | `0xC01E` / `0xF00F` | set: `[01, mode, 00]` |
| EQ query / set | `0xC01F` / `0xF010` | set: preset byte |
| Bass boost set | `0xF051` | `[enabled, level]` |
| Low latency query / set | `0xC041` / `0xF040` | set: `[01]` on, `[02]` off |
| Spatial audio query / set | `0xC04F` / `0xF052` | set: `[01]` on, `[00]` off |
| Dual connection query | `0xC027` | set command semantics are not mapped |
| In-ear detection query / set | `0xC00E` / `0xF004` | set: `[01, 01, on]`, matching Ear (2) captures (`01` on, `00` off) |
| Custom EQ query / set | `0xC024` / `0xF041` | see below |
| Gesture query / set | `0xC018` / `0xF003` | set: `[01, side, 01, gesture, action]`; side `02` left, `03` right |
| Find my buds set | `0xF002` | `[side, 01]` ring, `[side, 00]` stop |
| Firmware query | `0xC042` | none |
| Model query | `0xC01C` | none |

ANC values are high `01`, mid `02`, low `03`, adaptive `04`, off `05`, and transparency `07`. EQ values are balanced `00`, voice `01`, more treble `02`, more bass `03`, and custom `05`. Bass levels 1–5 use `[01, level]`; zero uses `[00, 00]`.

The EQ picker sends the one-byte preset value and reads it back from the first response byte. Custom (`05`) uses the 3-band payload: `[03]`, total gain, then bass, mid and treble entries, each a little-endian float32 gain followed by fixed frequency and Q parameters. A positive overall gain is written as negative zero (`00 00 00 80`). CMFControl waits 250 ms after the last slider change before sending. This layout comes from the `nothing-x-macos` project and is not yet verified against every model.

Gesture codes: double tap `02`, triple tap `03`, press and hold `07`, double press and hold `09`. Action codes: none `01`, play/pause `02`, previous `08`, next `09`, noise control (all modes) `0A`, voice assistant `0B`, volume up `12`, volume down `13`, noise control ANC/off `14`, transparency/off `15`, ANC/transparency `16`. The reply is a count followed by `[side, ?, gesture, action]` groups. Unknown gesture or action codes are kept and shown as raw numbers.

Battery responses begin with a component count followed by `(component ID, level)` pairs. IDs `02`, `03`, and `04` identify left, right, and case; ID `06` represents both earbuds together. The top bit of level marks charging and the lower seven bits hold the percentage.

Device-info (`0xC006`) replies are newline separated `device,type,value` rows; type `2` is firmware and type `4` the serial number.

## References

- [nothing-x-macos](https://github.com/nikiomori/nothing-x-macos) (GPL-3.0) — macOS app whose connection handling, custom EQ, gesture and find-my-buds formats CMFControl follows.
- [Nada protocol notes](https://github.com/chukfinley/nada/blob/main/docs/PROTOCOL.md) — reverse-engineered from Nothing X and verified on CMF Buds 2 Plus (B184).
- [Nothing Ear (2) packet captures](https://bharadwaj-raju.github.io/posts/nothing-ear-2-on-linux/) — concrete RFCOMM frames and observed behavior.
- [Nothing/CMF device compatibility notes](https://github.com/ezvk/nadamas/blob/main/DEVICES.md) — model coverage and limits.
- [NT Link capture notes](https://github.com/ncr/omarchy-headphones/blob/main/PROTOCOL.md) — CMF Headphone Pro channel 28, battery pushes, and device-info activation sequence.

CMFControl does not include or depend on these projects; these links document protocol provenance and compatibility caveats.
