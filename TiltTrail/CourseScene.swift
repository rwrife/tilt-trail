import SpriteKit
import TiltTrailKit
import UIKit

/// Renders in simulation cell coordinates; touch delta supplies steering, never teleports marble.
@MainActor
final class CourseScene: SKScene {
    weak var game: GameController?
    private var fingerStart: CGPoint?
    private var fingerNow: CGPoint?
    private var lastFrame: TimeInterval?
    private let marble = SKShapeNode(circleOfRadius: 0.21)

    init(course: Course) {
        super.init(size: CGSize(width: course.width, height: course.height))
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.07, green: 0.10, blue: 0.19, alpha: 1)
        isUserInteractionEnabled = true

        let board = SKShapeNode(rect: CGRect(x: 0, y: 0, width: CGFloat(course.width), height: CGFloat(course.height)))
        board.strokeColor = .white.withAlphaComponent(0.7)
        board.lineWidth = 0.035
        addChild(board)
        for x in 0..<course.width {
            for y in 0..<course.height {
                let cell = Cell(x, y)
                let color: SKColor
                if course.walls.contains(cell) { color = SKColor(red: 0.25, green: 0.44, blue: 0.61, alpha: 1) }
                else if course.pits.contains(cell) { color = .black }
                else if course.start == cell { color = .systemMint }
                else if course.finish == cell { color = .systemYellow }
                else if course.checkpoints.contains(cell) { color = .systemOrange }
                else { continue }
                let tile = SKShapeNode(rectOf: CGSize(width: 0.84, height: 0.84), cornerRadius: 0.12)
                tile.position = CGPoint(x: x + 0.5, y: y + 0.5)
                tile.fillColor = color
                tile.strokeColor = .clear
                addChild(tile)
            }
        }
        marble.fillColor = .white
        marble.strokeColor = .systemCyan
        marble.lineWidth = 0.04
        marble.zPosition = 1
        addChild(marble)
        sync()
    }

    required init?(coder: NSCoder) { fatalError("Storyboard construction unsupported") }

    func sync() {
        guard let state = game?.session.simulation else { return }
        marble.position = CGPoint(x: state.position.x, y: state.position.y)
    }

    func clearTouch() {
        fingerStart = nil
        fingerNow = nil
        lastFrame = nil
    }

    override func update(_ currentTime: TimeInterval) {
        guard let game else { return }
        defer { lastFrame = currentTime }
        guard let lastFrame else { return }
        let input: Point
        if let fingerStart, let fingerNow {
            // SpriteKit positions are in cells; 0.9 cells of finger travel gives full input.
            input = DragSteering.vector(dx: fingerNow.x - fingerStart.x,
                                        dy: fingerNow.y - fingerStart.y, travel: 0.9)
        } else {
            input = Point(0, 0)
        }
        game.advance(seconds: currentTime - lastFrame, steering: input)
        sync()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        fingerStart = touch.location(in: self)
        fingerNow = fingerStart
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        fingerNow = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { clearTouch() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { clearTouch() }
}
