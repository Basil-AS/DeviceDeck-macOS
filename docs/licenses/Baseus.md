# Baseus protocol provenance and implementation boundary

## Source inspected

- User-supplied Baseus Intelligent 2.18.0 (version code 185), arm64 split bundle.
- Bundle SHA-256: `c93512f905fca24d401d0c45d8e795a1e37db96864d0489fc051d437a53f4003`.
- Decompiled sources/resources are kept locally in the umbrella repository under `research/local-evidence/decompiled/baseus/`; the APK and vendor artwork are not redistributed.
- The findings and model-specific call paths are summarized in [`research/baseus-intelligent-findings.md`](../../../../research/baseus-intelligent-findings.md).

## EP10 Pro support implemented here

The Android app routes the exact name `Baseus Bass EP10 Pro` through classic `ClassBt` / RFCOMM using UUID `00001101-0000-1000-8000-00805F9B34FB`. The app writes bare `BA` commands for this model; its shared `789C` wrapper predicate does not include it. The initial macOS session implements:

| Operation | Request | Expected response / validation |
| --- | --- | --- |
| Battery | `BA 02` | `AA 02 L 00 R 01`; L/R are percentages |
| Read noise mode | `BA 33` | `AA 33` state payload; mode 0=off, 1=ANC, 2=transparency |
| Set noise mode | `BA 34 mode type` | `AA 34 01` acknowledgment, then a separate `BA 33` state readback |

For EP10 Pro the vendor app's ANC manager selects type `101`; the implementation preserves the observed type when already in ANC and otherwise uses that app default. Off/transparency use the app's no-level sentinel `FF`. Other command families, EQ, gestures, firmware, wear detection, and case battery are not implemented by this initial session.

## Verification boundary

The packet codec and session tests cover raw command bytes, fragmented/coalesced SPP replies, and readback-gated writes. No EP10 Pro hardware is connected in this environment. Therefore this is an **implemented, unverified initial control path**, not a claim of complete or hardware-accepted support. Bowie MF1's SPP route, Bowie 30's BLE profile, and Blade 2's separate power-device flow require separate implementations and validation.

No vendor application code, APK resources, product artwork, or binary assets are copied into this project. This document records protocol facts derived from the supplied app for interoperability; it is not a license grant for Baseus materials.
