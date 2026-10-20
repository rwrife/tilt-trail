import SwiftUI
import SpriteKit
import TiltTrailKit

struct ContentView: View {
    @State private var game = GameController(course: TrailCourses.all[0])
    @State private var showingTiltSettings = false

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
                            Button {
                                showingTiltSettings = true
                            } label: {
                                Image(systemName: game.motionConfig.isMotionEnabled ? "gyroscope.fill" : "gyroscope")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Tilt settings")
                            .accessibilityValue(game.motionConfig.isMotionEnabled ? "On" : "Off")
                            .accessibilityIdentifier("motion.settings")
                            .sheet(isPresented: $showingTiltSettings) {
                                tiltSettings
                            }
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
                .onAppear { game.appear() }
                .onDisappear { game.disappear() }
            }
        }
    }

    private var tiltSettings: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use tilt steering", isOn: Binding(
                        get: { game.motionConfig.isMotionEnabled },
                        set: { game.setMotionEnabled($0) }
                    ))
                    .accessibilityIdentifier("motion.toggle")
                    .disabled(!game.isSensorAvailable)

                    Text(game.motionStatus)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Motion stays off until enabled. Touch steering always works and takes priority while dragging.")
                }

                if game.motionConfig.isMotionEnabled {
                    Section("Tilt calibration") {
                        Slider(
                            value: Binding(
                                get: { game.motionConfig.sensitivity },
                                set: { game.setSensitivity($0) }
                            ),
                            in: 0.2...3.0
                        ) {
                            Text("Sensitivity")
                        }
                        .accessibilityIdentifier("motion.sensitivity")

                        Button("Calibrate neutral angle") {
                            game.calibrate()
                        }
                        .accessibilityIdentifier("motion.calibrate")
                        .disabled(game.isPaused || game.isFinished)
                        Text(game.isCalibrationReady ? "Neutral angle saved for this session." : "Hold phone level, then calibrate. Calibration needs a live sensor sample.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Tilt settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingTiltSettings = false }
                }
            }
        }
    }
}
