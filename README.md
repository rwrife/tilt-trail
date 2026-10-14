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
Course state, control preference and times live in app container; no network calls (`network_allowlist: []`), trackers, login or analytics. JSON export/import through file picker with validation and overwrite confirmation; delete-all offered. Core Motion access is opt-in only while playing and requires device motion usage text if platform prompts; touch input always works. No notification permission. VoiceOver-labelled course selection, checkpoint/retry controls, Dynamic Type menus, large touch targets, contrast and reduce-motion support; gameplay offers touch alternative. No health claims.

## Platform / status
Documentation-only scaffold; game, icon, Xcode target, CI and publish Action not built. Pin iOS 26 SDK or newer, Xcode 26.0.1 (17A400), Swift 6, deployment iOS 26.0. Native Swift/SwiftUI/UIKit/SpriteKit only. Every app config must set `TARGETED_DEVICE_FAMILY = 1`; Apple CI must confirm built `UIDeviceFamily = [1]`. `PRODUCT_BUNDLE_IDENTIFIER = com.infinityball.tilttrail` in all targets and signing; ASC registration: CREATED. `toolchain.json` pins planning contract; no Linux claim of Apple compilation.

## Milestones
1. Xcode skeleton, pinned CI and `TiltWorkspaceLayout`.
2. Deterministic simulation, collision and course fixtures.
3. Touch-driven playable three-course loop and checkpoint/timer flow.
4. Optional calibrated tilt and accessibility polish.
5. JSON export/import/delete, App Store artwork and release evidence.

## App Store / release
`AppStore/description.txt` contains planned-feature copy; review against real features before submission. Real `AppStore/icon.png` must be generated with `hermes-image-gen` after inspecting repo and description, saved square, opaque, edge-to-edge, without text, border or baked corner radius, and wired into Xcode app-icon catalog. No placeholder. Publish issue must port proven `rwrife/cook-console` `.github/workflows/release.yml`: `v*` tag or manual dispatch on macos-26; iOS 26+ SDK enforcement, signed IPA archive/export, TestFlight upload via App Store Connect API, ASC processing poll, GitHub release. Secrets already set: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (names only; never log values). TestFlight upload ≠ App Store approval.

## Development quickstart
On macOS with Xcode 26.0.1 (17A400), after issue #1 creates Xcode project, run `xcodebuild -project TiltTrail.xcodeproj -scheme TiltTrail -destination 'generic/platform=iOS Simulator' build`. No runnable app exists at scaffold stage.

MIT license; see LICENSE. See PLAN.md for architecture and test gates.
