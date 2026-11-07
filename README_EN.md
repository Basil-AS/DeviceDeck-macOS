# DeviceDeck for macOS

DeviceDeck is an open-source macOS menu bar app for controlling supported Bluetooth headphones. This is a HeyBuds fork; its GPL license and required notices are preserved. Development happens in the public [DeviceDeck-macOS repository](https://github.com/Basil-AS/DeviceDeck-macOS).

Check the [compatibility matrix](docs/SUPPORTED_DEVICES.md) for each model and feature. A catalog entry or simulated protocol test does not prove compatibility with physical hardware. Initial Edifier W820NB Plus BLE support still needs validation with the actual headphones.

## Build

Requires Apple Silicon, Swift 6.4 and the macOS 27 SDK. The app targets macOS 15 and later.

```sh
git clone https://github.com/Basil-AS/DeviceDeck-macOS.git
cd DeviceDeck-macOS
swift test --no-parallel
bash scripts/build.sh
open dist/DeviceDeck.app
```

The build produces `dist/DeviceDeck.app` and `dist/DeviceDeck-macos-arm64.dmg`. Check for updates opens the [DeviceDeck Releases page](https://github.com/Basil-AS/DeviceDeck-macOS/releases); the app does not install updates automatically.

CI publishes releases for `macos-v<version>` tags. Builds are currently ad-hoc signed and not Apple-notarized; macOS may require you to allow the app in Security settings.

## Development and license

Branches: `main` is for releases, `develop` is for integration, and changes go through feature PRs into `develop`. See [RELEASING.md](docs/RELEASING.md) for packaging and [ARCHITECTURE.md](docs/ARCHITECTURE.md) for implementation details.

Code is licensed under [GPL-3.0-or-later](LICENSE). Protocol sources, licenses and attribution are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). DeviceDeck is not affiliated with the makers of supported devices.
