# Nothing / CMF protocol notes

CMFControl uses the public reverse-engineered Nothing SPP findings as a starting profile. This is an undocumented vendor protocol, and community protocol tables can be incomplete or model-specific. The app logs raw packets and leaves dual-connection writes disabled because the command is documented without a verified on/off payload.

## Frame

`55 | control (2-byte LE) | command (2-byte LE) | payload length (2-byte LE) | operation/sequence | payload | optional CRC-16/MODBUS (2-byte LE)`

The request control field used by the documented Nothing profile is `0x0160`; its wire bytes are `60 01` and the `0x20` flag indicates a CRC footer. Some observed responses use other control values and omit the CRC. The RFCOMM service UUID is `aeac4a03-dff5-498f-843a-34487cf133eb`. SDP supplies the channel; known fallbacks are 15 for Nothing Ear, 28 for CMF Headphone Pro, and 16 for CMF Buds 2. A response commonly clears request command bit 15; unsolicited ANC and battery updates use commands `0xE003` and `0xE001`.

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
| In-ear detection query / set (experimental) | `0xC00E` / `0xF004` | set: `[01, 01, on]`; the on/off byte values (`01`/`00`) are unconfirmed |
| Firmware query | `0xC042` | none |
| Model query | `0xC01C` | none |

ANC values are high `01`, mid `02`, low `03`, adaptive `04`, off `05`, and transparency `07`. EQ values are balanced `00`, voice `01`, more treble `02`, more bass `03`, and custom `05`. Bass levels 1–5 use `[01, level]`; zero uses `[00, 00]`.

The EQ picker sends the documented one-byte preset value and reads it back from the first response byte. Selecting Custom (`05`) selects the curve stored on the headphones; The Sound tab's custom band editor is a local preview: the band write (`0xF06D` in the Nada notes) has no documented layout, so band values are never sent.

Battery responses begin with a component count followed by `(component ID, level)` pairs. IDs `02`, `03`, and `04` identify left, right, and case; ID `06` represents both earbuds together. The top bit of level marks charging and the lower seven bits hold the percentage.

## References

- [Nada protocol notes](https://github.com/chukfinley/nada/blob/main/docs/PROTOCOL.md) — reverse-engineered from Nothing X and verified on CMF Buds 2 Plus (B184).
- [Nothing Ear (2) packet captures](https://bharadwaj-raju.github.io/posts/nothing-ear-2-on-linux/) — concrete RFCOMM frames and observed behavior.
- [Nothing/CMF device compatibility notes](https://github.com/ezvk/nadamas/blob/main/DEVICES.md) — model coverage and limits.
- [NT Link capture notes](https://github.com/ncr/omarchy-headphones/blob/main/PROTOCOL.md) — CMF Headphone Pro channel 28, battery pushes, and device-info activation sequence.

CMFControl does not include or depend on these projects; these links document protocol provenance and compatibility caveats.
