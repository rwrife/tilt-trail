import Foundation

/// Only finished personal bests and control preferences are durable. Runs restart on launch.
public struct LocalSave: Codable, Equatable, Sendable {
    public let version: Int
    public let bests: [String: Double]
    public let motionEnabled: Bool
    public let sensitivity: Double

    public init(bests: [String: Double] = [:], motionEnabled: Bool = false, sensitivity: Double = 1) {
        version = 1
        self.bests = bests
        self.motionEnabled = motionEnabled
        self.sensitivity = sensitivity
    }

    public static func decode(_ data: Data) throws -> LocalSave {
        // Validate before replacing existing state; Codable rejects missing fields and wrong types.
        guard data.count <= 64 * 1024 else { throw SaveError.invalidData }
        let value = try JSONDecoder().decode(LocalSave.self, from: data)
        guard value.version == 1 else { throw SaveError.unsupportedVersion }
        let ids = Set(TrailCourses.all.map(\.id))
        guard value.bests.count <= ids.count,
              value.bests.allSatisfy({ ids.contains($0.key) && $0.value.isFinite && $0.value > 0 }),
              value.sensitivity.isFinite, (0.2...3.0).contains(value.sensitivity) else {
            throw SaveError.invalidData
        }
        return value
    }

    public func encoded() throws -> Data {
        _ = try Self.decode(JSONEncoder().encode(self))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

public enum SaveError: Error, LocalizedError {
    case invalidData, unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .invalidData: "Invalid save data. Existing records were kept."
        case .unsupportedVersion: "Unsupported save version. Existing records were kept."
        }
    }
}

public struct LocalSaveStore {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> LocalSave {
        do { return try LocalSave.decode(Data(contentsOf: url)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return LocalSave() }
    }

    public func write(_ save: LocalSave) throws {
        let bytes = try save.encoded()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
    }

    public func delete() throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }
    }
}
