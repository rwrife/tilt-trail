# Tilt Trail — build plan

## Scope and architecture
Native Swift, SwiftUI menus and first-party SpriteKit gameplay; deterministic fixed-step marble physics and handcrafted course definitions in a pure Swift domain module. `TiltWorkspaceLayout` controls course viewport and persistent control strip geometry, isolating future dual-display placement from physics. Current build is standard portrait iPhone; future iPhone Duo public SDK migration places course on one display and checkpoint map, timer, calibration/retry on the other while preserving state across folding. No imaginary fold SDK dependency.

Platform contract: iOS 26 SDK or newer, Xcode 26.0.1 (17A400), Swift 6, deployment iOS 26.0; `PRODUCT_BUNDLE_IDENTIFIER = com.infinityball.tilttrail` in every target/config. `TARGETED_DEVICE_FAMILY = 1` in every app config and generator; built `UIDeviceFamily = [1]` proven on Apple CI. Native iPad support is disabled; only explicit opt-in enables it. Android and iPad release work out of scope. No Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity, or other hybrid engine.

Data model: course ID and definition version, checkpoint reached, best elapsed milliseconds, control mode, neutral tilt calibration and sensitivity. Versioned JSON in app container with atomic writes; import validates schema and course IDs, requires overwrite consent and retains old data on error. Export user-owned JSON via file exporter; delete all. Network allowlist empty; no account, analytics, ads or notifications. Motion only while active, enabled by user with fallback touch steering. Course geometry and collision fixtures carry no copyrighted levels/assets.

## Milestones and dependency order
1. Xcode project + SwiftPM domain, pinned macos-26 CI and `TiltWorkspaceLayout` seam. Source device-family gate and actual built Info.plist assertion.
2. Pure Swift fixed-step simulation: steering, walls, pits, checkpoint and finish; three fixture courses and deterministic replay tests.
3. DONE (this slice): SpriteKit course + SwiftUI controls; touch play, pause/retry/checkpoint, visible clock and in-memory personal best (save lands in #6).
4. Opt-in Core Motion calibration/sensitivity; graceful permission/sensor failure fallback to touch. VoiceOver labels, 44pt controls, contrast, reduced motion, Dynamic Type menus.
5. JSON export/import/delete, storage tests. Review `AppStore/description.txt` against implementation; generate real `AppStore/icon.png` with `hermes-image-gen`, wire same art into Xcode catalog. No placeholder.
6. Pinned native build/UI tests, release Action and actual TestFlight evidence.

## Testing
Pure Swift unit tests for repeatable simulation, fixed-step invariance bounds, course reachability fixtures, checkpoint retry timing, invalid input and replay determinism. Persistence tests cover corrupt/unknown-version import without data loss, export roundtrip, delete. XCUITest covers first launch, touch course complete, opt-in tilt fallback, accessibility and resume. CI on macos-26 uses pinned Xcode and iOS 26+ SDK; confirms app `UIDeviceFamily == [1]` and `PRODUCT_BUNDLE_IDENTIFIER = com.infinityball.tilttrail`. Linux parse/config checks are not iOS builds. Real-device tilt tuning and frame rate remain unverified until measured on device. No iPad screenshots or iPad tests.

## Packaging / distribution
`AppStore/description.txt` starts as truthful planned-feature copy; change tense only after app works. Real square opaque icon `AppStore/icon.png` from `hermes-image-gen` after analysis, edge-to-edge colorful labyrinth imagery without text, borders, transparency or corner radius; inspect and wire into asset catalog. Model missing means issue stays open.

Port `rwrife/cook-console` `.github/workflows/release.yml`, not a new signing flow: `v*` tag or manual dispatch, macos-26, enforce iOS 26+ SDK, mode-600 API key, signed IPA archive/export for `com.infinityball.tilttrail`, TestFlight upload via App Store Connect API, wait for ASC processing and publish GitHub release. Use `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` secrets by name only; never log values. Review signing and actual ASC evidence before declaring publish success.

## Risks and explicit non-goals
Physics fairness requires repeatable tests and real playtest; Core Motion calibration varies by device orientation and must fail safely to touch. Apple dual-screen APIs unavailable: future split layout only after public support. No copied Marble Madness levels/art/names, Android, iPad, Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity, online rankings, cloud sync, paywall, third-party game engine, ray-tracing requirement or claimed Apple archive from Linux.
