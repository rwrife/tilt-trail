/// Drag-to-steer mapping shared by the SpriteKit scene and tests.
public enum DragSteering {
    /// Finger travel (scene units) that yields full steering.
    public static let fullTravel = 60.0

    /// `dx` is rightward and `dy` is upward (course orientation, not UIKit's y-down).
    /// Non-finite input steers nowhere; the result is clamped to the unit disc.
    public static func vector(dx: Double, dy: Double, travel: Double = fullTravel) -> Point {
        guard dx.isFinite, dy.isFinite, travel.isFinite, travel > 0 else { return Point(0, 0) }
        let x = dx / travel
        let y = dy / travel
        let length = (x * x + y * y).squareRoot()
        return length > 1 ? Point(x / length, y / length) : Point(x, y)
    }
}

public enum ClockFormat {
    /// `m:ss.t`, truncated to tenths so the label never runs ahead of the clock.
    public static func string(_ seconds: Double) -> String {
        let tenths = seconds.isFinite && seconds > 0 ? Int(min(seconds, 5999.9) * 10) : 0
        let secs = tenths / 10
        return "\(secs / 60):\(secs % 60 < 10 ? "0" : "")\(secs % 60).\(tenths % 10)"
    }
}

/// One play-through of a course: pause, retry, checkpoint restart and in-memory personal bests.
/// Persistence of `bests` belongs to issue #6.
public struct PlaySession: Sendable {
    public let course: Course
    public private(set) var simulation: MarbleSimulation
    public private(set) var isPaused = false
    public private(set) var newBest = false
    /// Best finish time in seconds per course id.
    public private(set) var bests: [String: Double]
    private var recorded = false

    public var isFinished: Bool { simulation.finished }
    public var best: Double? { bests[course.id] }

    public init(course: Course, bests: [String: Double] = [:]) {
        self.course = course
        self.bests = bests.filter { $0.value.isFinite && $0.value > 0 }
        simulation = MarbleSimulation(course: course)
    }

    /// Advances by a wall-clock frame. No-op while paused or finished.
    /// ponytail: a frame longer than 0.25 s is clamped, so a stall costs at most 0.25 s of play time.
    public mutating func update(seconds: Double, steering: Point) {
        guard !isPaused, !simulation.finished, seconds.isFinite, seconds >= 0 else { return }
        simulation.advance(seconds: min(seconds, 0.25), steering: steering)
        if simulation.finished, !recorded {
            recorded = true
            let time = simulation.elapsedSeconds
            if best.map({ time < $0 }) ?? true {
                bests[course.id] = time
                newBest = true
            }
        }
    }

    public mutating func pause() { isPaused = true }
    public mutating func resume() { isPaused = false }

    /// Fresh run; personal bests are kept.
    public mutating func retry() {
        simulation = MarbleSimulation(course: course)
        isPaused = false
        newBest = false
        recorded = false
    }

    /// Returns to the last checkpoint; the clock keeps running.
    public mutating func restartFromCheckpoint() {
        simulation.restartAtCheckpoint()
    }
}
