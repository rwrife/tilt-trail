/// Geometry seam for current portrait iPhone workspace. Future display routing
/// can replace these regions without changing course or control state.
public struct TiltWorkspaceLayout: Equatable, Sendable {
    public struct Region: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
    }

    public let course: Region
    public let controls: Region

    public init?(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        let strip = min(height * 0.5, max(64, min(160, height * 0.25)))
        course = Region(x: 0, y: 0, width: width, height: height - strip)
        controls = Region(x: 0, y: height - strip, width: width, height: strip)
    }
}
