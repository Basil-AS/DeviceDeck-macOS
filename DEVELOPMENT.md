# DeviceDeck development notes

This repository is the DeviceDeck fork of HeyBuds. `main` is the release branch, `develop` is the integration branch, and feature changes merge to `develop` through PRs. The umbrella repo pins this fork as a submodule.

Keep HeyBuds' GPL-3.0-or-later license, third-party notices, and attribution. Preserve existing brands while adding Edifier and other BLE profiles as isolated protocol/session modules. Catalog presence is not hardware verification.

Never reuse upstream bundle identifiers, Sparkle signing keys, appcast URLs, or update infrastructure. Give the fork a distinct app identity and update channel before publishing installable releases.
