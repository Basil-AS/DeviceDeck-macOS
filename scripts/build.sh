#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
config=${1:-release}
if [[ "$config" != release && "$config" != debug ]]; then echo 'Usage: bash scripts/build.sh [release|debug]' >&2; exit 2; fi
# Lower the runtime target without opting new systems into an older SDK's UI.
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
swift build -c "$config" --arch arm64 --product HeyBuds \
  -Xlinker -platform_version -Xlinker macos -Xlinker 15.0 -Xlinker "$sdk_version"
bin_dir=$(swift build -c "$config" --arch arm64 --show-bin-path)
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/.DeviceDeck-build.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/DeviceDeck.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/HeyBuds" "$app/Contents/MacOS/HeyBuds"
if [[ "$config" == release ]]; then xcrun strip -S -x "$app/Contents/MacOS/HeyBuds"; fi
cp -R "$bin_dir/HeyBuds_HeyBudsProtocol.bundle" "$app/Contents/Resources/"
# Keep only the public image and minimal bundle metadata from the app resources.
mkdir -p "$app/Contents/Resources/HeyBuds_HeyBuds.bundle/Contents/Resources"
cp "$bin_dir/HeyBuds_HeyBuds.bundle/Contents/Info.plist" "$app/Contents/Resources/HeyBuds_HeyBuds.bundle/Contents/"
cp Sources/HeyBuds/Resources/GitHub.pdf "$app/Contents/Resources/HeyBuds_HeyBuds.bundle/Contents/Resources/"
mkdir -p "$app/Contents/Frameworks"
# Keep the source catalogs readable; ship equivalent compact JSON in the app.
python3 - "$app/Contents/Resources/HeyBuds_HeyBudsProtocol.bundle" <<'PY'
import json
import pathlib
import sys
sources = {p.name: p for p in pathlib.Path('Sources/HeyBudsProtocol/Resources').glob('*.json')}
seen = set()
for path in pathlib.Path(sys.argv[1]).rglob('*.json'):
    if path.name not in sources:
        path.unlink()  # Also discard stale resources left by an incremental build.
        continue
    value = json.loads(path.read_text())
    assert value == json.loads(sources[path.name].read_text()), path.name
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n')
    seen.add(path.name)
assert seen == sources.keys(), 'Missing runtime catalog'
PY
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
cp -R Licenses "$app/Contents/Resources/"
xcrun swift scripts/make-icon.swift "$stage/DeviceDeck.iconset"
iconutil -c icns "$stage/DeviceDeck.iconset" -o "$app/Contents/Resources/DeviceDeck.icns"
# Recompress PNG streams losslessly; keep every icon size, pixel and metadata chunk.
python3 - "$app/Contents/Resources/DeviceDeck.icns" <<'PY'
from pathlib import Path
import struct
import sys
import zlib

def compact_png(data):
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        return data
    chunks = []
    offset = 8
    while offset < len(data):
        size = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        chunks.append((kind, data[offset + 8:offset + 8 + size]))
        offset += size + 12
    original = b''.join(value for kind, value in chunks if kind == b'IDAT')
    packed = zlib.compress(zlib.decompress(original), 9)
    if len(packed) >= len(original):
        return data
    result = data[:8]
    written = False
    for kind, value in chunks:
        if kind == b'IDAT':
            if written:
                continue
            value = packed
            written = True
        result += struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind + value))
    assert zlib.decompress(packed) == zlib.decompress(original)
    return result

path = Path(sys.argv[1])
data = path.read_bytes()
assert data[:4] == b'icns' and struct.unpack_from('>I', data, 4)[0] == len(data)
offset = 8
result = b''
while offset < len(data):
    kind, size = struct.unpack_from('>4sI', data, offset)
    value = compact_png(data[offset + 8:offset + size])
    result += struct.pack('>4sI', kind, len(value) + 8) + value
    offset += size
path.write_bytes(b'icns' + struct.pack('>I', len(result) + 8) + result)
PY
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.devicedeck.macos</string>
<key>CFBundleExecutable</key><string>HeyBuds</string>
<key>CFBundleName</key><string>DeviceDeck</string>
<key>CFBundleDisplayName</key><string>DeviceDeck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.7.0-alpha.7</string>
<key>CFBundleVersion</key><string>24</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>CFBundleLocalizations</key><array><string>zh-Hans</string><string>en</string></array>
<key>CFBundleIconFile</key><string>DeviceDeck.icns</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>DeviceDeck 通过蓝牙读取设备状态并控制支持的功能。

DeviceDeck uses Bluetooth to read device status and control supported features.</string>
<key>NSHumanReadableCopyright</key><string>DeviceDeck contributors. GPL-3.0-or-later. Includes attributed third-party code.</string>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign "${DEVICEDECK_SIGN_IDENTITY:--}" --identifier app.devicedeck.macos "$app"
codesign --verify --strict "$app"
test "$(lipo -archs "$app/Contents/MacOS/HeyBuds")" = arm64
if [[ -e dist/DeviceDeck.app ]]; then
  mkdir -p dist/backups
  mv dist/DeviceDeck.app "dist/backups/DeviceDeck-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
mv "$app" dist/DeviceDeck.app
python3 scripts/disk_image.py dist/DeviceDeck.app dist/DeviceDeck-macos-arm64.dmg
echo "Built: $PWD/dist/DeviceDeck.app"
