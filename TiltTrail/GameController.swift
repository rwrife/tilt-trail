import Foundation
import Observation
import SpriteKit
import TiltTrailKit

/// Owns the current play-through and the in-memory personal bests (persistence: issue #6).
@MainActor
@Observable
final class GameController {
    private(set) var session: PlaySession
    private(set) var scene: CourseScene

    init(course: Course) {
        session = PlaySession(course: course)
        scene = CourseScene(course: course)
        scene.game = self
    }

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

    func advance(seconds: Double, steering: Point) { session.update(seconds: seconds, steering: steering) }

    func togglePause() {
        guard !session.isFinished else { return }
        session.isPaused ? session.resume() : session.pause()
    }

    func retry() {
        let bests = session.bests
        session = PlaySession(course: course, bests: bests)
        scene = CourseScene(course: course)
        scene.game = self
    }

    func restartFromCheckpoint() {
        session.restartFromCheckpoint()
        session.resume()
        scene.clearTouch()
    }

    func select(course newCourse: Course) {
        // Same course with a run in progress: restart it; fresh idle selection is a no-op.
        guard newCourse.id != course.id || session.simulation.ticks > 0 || session.isFinished else { return }
        let bests = session.bests
        session = PlaySession(course: newCourse, bests: bests)
        scene = CourseScene(course: newCourse)
        scene.game = self
    }
}
