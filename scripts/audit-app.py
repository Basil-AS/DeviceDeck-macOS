#!/usr/bin/env python3
"""Verify the distributable, including resource equivalence and DMG contents."""
import json
import plistlib
import re
import subprocess
import os
from disk_image import mounted
from source_package import ROOT

app = ROOT / 'dist/DeviceDeck.app'
resources = app / 'Contents/Resources'
bundle = resources / 'HeyBuds_HeyBudsProtocol.bundle'
expected = {p.name: p for p in (ROOT / 'Sources/HeyBudsProtocol/Resources').glob('*.json')}
actual = {p.name: p for p in bundle.rglob('*.json')}
assert actual.keys() == expected.keys(), 'Unexpected or missing runtime catalogs'
for name, path in actual.items():
    assert json.loads(path.read_text()) == json.loads(expected[name].read_text()), name
license_files = tuple('Licenses/' + p.name for p in sorted((ROOT / 'Licenses').glob('*.txt')))
for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md') + license_files:
    assert (resources / name).read_bytes() == (ROOT / name).read_bytes(), name
allowed = {
    'Contents/Info.plist', 'Contents/MacOS/HeyBuds', 'Contents/_CodeSignature/CodeResources',
    'Contents/Resources/DeviceDeck.icns', 'Contents/Resources/LICENSE',
    'Contents/Resources/THIRD_PARTY_NOTICES.md', 'Contents/Resources/Licenses/Realme-MIT.txt',
    'Contents/Resources/Licenses/EncoDeck-GPL-3.0.txt',
    'Contents/Resources/Licenses/Sony-MIT.txt',
    'Contents/Resources/HeyBuds_HeyBuds.bundle/Contents/Info.plist',
    'Contents/Resources/HeyBuds_HeyBuds.bundle/Contents/Resources/GitHub.pdf',
    'Contents/Resources/HeyBuds_HeyBudsProtocol.bundle/Contents/Info.plist',
} | {p.relative_to(app).as_posix() for p in actual.values()} | {'Contents/Resources/' + name for name in license_files}
def entries(directory):
    return {p.relative_to(directory).as_posix(): p for p in directory.rglob('*') if p.is_symlink() or p.is_file()}

def bytes_or_link(path):
    return os.readlink(path).encode() if path.is_symlink() else path.read_bytes()

files = entries(app)
assert set(files) == allowed, f'Unexpected app contents: {set(files) ^ allowed}'
assert (resources / 'HeyBuds_HeyBuds.bundle/Contents/Resources/GitHub.pdf').read_bytes() == (ROOT / 'Sources/HeyBuds/Resources/GitHub.pdf').read_bytes()
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleIdentifier'] == 'app.devicedeck.macos'
assert info['CFBundleName'] == 'DeviceDeck' and info['CFBundleDisplayName'] == 'DeviceDeck'
version = re.search(r'static let version="([^"]+)"', (ROOT / 'Sources/HeyBuds/AppIdentity.swift').read_text()).group(1)
assert info['CFBundleShortVersionString'] == version
assert info['LSMinimumSystemVersion'] == '15.0'
assert info['LSUIElement'] is True
assert subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/HeyBuds')], text=True).strip() == 'arm64'
build_metadata = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(app / 'Contents/MacOS/HeyBuds')], text=True)
assert re.search(r'^\s*minos 15\.0\s*$', build_metadata, re.MULTILINE), 'Executable deployment target differs from Info.plist'
linked_sdk = re.search(r'^\s*sdk ([\d.]+)\s*$', build_metadata, re.MULTILINE)
assert linked_sdk and tuple(map(int, linked_sdk.group(1).split('.'))) >= (26, 0), 'Linked SDK would opt new systems into legacy UI behavior'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
image = ROOT / 'dist/DeviceDeck-macos-arm64.dmg'
subprocess.run(['hdiutil', 'verify', '-quiet', str(image)], check=True)
with mounted(image) as volume:
    contents = {p.name for p in volume.iterdir()}
    assert contents == {'DeviceDeck.app', 'Applications'}, 'Unexpected installer contents'
    assert (volume / 'Applications').is_symlink() and os.readlink(volume / 'Applications') == '/Applications'
    packaged = entries(volume / 'DeviceDeck.app')
    assert packaged.keys() == files.keys(), 'DMG contains extra or missing application files'
    for name, path in files.items():
        assert packaged[name].is_symlink() == path.is_symlink(), name
        assert bytes_or_link(packaged[name]) == bytes_or_link(path), name
        assert bool(packaged[name].stat().st_mode & 0o111) == bool(path.stat().st_mode & 0o111), name
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(volume / 'DeviceDeck.app')], check=True)
print(f'App audit passed: {len(files)} files, {sum(p.stat().st_size for p in files.values())} app bytes, {image.stat().st_size} DMG bytes.')
