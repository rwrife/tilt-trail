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
