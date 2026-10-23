# Tilt Trail

**Pitch:** Offline iPhone tilt-labyrinth game: guide an original marble through handcrafted obstacle courses with optional motion controls, transparent checkpoints and local time trials.

## Overview and motivation
Tilt Trail gives casual players a short, tactile route-planning challenge without accounts, ads, subscriptions, or online leaderboards. Each course has visible hazards, a start, checkpoints and finish. Players learn a route, roll with touch or optional device tilt, retry, and compare their own times. Original course designs and artwork only; no franchise assets or names.

## Target users and use cases
- Commuter plays one short course with thumb drag while motion control stays off.
- Player enables tilt on a stationary device, calibrates neutral angle, and retries a course from its last checkpoint.
- Player exports local times and settings before replacing their phone.

## Intended workflow
Choose course → select touch or tilt input → preview hazards and checkpoints → steer marble → fall or reach checkpoint → retry/finish → see elapsed time and optional personal best. Pause and resume without background motion sampling. No online features.

## MVP
- Native Swift + SwiftUI shell and first-party SpriteKit course view, iPhone-only portrait.
- Three handcrafted compact courses, deterministic marble/collision model and fixed update step, touch steering plus opt-in Core Motion tilt with calibration and sensitivity control.
- Explicit checkpoints, pause/retry, local personal times and accessible menus. Import/export JSON and delete local records.
- `TiltWorkspaceLayout` seam for field and controls. Today both share one iPhone screen; iPhone Duo design target uses one screen for uninterrupted course view and second for tilt calibration, checkpoint map, time and restart controls. Public dual-screen API migration waits for Apple SDK support; no speculative fold APIs.

## Non-goals
No Android, native iPad support, Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity, cloud sync, accounts, ads, IAP, live multiplayer, ray-tracing promise, third-party game engine or copied marble game levels. Native iPad support is disabled; future iPad support needs explicit user opt-in. iPhone compatibility mode on iPad is not native iPad support.

## Privacy, permissions and accessibility
Personal best times and tilt on/off and sensitivity preferences are saved as versioned JSON in app-local storage after changes. Neutral calibration and unfinished runs reset on relaunch. Local data sheet exports JSON through Files, validates imports before asking permission to overwrite, and deletes all saved data after confirmation; malformed or future-version saves are never silently replaced. App has no cloud backup code, network calls (`network_allowlist: []`), trackers, login, analytics, or notification permission. Core Motion sampling starts only after opt-in while playing on screen and stops on pause, finish, exit, or toggle off; touch always works, including when motion is unavailable. `NSMotionUsageDescription` explains optional sensor use if iOS prompts. VoiceOver hints, scrollable large-text controls, and touch targets are checked in #5; gesture-only course steering still needs physical-device VoiceOver playtesting. No health claims.

## Platform / status
Playable touch loop: three SpriteKit courses with drag steering, pause/retry/checkpoint restart, elapsed clock and persistent personal bests; XCUITest completes a course through real touch events. Opt-in Core Motion tilt (off by default, sampled only while a run is live and on screen, neutral-angle calibration, sensitivity slider, automatic touch fallback) is implemented; its mapper is unit-tested, but real-device tilt feel and sensitivity tuning are UNVERIFIED until measured on a physical iPhone. Versioned local JSON save plus export, confirmed import, and delete-all are implemented; their file round-trip and invalid-input tests pass. App icon is generated and wired into the asset catalog; publish Action is configured but not yet proven by TestFlight evidence. Xcode target, pure Swift layout seam and pinned CI added. Pin iOS 26 SDK or newer, Xcode 26.0.1 (17A400), Swift 6, deployment iOS 26.0. Native Swift/SwiftUI/UIKit/SpriteKit only. Every app config must set `TARGETED_DEVICE_FAMILY = 1`; Apple CI must confirm built `UIDeviceFamily = [1]`. `PRODUCT_BUNDLE_IDENTIFIER = com.infinityball.tilttrail` in all targets and signing; ASC registration: CREATED. `toolchain.json` pins planning contract; no Linux claim of Apple compilation. Tagged/manual TestFlight publication is wired through `release.yml`, but an Apple CI run and processed ASC build remain required before release-ready claims.

## Milestones
1. Xcode skeleton, pinned CI and `TiltWorkspaceLayout`.
2. Deterministic simulation, collision and course fixtures.
3. Touch-driven playable three-course loop and checkpoint/timer flow.
4. Optional calibrated tilt and accessibility polish.
5. JSON export/import/delete, App Store artwork and release evidence.

## App Store / release
`AppStore/description.txt` describes implemented features only; review it again before submission. `AppStore/icon.png` is 1024×1024 opaque RGB artwork generated by Hermes image-gen (`gpt-image-2-medium`) after inspecting repo and description; the same bytes are wired into Xcode's app-icon catalog. Visually inspect on a display before release; Linux file checks prove format and parity, not absence of visual defects. Publish issue must port proven `rwrife/cook-console` `.github/workflows/release.yml`: `v*` tag or manual dispatch on macos-26; iOS 26+ SDK enforcement, signed IPA archive/export, TestFlight upload via App Store Connect API, ASC processing poll, GitHub release. Secrets already set: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (names only; never log values). TestFlight upload ≠ App Store approval.

## Development quickstart
On macOS with Xcode 26.0.1 (17A400), run `swift test --package-path Packages/TiltTrailKit` then `xcodebuild -project TiltTrail.xcodeproj -scheme TiltTrail -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. `Scripts/ci.sh <sha>` runs the full pinned simulator gate (Xcode pin, exact runtime, package tests, build, family guard, boot, UI tests).

MIT license; see LICENSE. See PLAN.md for architecture and test gates.
