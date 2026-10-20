import XCTest

/// Real touch journey through Switchback. Steers from live viewport telemetry, exactly like a
/// player: XCUICoordinate nudges are the only input; nothing teleports the marble.
final class CourseJourneyTests: XCTestCase {
    func testMotionDefaultsOffAndTouchRemainsAvailable() {
        let app = XCUIApplication()
        app.launch()
        let settings = app.buttons["motion.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        XCTAssertEqual(settings.value as? String, "Off")
        settings.tap()
        let toggle = app.switches["motion.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Motion stays off until enabled. Touch steering always works and takes priority while dragging."].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.otherElements["course.viewport"].exists)
    }

    func testTouchCompletesOriginalCourse() throws {
        let app = XCUIApplication()
        app.launch()
        let viewport = app.otherElements["course.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 15))
        let checkpoints = app.staticTexts["game.checkpoints"]
        let status = app.staticTexts["game.status"]
        let best = app.staticTexts["game.best"]
        XCTAssertEqual(checkpoints.label, "Checkpoint 0 of 2")
        XCTAssertTrue(best.label.hasPrefix("Best --"), best.label)

        let pause = app.buttons["game.pause"]
        pause.tap()
        XCTAssertEqual(status.label, "Paused")
        pause.tap()

        let scale = min(viewport.frame.width / 8, viewport.frame.height / 7)
        let center = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Original Switchback route; each entry is a cell center in course coordinates.
        let route: [(Double, Double)] = [(5.5, 1.5), (5.5, 5.5), (1.5, 5.5)]
        for (index, target) in route.enumerated() {
            var arrived = false
            for _ in 0..<120 {
                if status.label.contains("Course complete") { arrived = true; break }
                let telemetry = readTelemetry(viewport)
                let dx = target.0 - telemetry.x
                let dy = target.1 - telemetry.y
                if dx * dx + dy * dy < 0.08 { arrived = true; break }
                let distance = hypot(dx, dy)
                let ux = dx / distance
                let vy = dy / distance
                let drag = max(0.15, min(0.8, distance)) * CGFloat(scale)
                let speed = hypot(telemetry.vx, telemetry.vy)
                // Brake against momentum when it carries us past the waypoint, else chase it.
                // Scene y is up; UIKit offsets are y-down, hence the sign flip on dy.
                let travel: CGPoint
                if speed > 0.6 && (ux * telemetry.vx + vy * telemetry.vy) < 0 {
                    travel = CGPoint(x: CGFloat(-telemetry.vx / speed), y: CGFloat(telemetry.vy / speed))
                } else {
                    travel = CGPoint(x: CGFloat(ux), y: CGFloat(-vy))
                }
                center.press(forDuration: 0.05,
                             thenDragTo: center.withOffset(CGVector(dx: travel.x * drag, dy: travel.y * drag)),
                             withVelocity: .slow, thenHoldForDuration: 0.08)
            }
            XCTAssertTrue(arrived, "Waypoint \(index) unreached; telemetry: \(String(describing: viewport.value))")
        }
        XCTAssertTrue(status.label.contains("Course complete"), status.label)
        let recordedBest = best.label
        XCTAssertTrue(recordedBest.hasPrefix("Best ") && recordedBest != "Best --:--", recordedBest)
        XCTAssertEqual(checkpoints.label, "Checkpoint 2 of 2")
        app.buttons["game.retry"].tap()
        XCTAssertEqual(checkpoints.label, "Checkpoint 0 of 2")
        XCTAssertEqual(best.label, recordedBest, "Retry must keep the personal best")
    }

    private struct Telemetry { let x, y, vx, vy: Double }

    private func readTelemetry(_ viewport: XCUIElement) -> Telemetry {
        let parts = ((viewport.value as? String) ?? "").split(separator: " ").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 4, "Missing marble telemetry: \(String(describing: viewport.value))")
        guard parts.count == 4 else { return Telemetry(x: 0, y: 0, vx: 0, vy: 0) }
        return Telemetry(x: parts[0], y: parts[1], vx: parts[2], vy: parts[3])
    }
}
