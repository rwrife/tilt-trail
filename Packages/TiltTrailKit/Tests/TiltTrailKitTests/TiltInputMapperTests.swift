import Testing
@testable import TiltTrailKit

@Test("tilt stays zero until the user enables motion")
func motionOffByDefault() {
    #expect(TiltInputMapper.Configuration.default.isMotionEnabled == false)
    let mapper = TiltInputMapper()
    #expect(mapper.mapTilt(pitch: 0.7, roll: -0.7) == Point(0, 0))
    #expect(mapper.resolveSteering(touchInput: Point(0, 0),
                                   motionSample: (0.7, -0.7),
                                   isSensorAvailable: true) == Point(0, 0))
}

@Test("calibration offset recenters neutral and dead zone suppresses micro-slope")
func calibrationAndDeadZone() {
    var config = TiltInputMapper.Configuration(isMotionEnabled: true, sensitivity: 1.0, deadZone: 0.05)
    config.calibration = TiltInputMapper.Calibration(pitch: 0.2, roll: -0.1)
    let mapper = TiltInputMapper(config: config)

    // Holding the device at the calibrated neutral angle steers nowhere.
    #expect(mapper.mapTilt(pitch: 0.2, roll: -0.1) == Point(0, 0))
    // Inside the dead zone (|delta| <= 0.05) still steers nowhere.
    #expect(mapper.mapTilt(pitch: 0.24, roll: -0.13) == Point(0, 0))
    // Just outside the dead zone: (0.06 - 0.05) / (1 - 0.05) = 1/95.
    let slight = mapper.mapTilt(pitch: 0.26, roll: -0.1)
    #expect(abs(slight.y - 1.0 / 95.0) < 0.0001)
    #expect(slight.x == 0)
}

@Test("steering clamps to the unit disc and non-finite input steers nowhere")
func clamping() {
    var config = TiltInputMapper.Configuration(isMotionEnabled: true, sensitivity: 3.0, deadZone: 0.0)
    config.calibration = .zero
    let mapper = TiltInputMapper(config: config)

    let extreme = mapper.mapTilt(pitch: 2.0, roll: 2.0)
    #expect(abs(extreme.x * extreme.x + extreme.y * extreme.y - 1.0) < 0.00001)
    #expect(mapper.mapTilt(pitch: .nan, roll: 0.1) == Point(0, 0))
    #expect(mapper.mapTilt(pitch: 0.1, roll: .infinity) == Point(0, 0))

    let axis = mapper.mapTilt(pitch: 1.0, roll: 0.0)
    #expect(axis.x == 0)
    #expect(axis.y == 1.0) // sensitivity 3 clamps to exactly 1, never overshoots
}

@Test("touch overrides tilt and unavailable sensor falls back to touch only")
func priorityAndFallback() {
    let mapper = TiltInputMapper(config: .init(isMotionEnabled: true, sensitivity: 1.0, deadZone: 0.0))

    // Active touch wins even when a motion sample exists.
    #expect(mapper.resolveSteering(touchInput: Point(0.5, -0.5),
                                   motionSample: (1, 1),
                                   isSensorAvailable: true) == Point(0.5, -0.5))
    // No touch and no sensor: motion contributes nothing (touch fallback posture).
    #expect(mapper.resolveSteering(touchInput: Point(0, 0),
                                   motionSample: (0.5, 0.5),
                                   isSensorAvailable: false) == Point(0, 0))
    // No touch and no sample yet (motion not started): still safe zero.
    #expect(mapper.resolveSteering(touchInput: Point(0, 0),
                                   motionSample: nil,
                                   isSensorAvailable: true) == Point(0, 0))
    // Only touch-free + available sensor + fresh sample drives the marble.
    let driven = mapper.resolveSteering(touchInput: Point(0, 0),
                                        motionSample: (0.5, 0.0),
                                        isSensorAvailable: true)
    #expect(driven.y == 0.5)
    #expect(driven.x == 0)

    // A finger held still (zero drag vector) still owns the marble; tilt must not fight it.
    #expect(mapper.resolveSteering(touchInput: Point(0, 0),
                                   touchActive: true,
                                   motionSample: (1, 1),
                                   isSensorAvailable: true) == Point(0, 0))
}

@Test("sensitivity and dead zone settings clamp out-of-range user values")
func settingsClamp() {
    let wild = TiltInputMapper.Configuration(isMotionEnabled: true, sensitivity: 99, deadZone: -5)
    #expect(wild.sensitivity == 3.0)
    #expect(wild.deadZone == 0.0)
    let broken = TiltInputMapper.Configuration(isMotionEnabled: true,
                                               sensitivity: .nan,
                                               deadZone: .nan,
                                               calibration: .init(pitch: .nan, roll: .nan))
    #expect(broken.sensitivity == 1.0)
    #expect(broken.deadZone == 0.05)
    #expect(broken.calibration == .zero)
}
