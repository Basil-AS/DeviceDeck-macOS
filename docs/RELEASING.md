# Releasing DeviceDeck for macOS

The `develop` branch is the integration line. Prepare releases from a reviewed release branch, merge it into `main`, and tag the merge as `macos-v<version>` (for example, `macos-v0.7.0`). The tag workflow runs source audit, Swift tests, app and DMG audits, packages the source archive, and publishes the artifacts to GitHub Releases.

Use Apple Silicon, Swift 6.4 and the macOS 27 SDK. The app targets macOS 15 or later. Keep `AppIdentity.version`, `CFBundleShortVersionString` in `scripts/build.sh` and `CHANGELOG.md` aligned; increment `CFBundleVersion` on every build intended for distribution.

```sh
python3 scripts/audit-source.py
swift test --no-parallel
bash scripts/build.sh
python3 scripts/audit-app.py
python3 scripts/package-source.py
```

The application uses its own bundle identifier, icon, GitHub project and release page. The update action opens DeviceDeck Releases; it does not install software automatically. Device control stays offline. Vendor apps, accounts, telemetry and upstream signing keys are not used.

## GitHub publication

Push the reviewed `macos-v<version>` tag after merging the release into `main`. GitHub Actions builds `DeviceDeck.app`, audits the app and `DeviceDeck-macos-arm64.dmg`, then creates a release with the DMG and reproducible source archive. The app is currently ad-hoc signed and not Apple-notarized; a Developer ID certificate and notarization credentials are required before distributing a Gatekeeper-clean installer.

Do not tag a release until the release notes, device support claims, licenses and artifact audit match the shipped code. Hardware verification must be stated per model and feature; simulated protocol checks are not hardware acceptance.
