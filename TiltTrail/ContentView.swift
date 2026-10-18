import SwiftUI
import SpriteKit
import TiltTrailKit

struct ContentView: View {
    @State private var game = GameController(course: TrailCourses.all[0])

    var body: some View {
        GeometryReader { geometry in
            if let layout = TiltWorkspaceLayout(width: geometry.size.width, height: geometry.size.height) {
                VStack(spacing: 0) {
                    SpriteView(scene: game.scene)
                        .frame(height: layout.course.height)
                        .accessibilityIdentifier("course.viewport")
                        .accessibilityLabel("Course \(game.course.id)")
                        .accessibilityValue(game.marbleAccessibilityValue)

                    VStack(spacing: 8) {
                        Picker("Course", selection: Binding(
                            get: { game.course.id },
                            set: { id in
                                if let picked = TrailCourses.all.first(where: { $0.id == id }) {
                                    game.select(course: picked)
                                }
                            }
                        )) {
                            ForEach(TrailCourses.all, id: \.id) { course in
                                Text(course.id).tag(course.id)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("course.picker")

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.statusText)
                                    .font(.title2.monospacedDigit().bold())
                                    .accessibilityIdentifier("game.status")
                                Text(game.checkpointText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("game.checkpoints")
                            }
                            Spacer()
                            Text(game.bestText)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("game.best")
                        }

                        HStack(spacing: 12) {
                            Button(game.isPaused ? "Resume" : "Pause") {
                                game.togglePause()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("game.pause")
                            .disabled(game.isFinished)

                            Button("Retry") {
                                game.retry()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("game.retry")

                            Button("Checkpoint") {
                                game.restartFromCheckpoint()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("game.checkpoint")
                            .disabled(game.isFinished)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.controls.height)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}
