import SwiftUI
import SpriteKit
import UniformTypeIdentifiers
import TiltTrailKit

private struct SaveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw SaveError.invalidData }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ContentView: View {
    @State private var game = GameController(course: TrailCourses.all[0])
    @State private var showingTiltSettings = false
    @State private var showingData = false
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var importCandidate: Data?
    @State private var confirmingDelete = false
    @State private var dataError: String?
    @State private var exportDocument: SaveDocument?

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
                            .sheet(isPresented: $showingTiltSettings) { tiltSettings }
                            Button {
                                showingData = true
                            } label: {
                                Image(systemName: "externaldrive")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Local data")
                            .accessibilityIdentifier("data.settings")
                            .sheet(isPresented: $showingData) { dataSettings }
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

    private var dataSettings: some View {
        NavigationStack { dataDialogView }
    }

    private var dataDialogView: some View {
        dataTransferView
            .confirmationDialog("Replace existing local times and settings?", isPresented: Binding(
                get: { importCandidate != nil },
                set: { if !$0 { importCandidate = nil } }
            ), titleVisibility: .visible) {
                Button("Replace data", role: .destructive) { confirmReplace() }
                Button("Cancel", role: .cancel) { importCandidate = nil }
            }
            .confirmationDialog("Delete all local times and settings?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) { confirmDelete() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Local data error", isPresented: Binding(
                get: { dataError != nil },
                set: { if !$0 { dataError = nil } }
            )) {
                Button("OK") { dataError = nil }
            } message: { Text(dataError ?? "") }
    }

    private var dataTransferView: some View {
        dataForm
            .navigationTitle("Local data")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { showingData = false }
            } }
            .fileExporter(isPresented: $showingExport, document: exportDocument,
                          contentType: .json, defaultFilename: "TiltTrail-save") { result in
                if case .failure(let error) = result { showError(error.localizedDescription) }
            }
            .fileImporter(isPresented: $showingImport, allowedContentTypes: [.json],
                          onCompletion: handleImportResult)
    }

    private func showError(_ message: String) { dataError = message }

    private func handleImportResult(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { throw SaveError.invalidData }
            defer { url.stopAccessingSecurityScopedResource() }
            let bytes = try Data(contentsOf: url)
            _ = try LocalSave.decode(bytes)
            importCandidate = bytes
        } catch { showError(error.localizedDescription) }
    }

    private func confirmReplace() {
        guard let data = importCandidate else { return }
        do { try game.importSave(data) }
        catch { showError(error.localizedDescription) }
        importCandidate = nil
    }

    private func confirmDelete() {
        do { try game.deleteAll() }
        catch { showError(error.localizedDescription) }
    }

    private var dataForm: some View {
        Form {
            Section("Your data") {
                Button("Export JSON") {
                    if let data = game.exportData {
                        exportDocument = SaveDocument(data: data)
                        showingExport = true
                    } else { showError("Could not prepare export.") }
                }
                .accessibilityIdentifier("data.export")
                Button("Import JSON") { showingImport = true }
                    .accessibilityIdentifier("data.import")
                Button("Delete all local data", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("data.delete")
            } footer: {
                Text("Best times and tilt preferences stay on this device. Import replaces them after confirmation. Deletion cannot be undone.")
            }
            if let warning = game.storageError {
                Text(warning).foregroundStyle(.red)
                    .accessibilityIdentifier("data.storageError")
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
