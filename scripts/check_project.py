#!/usr/bin/env python3
"""Fail closed on project device-family and bundle-ID drift."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
project = (root / 'TiltTrail.xcodeproj/project.pbxproj').read_text()
settings = re.findall(r'\b(TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)\s*=\s*([^;]+);', project)
for key, expected, minimum in [('TARGETED_DEVICE_FAMILY', '1', 4),
                                ('PRODUCT_BUNDLE_IDENTIFIER', 'com.infinityball.tilttrail', 2)]:
    values = [value.strip('" ') for name, value in settings if name == key]
    if len(values) < minimum or any(value != expected for value in values):
        raise SystemExit(f'{key}: expected {expected} in at least {minimum} configurations; got {values}')
pin = json.loads((root / 'toolchain.json').read_text())
assert pin['targeted_device_family'] == '1' and pin['bundle_identifier'] == 'com.infinityball.tilttrail'
print('iPhone family and bundle ID source gate: PASS')

# App icon artwork gate: real square opaque edge-to-edge art, byte-identical in the catalog.
store_icon = root / 'AppStore/icon.png'
catalog_icon = root / 'TiltTrail/Assets.xcassets/AppIcon.appiconset/icon.png'
for path in (store_icon, catalog_icon):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 26:
        raise SystemExit(f'{path}: not a PNG')
    width, height = int.from_bytes(data[16:20], 'big'), int.from_bytes(data[20:24], 'big')
    depth, color_type = data[24], data[25]
    if (width, height) != (1024, 1024) or depth != 8 or color_type not in (0, 2):
        raise SystemExit(f'{path}: expected 1024x1024 8-bit RGB, got {(width, height)} depth={depth} color={color_type}')
    if b'tRNS' in data:
        raise SystemExit(f'{path}: PNG carries transparency (tRNS chunk)')
if store_icon.read_bytes() != catalog_icon.read_bytes():
    raise SystemExit('App Store artwork and app-icon catalog artwork differ')
catalog = json.loads((root / 'TiltTrail/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
if not [i for i in catalog['images']
        if i.get('filename') == 'icon.png' and i.get('size') == '1024x1024' and i.get('idiom') == 'universal']:
    raise SystemExit('AppIcon.appiconset lacks a universal 1024x1024 icon.png entry')
print('App icon artwork gate: PASS')
