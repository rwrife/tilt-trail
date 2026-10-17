/// Grid cells use lower-left origins; marble coordinates use cell centers.
public struct Cell: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Course: Sendable {
    public let id: String
    public let width: Int
    public let height: Int
    public let start: Cell
    public let checkpoints: [Cell]
    public let finish: Cell
    public let walls: Set<Cell>
    public let pits: Set<Cell>

    public init?(id: String, width: Int, height: Int, start: Cell,
                 checkpoints: [Cell], finish: Cell, walls: Set<Cell>, pits: Set<Cell>) {
        guard !id.isEmpty, (2...64).contains(width), (2...64).contains(height),
              !checkpoints.isEmpty, Set(checkpoints).count == checkpoints.count else { return nil }
        let targets = [start, finish] + checkpoints
        guard targets.count == Set(targets).count,
              (targets + Array(walls) + Array(pits)).allSatisfy({
                  (0..<width).contains($0.x) && (0..<height).contains($0.y)
              }), walls.isDisjoint(with: pits),
              targets.allSatisfy({ !walls.contains($0) && !pits.contains($0) }) else { return nil }
        self.id = id
        self.width = width
        self.height = height
        self.start = start
        self.checkpoints = checkpoints
        self.finish = finish
        self.walls = walls
        self.pits = pits
    }
}

public enum TrailCourses {
    // Original small mazes. All targets have a clear, test-replayed route.
    public static let all: [Course] = [
        Course(id: "Switchback", width: 8, height: 7, start: Cell(1, 1),
               checkpoints: [Cell(5, 1), Cell(5, 5)], finish: Cell(1, 5),
               walls: [Cell(3, 2), Cell(3, 3), Cell(3, 4)],
               pits: [Cell(2, 3), Cell(6, 3)])!,
        Course(id: "Sundial", width: 8, height: 7, start: Cell(1, 1),
               checkpoints: [Cell(1, 5), Cell(5, 5)], finish: Cell(5, 1),
               walls: [Cell(3, 1), Cell(3, 2), Cell(3, 3)],
               pits: [Cell(2, 3), Cell(6, 3)])!,
        Course(id: "Three Bends", width: 9, height: 7, start: Cell(1, 1),
               checkpoints: [Cell(6, 1), Cell(6, 5)], finish: Cell(2, 5),
               walls: [Cell(3, 2), Cell(4, 2), Cell(4, 3), Cell(4, 4)],
               pits: [Cell(1, 3), Cell(7, 3)])!
    ]
}

public struct MarbleSimulation: Sendable {
    public static let stepSeconds = 1.0 / 60.0
    public let course: Course
    public private(set) var position: Point
    public private(set) var velocity = Point(0, 0)
    /// Count of checkpoints crossed in order; later checkpoints cannot be skipped.
    public private(set) var reached = 0
    public private(set) var falls = 0
    public private(set) var ticks = 0
    public private(set) var finished = false
    private var remainder = 0.0
    public var elapsedSeconds: Double { Double(ticks) * Self.stepSeconds }

    public init(course: Course) {
        self.course = course
        position = Self.center(course.start)
    }

    public mutating func step(steering: Point) {
        guard !finished else { return }
        ticks += 1
        let x = steering.x.isFinite ? max(-1, min(1, steering.x)) : 0
        let y = steering.y.isFinite ? max(-1, min(1, steering.y)) : 0
        let scale = max(1, (x * x + y * y).squareRoot())
        velocity.x = (velocity.x + 18 * x / scale * Self.stepSeconds) * 0.88
        velocity.y = (velocity.y + 18 * y / scale * Self.stepSeconds) * 0.88
        let nextX = position.x + velocity.x * Self.stepSeconds
        if blocked(x: nextX, y: position.y) { velocity.x = 0 }
        else { position.x = nextX }
        let nextY = position.y + velocity.y * Self.stepSeconds
        if blocked(x: position.x, y: nextY) { velocity.y = 0 }
        else { position.y = nextY }

        let cell = Cell(Int(position.x.rounded(.down)), Int(position.y.rounded(.down)))
        if course.pits.contains(cell) {
            falls += 1
            position = Self.center(reached == 0 ? course.start : course.checkpoints[reached - 1])
            velocity = Point(0, 0)
            return
        }
        if reached < course.checkpoints.count,
           close(to: course.checkpoints[reached], radius: 0.30) { reached += 1 }
        if reached == course.checkpoints.count, close(to: course.finish, radius: 0.30) {
            finished = true
            velocity = Point(0, 0)
        }
    }

    /// Accumulates wall-clock frames into fixed steps; reject bad/oversized frames.
    /// ponytail: cap stalls at 0.25 s; upgrade to a pause-aware clock if background time must count.
    public mutating func advance(seconds: Double, steering: Point) {
        guard seconds.isFinite, seconds >= 0, seconds <= 0.25, !finished else { return }
        remainder += seconds
        while remainder + 1e-10 >= Self.stepSeconds {
            step(steering: steering)
            remainder -= Self.stepSeconds
            if finished { remainder = 0; break }
        }
    }

    private static func center(_ cell: Cell) -> Point {
        Point(Double(cell.x) + 0.5, Double(cell.y) + 0.5)
    }

    private func close(to cell: Cell, radius: Double) -> Bool {
        let dx = position.x - Double(cell.x) - 0.5
        let dy = position.y - Double(cell.y) - 0.5
        return dx * dx + dy * dy <= radius * radius
    }

    private func blocked(x: Double, y: Double) -> Bool {
        let radius = 0.22
        if x < radius || y < radius || x > Double(course.width) - radius || y > Double(course.height) - radius { return true }
        return course.walls.contains { wall in
            let dx = max(Double(wall.x) - x, 0, x - Double(wall.x + 1))
            let dy = max(Double(wall.y) - y, 0, y - Double(wall.y + 1))
            return dx * dx + dy * dy < radius * radius
        }
    }
}
