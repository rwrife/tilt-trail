import Foundation

/// Pure input mapper for motion and touch fallback.
/// Unit-tested on Linux without CoreMotion runtime.
public struct TiltInputMapper: Sendable, Equatable {
    /// Neutral gravity/acceleration baseline captured at calibration.
    public struct Calibration: Sendable, Equatable, Codable {
        public let pitch: Double
        public let roll: Double

        public init(pitch: Double, roll: Double) {
            self.pitch = pitch.isFinite ? pitch : 0
            self.roll = roll.isFinite ? roll : 0
        }

        public static let zero = Calibration(pitch: 0, roll: 0)
    }

    /// User tilt configuration. Off by default per issue #4 acceptance criteria.
    public struct Configuration: Sendable, Equatable, Codable {
        public var isMotionEnabled: Bool
        public var sensitivity: Double
        public var deadZone: Double
        public var calibration: Calibration

        public init(
            isMotionEnabled: Bool = false,
            sensitivity: Double = 1.0,
            deadZone: Double = 0.05,
            calibration: Calibration = .zero
        ) {
            self.isMotionEnabled = isMotionEnabled
            self.sensitivity = sensitivity.isFinite ? max(0.2, min(3.0, sensitivity)) : 1.0
            self.deadZone = deadZone.isFinite ? max(0.0, min(0.3, deadZone)) : 0.05
            self.calibration = calibration
        }

        public static let `default` = Configuration()
    }

    public let config: Configuration

    public init(config: Configuration = .default) {
        self.config = config
    }

    /// Map raw pitch and roll (radians or normalized gravity components) into a 2D steering vector.
    /// Pitch tilts forward/back (+pitch tilts phone top away -> forward/upward marble drive).
    /// Roll tilts right/left (+roll tilts right -> rightward marble drive).
    /// Applies neutral offset, dead-zone deadening, sensitivity scale, and disc clamp.
    public func mapTilt(pitch: Double, roll: Double) -> Point {
        guard config.isMotionEnabled else { return Point(0, 0) }
        guard pitch.isFinite, roll.isFinite else { return Point(0, 0) }

        let rawX = roll - config.calibration.roll
        let rawY = pitch - config.calibration.pitch

        let x = applyDeadZoneAndScale(rawX)
        let y = applyDeadZoneAndScale(rawY)

        let length = (x * x + y * y).squareRoot()
        guard length > 0 else { return Point(0, 0) }
        if length > 1.0 {
            return Point(x / length, y / length)
        }
        return Point(x, y)
    }

    /// Resolves steering priority: touch active -> touch wins; else motion if enabled & available; else zero.
    public func resolveSteering(
        touchInput: Point,
        touchActive: Bool = false,
        motionSample: (pitch: Double, roll: Double)?,
        isSensorAvailable: Bool
    ) -> Point {
        if touchActive || touchInput.x != 0 || touchInput.y != 0 {
            return touchInput
        }
        guard config.isMotionEnabled, isSensorAvailable, let sample = motionSample else {
            return Point(0, 0)
        }
        return mapTilt(pitch: sample.pitch, roll: sample.roll)
    }

    private func applyDeadZoneAndScale(_ delta: Double) -> Double {
        let mag = abs(delta)
        let dz = config.deadZone
        guard mag > dz else { return 0.0 }
        let sign = delta >= 0 ? 1.0 : -1.0
        // Rescale from deadzone threshold to 1.0 smoothly
        let normalized = (mag - dz) / max(0.0001, (1.0 - dz))
        return sign * normalized * config.sensitivity
    }
}
