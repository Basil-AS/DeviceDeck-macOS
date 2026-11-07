# DeviceDeck development notes

This repository is the DeviceDeck fork of HeyBuds. `main` is the release branch, `develop` is the integration branch, and feature changes merge to `develop` through PRs. The umbrella repo pins this fork as a submodule.

Keep the upstream GPL-3.0-or-later license, third-party notices, and attribution. Preserve existing brands while adding Edifier and other BLE profiles as isolated protocol/session modules. Catalog presence is not hardware verification.

DeviceDeck has its own bundle identifier, version, icon, GitHub destination and manual release-page updater. Do not restore an upstream appcast, signing key, payment QR or release endpoint. macOS release artifacts must state that they are ad-hoc signed until a DeviceDeck Developer ID/notarization credential is configured.
