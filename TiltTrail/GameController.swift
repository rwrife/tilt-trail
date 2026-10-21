import Foundation
import Observation
import SpriteKit
import CoreMotion
import TiltTrailKit

/// Owns the current play-through and optional device-motion sampling.
@MainActor
@Observable
final class GameController {
    private(set) var session: PlaySession
    private(set) var scene: CourseScene
    private(set) var motionConfig = TiltInputMapper.Configuration.default
    private(set) var isCalibrationReady = false
    private let motion = CMMotionManager()
    private let store: LocalSaveStore
    private var isOnScreen = false
    private(set) var storageError: String?

    init(course: Course, store: LocalSaveStore = LocalSaveStore(
        url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TiltTrail/save.json"))) {
        self.store = store
        let saved: LocalSave
        do { saved = try store.load() }
        catch {
            saved = LocalSave()
            storageError = "Could not read local save: \(error.localizedDescription). Existing file was not changed."
        }
        session = PlaySession(course: course, bests: saved.bests)
        motionConfig = .init(isMotionEnabled: saved.motionEnabled, sensitivity: saved.sensitivity)
        scene = CourseScene(course: course)
        scene.game = self
    }

    var exportData: Data? {
        guard storageError == nil else { return nil }
        return try? snapshot.encoded()
    }

    private var snapshot: LocalSave {
        LocalSave(bests: session.bests, motionEnabled: motionConfig.isMotionEnabled,
                  sensitivity: motionConfig.sensitivity)
    }

    private func persist() {
        // Never overwrite unreadable or future-version data implicitly.
        guard storageError == nil else { return }
        do { try store.write(snapshot) }
        catch { storageError = "Could not save changes: \(error.localizedDescription)" }
    }

    func importSave(_ data: Data) throws {
        let imported = try LocalSave.decode(data)
        try store.write(imported)
        session = PlaySession(course: course, bests: imported.bests)
        scene = CourseScene(course: course)
        scene.game = self
        motionConfig = .init(isMotionEnabled: imported.motionEnabled, sensitivity: imported.sensitivity)
        isCalibrationReady = false
        storageError = nil
        updateMotionSampling()
    }

    func deleteAll() throws {
        try store.delete()
        session = PlaySession(course: course)
        scene = CourseScene(course: course)
        scene.game = self
        motionConfig = .default
        isCalibrationReady = false
        storageError = nil
        updateMotionSampling()
    }

    var isSensorAvailable: Bool { motion.isDeviceMotionAvailable }
    var motionStatus: String {
        if !isSensorAvailable { return "Tilt unavailable. Touch steering remains active." }
        if !motionConfig.isMotionEnabled { return "Touch steering. Tilt is off." }
        if !isCalibrationReady { return "Tilt enabled. Calibrate your neutral angle below; touch still works." }
        return "Tilt enabled. Drag anywhere to override tilt."
    }

    func appear() {
        isOnScreen = true
        updateMotionSampling()
    }

    func disappear() {
        isOnScreen = false
        updateMotionSampling()
    }

    func setMotionEnabled(_ enabled: Bool) {
        motionConfig.isMotionEnabled = enabled && isSensorAvailable
        if !motionConfig.isMotionEnabled { isCalibrationReady = false }
        persist()
        updateMotionSampling()
    }

    func setSensitivity(_ value: Double) {
        motionConfig.sensitivity = TiltInputMapper.Configuration(sensitivity: value).sensitivity
        persist()
    }

    func calibrate() {
        guard motionConfig.isMotionEnabled, !isPaused, !isFinished,
              let attitude = motion.deviceMotion?.attitude else { return }
        motionConfig.calibration = .init(pitch: attitude.pitch, roll: attitude.roll)
        isCalibrationReady = true
    }

    func steering(touch: Point, touchActive: Bool) -> Point {
        // No state mutation here: this runs every rendered frame.
        guard motionConfig.isMotionEnabled, isOnScreen, !isPaused, !isFinished,
              let attitude = motion.deviceMotion?.attitude else { return touch }
        return TiltInputMapper(config: motionConfig).resolveSteering(
            touchInput: touch,
            touchActive: touchActive,
            motionSample: (pitch: attitude.pitch, roll: attitude.roll),
            isSensorAvailable: isSensorAvailable)
    }

    private func updateMotionSampling() {
        let shouldRun = isOnScreen && motionConfig.isMotionEnabled && isSensorAvailable && !isPaused && !isFinished
        if shouldRun && !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates()
        } else if !shouldRun && motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }

    // ponytail: calibration resets on relaunch; recalibrate for the current device posture.

    var course: Course { session.course }
    var simulation: MarbleSimulation { session.simulation }
    var isPaused: Bool { session.isPaused && !session.isFinished }
    var isFinished: Bool { session.isFinished }
    var clock: String { ClockFormat.string(session.simulation.elapsedSeconds) }
    var bestText: String {
        session.best.map { "Best \(ClockFormat.string($0))" } ?? "Best --:--"
    }
    var checkpointText: String {
        "Checkpoint \(session.simulation.reached) of \(course.checkpoints.count)"
    }
    var statusText: String {
        if session.isFinished {
            return session.newBest ? "Course complete. New personal best!" : "Course complete."
        }
        return isPaused ? "Paused" : clock
    }
    /// Live telemetry the UI test steers from; UIKit is not imported in TiltTrailKit.
    var marbleAccessibilityValue: String {
        let sim = session.simulation
        return String(format: "x %.2f y %.2f vx %.2f vy %.2f",
                      sim.position.x, sim.position.y, sim.velocity.x, sim.velocity.y)
    }

    func advance(seconds: Double, steering: Point) {
        let wasFinished = session.isFinished
        session.update(seconds: seconds, steering: steering)
        if !wasFinished && session.isFinished {
            persist()
            updateMotionSampling()
        }
    }

    func togglePause() {
        guard !session.isFinished else { return }
        session.isPaused ? session.resume() : session.pause()
        updateMotionSampling()
    }

    func retry() {
        let bests = session.bests
        session = PlaySession(course: course, bests: bests)
        scene = CourseScene(course: course)
        scene.game = self
        updateMotionSampling()
    }

    func restartFromCheckpoint() {
        session.restartFromCheckpoint()
        session.resume()
        scene.clearTouch()
        updateMotionSampling()
    }

    func select(course newCourse: Course) {
        // Same course with a run in progress: restart it; fresh idle selection is a no-op.
        guard newCourse.id != course.id || session.simulation.ticks > 0 || session.isFinished else { return }
        let bests = session.bests
        session = PlaySession(course: newCourse, bests: bests)
        scene = CourseScene(course: newCourse)
        scene.game = self
        updateMotionSampling()
    }
}
