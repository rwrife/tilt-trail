import Testing
@testable import TiltTrailKit

private func steer(_ game: inout PlaySession, to target: Cell) {
    for _ in 0..<500 {
        let dx = Double(target.x) + 0.5 - game.simulation.position.x
        let dy = Double(target.y) + 0.5 - game.simulation.position.y
        if dx * dx + dy * dy < 0.04 || game.isFinished { break }
        let input = Point(Double(max(-8, min(8, Int(((2 * dx - 0.35 * game.simulation.velocity.x) * 8).rounded())))) / 8,
                          Double(max(-8, min(8, Int(((2 * dy - 0.35 * game.simulation.velocity.y) * 8).rounded())))) / 8)
        game.update(seconds: 1.0 / 60, steering: input)
    }
}

@Test("drag input is finite and clamped")
func dragVector() {
    #expect(DragSteering.vector(dx: 0, dy: 0) == Point(0, 0))
    #expect(DragSteering.vector(dx: .nan, dy: 1) == Point(0, 0))
    #expect(DragSteering.vector(dx: 30, dy: 0).x == 0.5)
    let long = DragSteering.vector(dx: 1000, dy: -1000)
    #expect(abs(long.x * long.x + long.y * long.y - 1) < 0.00001)
    #expect(DragSteering.vector(dx: 1, dy: 1, travel: 0) == Point(0, 0))
}

@Test("clock truncates to tenths")
func clock() {
    #expect(ClockFormat.string(0) == "0:00.0")
    #expect(ClockFormat.string(61.99) == "1:01.9")
    #expect(ClockFormat.string(9.05) == "0:09.0")
    #expect(ClockFormat.string(-1) == "0:00.0")
    #expect(ClockFormat.string(.nan) == "0:00.0")
}

@Test("pause freezes clock, retry clears pause and preserves best")
func pauseAndRetry() {
    var game = PlaySession(course: TrailCourses.all[0], bests: ["Switchback": 12.5, "bogus": -1])
    for _ in 0..<30 { game.update(seconds: 1.0 / 60, steering: Point(1, 0)) }
    let before = game.simulation.elapsedSeconds
    game.pause()
    for _ in 0..<60 { game.update(seconds: 1.0 / 60, steering: Point(1, 0)) }
    #expect(game.simulation.elapsedSeconds == before)
    game.resume()
    game.update(seconds: 1.0 / 60, steering: Point(1, 0))
    #expect(game.simulation.elapsedSeconds > before)
    game.retry()
    #expect(game.simulation.ticks == 0)
    #expect(!game.isPaused)
    #expect(game.best == 12.5)
    #expect(game.bests["bogus"] == nil)
}

@Test("all three courses finish; only faster times replace personal bests")
func personalBests() {
    let routes: [[Cell]] = [
        [Cell(5, 1), Cell(5, 5), Cell(1, 5)],
        [Cell(1, 5), Cell(5, 5), Cell(5, 1)],
        [Cell(6, 1), Cell(6, 5), Cell(2, 5)]
    ]
    for (course, route) in zip(TrailCourses.all, routes) {
        var game = PlaySession(course: course)
        for point in route { steer(&game, to: point) }
        #expect(game.isFinished, "\(course.id)")
        #expect(game.newBest)
        let first = game.best!
        #expect(first == game.simulation.elapsedSeconds)
        game.retry()
        #expect(!game.newBest)
        for point in route { steer(&game, to: point) }
        #expect(game.isFinished)
        #expect(!game.newBest)
        #expect(game.best == first)
        var previousBest = PlaySession(course: course, bests: [course.id: first / 2])
        for point in route { steer(&previousBest, to: point) }
        #expect(previousBest.isFinished)
        #expect(!previousBest.newBest)
        #expect(previousBest.best == first / 2)
    }
}

@Test("checkpoint restart keeps elapsed time and pause state")
func checkpointRestartKeepsClock() {
    var game = PlaySession(course: TrailCourses.all[0])
    steer(&game, to: Cell(5, 1))
    #expect(game.simulation.reached == 1)
    game.update(seconds: 1.0 / 60, steering: Point(0, 1))
    let before = game.simulation.elapsedSeconds
    game.pause()
    game.restartFromCheckpoint()
    #expect(game.simulation.position == Point(5.5, 1.5))
    #expect(game.simulation.elapsedSeconds == before)
    #expect(game.isPaused)
}
