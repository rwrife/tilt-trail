#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
expected_sha="${1:?usage: Scripts/ci.sh <expected-sha>}"
artifacts="$PWD/build/ci-artifacts"
mkdir -p "$artifacts"
phase=init
udid=unselected
trap 'rc=$?; printf "expected_sha=%s\nactual_sha=%s\nphase=%s\nexit_status=%s\nsimulator_udid=%s\ndeveloper_dir=%s\n" "$expected_sha" "$(git rev-parse HEAD)" "$phase" "$rc" "${udid:-unselected}" "${DEVELOPER_DIR:-unselected}" > "$artifacts/provenance.txt"' EXIT
[[ "$(git rev-parse HEAD)" == "$expected_sha" ]]

phase=source_gates
python3 scripts/check_project.py
bash scripts/check_zero_network.sh
python3 -m unittest discover -s Scripts/tests -q

phase=xcode_pin
export DEVELOPER_DIR
DEVELOPER_DIR=$(python3 Scripts/select_xcode.py --toolchain toolchain.json)
xcodebuild -version

phase=simulator_runtime
# Derive the required runtime from the PINNED simulator SDK; never accept a newer one.
sdk=$(xcrun --sdk iphonesimulator --show-sdk-version)
required="com.apple.CoreSimulator.SimRuntime.iOS-${sdk//./-}"
runtime_present() {
  xcrun simctl list runtimes -j | python3 -c 'import json,sys; required=sys.argv[1]; sys.exit(0 if any(r.get("identifier") == required and r.get("isAvailable") for r in json.load(sys.stdin)["runtimes"]) else 1)' "$required"
}
if ! runtime_present; then
  xcodebuild -downloadPlatform iOS -architectureVariant universal 2>&1 | tee "$artifacts/runtime-download.log"
fi
runtime_present

phase=package_tests
swift test --package-path Packages/TiltTrailKit 2>&1 | tee "$artifacts/package-tests.log"

phase=app_build
xcodebuild build -project TiltTrail.xcodeproj -scheme TiltTrail -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$artifacts/build.log"
plist=build/DerivedData/Build/Products/Debug-iphonesimulator/TiltTrail.app/Info.plist
plutil -convert json -o "$artifacts/app-info.json" "$plist"
python3 - "$artifacts/app-info.json" <<'PY'
import json, sys
info = json.load(open(sys.argv[1]))
assert info['UIDeviceFamily'] == [1], info.get('UIDeviceFamily')
assert info['CFBundleIdentifier'] == 'com.infinityball.tilttrail', info.get('CFBundleIdentifier')
print('Built UIDeviceFamily == [1] and bundle ID: PASS')
PY

phase=simulator_select
udid=$(python3 Scripts/select_simulator.py --sdk "$sdk" --devices-json-out "$artifacts/devices.json")
phase=simulator_boot
python3 Scripts/boot_simulator.py boot --udid "$udid" \
  --devices-json "$artifacts/devices.json" --log "$artifacts/simulator-boot.log" \
  --boot-timeout 120 --bootstatus-timeout 300

phase=ui_tests
xcodebuild test -project TiltTrail.xcodeproj -scheme TiltTrail -only-testing:TiltTrailUITests \
  -configuration Debug -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath build/DerivedData -resultBundlePath "$artifacts/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$artifacts/test.log"
phase=complete
