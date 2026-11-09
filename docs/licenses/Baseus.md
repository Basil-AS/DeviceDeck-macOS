# Baseus protocol provenance and implementation boundary

## Source inspected

- User-supplied Baseus Intelligent 2.18.0 (version code 185), arm64 split bundle.
- Bundle SHA-256: `c93512f905fca24d401d0c45d8e795a1e37db96864d0489fc051d437a53f4003`.
- Decompiled sources/resources are kept locally in the umbrella repository under `research/local-evidence/decompiled/baseus/`; the APK and vendor artwork are not redistributed.
- The findings and model-specific call paths are summarized in the umbrella repository's [`research/baseus-intelligent-findings.md`](https://github.com/Basil-AS/DeviceDeck/blob/develop/research/baseus-intelligent-findings.md).

## EP10 Pro support implemented here

The Android app routes the exact name `Baseus Bass EP10 Pro` through classic `ClassBt` / RFCOMM using UUID `00001101-0000-1000-8000-00805F9B34FB`. The app writes bare `BA` commands for this model; its shared `789C` wrapper predicate does not include it. The initial macOS session implements:

| Operation | Request | Expected response / validation |
| --- | --- | --- |
| Battery | `BA 02` | `AA 02 L 00 R 01`; L/R are percentages |
| Read noise mode | `BA 33` | `AA 33` state payload; mode 0=off, 1=ANC, 2=transparency |
| Set noise mode | `BA 34 mode type` | `AA 34 01` acknowledgment, then a separate `BA 33` state readback |

For EP10 Pro the vendor app's ANC manager selects type `101`; the implementation preserves the observed type when already in ANC and otherwise uses that app default. Off/transparency use the app's no-level sentinel `FF`.

The shared DeviceDeck app now also reads left/right v2 gesture bindings with `BA 8C <button> FF`, offers the mapped primary actions through the existing gesture picker, and writes a selected action with `BA 8D <button> <layout> <function>`. A successful acknowledgment is followed by a fresh read of both gesture maps and a value comparison. Layouts and action IDs come from the statically decompiled vendor UI configuration. `BA 8E`/`BA 8F` child-action editing (for example, selecting the exact modes in a noise-cycle action) remains unimplemented. This path has not been validated on a physical EP10 Pro.

## Verification boundary

The packet codec and session tests cover raw command bytes, fragmented/coalesced SPP replies, noise readback, and gesture-map read/write/readback. No EP10 Pro hardware is connected in this environment. Therefore this is **implemented, unverified partial control**, not a claim of complete or hardware-accepted support. Bowie MF1's mapped control features, Bowie 30's BLE profile, and Blade 2's separate power-device flow require separate implementations and validation.

No vendor application code, APK resources, product artwork, or binary assets are copied into this project. This document records protocol facts derived from the supplied app for interoperability; it is not a license grant for Baseus materials.
