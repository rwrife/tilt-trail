import SwiftUI
import SpriteKit
import TiltTrailKit

struct ContentView: View {
    private let scene: SKScene = {
        let scene = SKScene(size: CGSize(width: 390, height: 600))
        scene.backgroundColor = .systemIndigo
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        GeometryReader { geometry in
            if let layout = TiltWorkspaceLayout(width: geometry.size.width, height: geometry.size.height) {
                VStack(spacing: 0) {
                    SpriteView(scene: scene)
                        .frame(height: layout.course.height)
                        .accessibilityLabel("Course preview unavailable; gameplay not yet implemented")
                    VStack {
                        Text("Tilt Trail")
                            .font(.title.bold())
                        Text("Game prototype — no playable courses yet")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.controls.height)
                }
            }
        }
    }
}
