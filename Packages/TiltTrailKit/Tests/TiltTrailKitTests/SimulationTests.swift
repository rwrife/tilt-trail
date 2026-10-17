import Testing
@testable import TiltTrailKit

private func fixture(_ start: Cell = Cell(1, 1), checkpoints: [Cell] = [Cell(2, 1)],
                     finish: Cell = Cell(3, 1), walls: Set<Cell> = [], pits: Set<Cell> = []) -> Course {
    Course(id: "test", width: 8, height: 7, start: start, checkpoints: checkpoints,
           finish: finish, walls: walls, pits: pits)!
}

@discardableResult
private func drive(_ simulation: inout MarbleSimulation, toward cell: Cell, limit: Int = 500) -> [Point] {
    let target = Point(Double(cell.x) + 0.5, Double(cell.y) + 0.5)
    var trace: [Point] = []
    for _ in 0..<limit {
        let dx = target.x - simulation.position.x
        let dy = target.y - simulation.position.y
        if dx * dx + dy * dy < 0.04 || simulation.finished { break }
        func quantize(_ input: Double) -> Double {
            Double(max(-8, min(8, Int((input * 8).rounded())))) / 8
        }
        let input = Point(quantize(2 * dx - 0.35 * simulation.velocity.x),
                          quantize(2 * dy - 0.35 * simulation.velocity.y))
        trace.append(input)
        simulation.step(steering: input)
    }
    return trace
}

@Test("original courses reachable by recorded waypoint input traces")
func courseReplay() {
    // Fixed waypoint fixtures plus quantized feedback produce a reproducible input trace.
    let routes: [[Cell]] = [
        [Cell(5, 1), Cell(5, 5), Cell(1, 5)],
        [Cell(1, 5), Cell(5, 5), Cell(5, 1)],
        [Cell(6, 1), Cell(6, 5), Cell(2, 5)]
    ]
    for (course, waypoints) in zip(TrailCourses.all, routes) {
        var first = MarbleSimulation(course: course)
        var trace: [Point] = []
        for point in waypoints { trace += drive(&first, toward: point) }
        // Replay the recorded input trace on a fresh simulation; results must be identical.
        var second = MarbleSimulation(course: course)
        for input in trace { second.step(steering: input) }
        #expect(first.finished, "Unreachable: \(course.id)")
        #expect(first.reached == course.checkpoints.count)
        #expect(first.falls == 0)
        #expect(first.ticks == second.ticks)
        #expect(first.position == second.position)
        #expect(first.elapsedSeconds == second.elapsedSeconds)
    }
}

@Test("wall slide preserves tangential movement without penetration")
func wallSlide() {
    var marble = MarbleSimulation(course: fixture(checkpoints: [Cell(2, 4)],
                                                 finish: Cell(3, 5), walls: [Cell(2, 2)]))
    for _ in 0..<150 { marble.step(steering: Point(1, 0.6)) }
    #expect(marble.position.x < 2.0 || marble.position.y >= 2.0)
    #expect(marble.position.y > 1.5)
}

@Test("fall restarts at last checkpoint, retaining elapsed time")
func pitRestart() {
    var marble = MarbleSimulation(course: fixture(checkpoints: [Cell(2, 1)],
                                                 finish: Cell(6, 1), pits: [Cell(3, 1)]))
    drive(&marble, toward: Cell(2, 1))
    #expect(marble.reached == 1)
    let before = marble.ticks
    drive(&marble, toward: Cell(3, 1), limit: 120)
    #expect(marble.falls > 0)
    #expect(marble.position.x >= 2.5)
    #expect(marble.ticks > before)
    #expect(marble.reached == 1)
}

@Test("checkpoint ordering gates finish; no early win")
func orderedCheckpoints() {
    var marble = MarbleSimulation(course: fixture(checkpoints: [Cell(2, 1), Cell(1, 2)],
                                                 finish: Cell(3, 1)))
    drive(&marble, toward: Cell(3, 1))
    #expect(marble.reached == 1)
    #expect(!marble.finished)
    drive(&marble, toward: Cell(1, 2))
    #expect(marble.reached == 2)
    drive(&marble, toward: Cell(3, 1))
    #expect(marble.finished)
    let ticks = marble.ticks
    marble.step(steering: Point(1, 1))
    #expect(marble.ticks == ticks)
}

@Test("fixed step accumulates chunks; bad frames do not advance")
func stepBounds() {
    let course = fixture()
    var whole = MarbleSimulation(course: course)
    var halves = MarbleSimulation(course: course)
    for _ in 0..<24 {
        whole.advance(seconds: 1.0 / 60, steering: Point(1, 0))
        halves.advance(seconds: 1.0 / 120, steering: Point(1, 0))
        halves.advance(seconds: 1.0 / 120, steering: Point(1, 0))
    }
    #expect(whole.ticks == halves.ticks)
    #expect(whole.position == halves.position)
    let before = whole.ticks
    for seconds in [Double.nan, .infinity, -1, 0.251] {
        whole.advance(seconds: seconds, steering: Point(1, 0))
    }
    #expect(whole.ticks == before)
    whole.step(steering: Point(.nan, .infinity))
    #expect(whole.position.x.isFinite && whole.position.y.isFinite)
    #expect(Course(id: "bad", width: 0, height: 5, start: Cell(0, 0),
                   checkpoints: [Cell(1, 1)], finish: Cell(2, 2), walls: [], pits: []) == nil)
}
