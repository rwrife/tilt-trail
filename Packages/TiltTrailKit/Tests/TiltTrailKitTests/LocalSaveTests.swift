import Foundation
import Testing
@testable import TiltTrailKit

@Suite struct LocalSaveTests {
    @Test func roundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalSaveStore(url: dir.appendingPathComponent("save.json"))
        let original = LocalSave(bests: ["Switchback": 12.5], motionEnabled: true, sensitivity: 1.4)
        try store.write(original)
        #expect(try store.load() == original)
        #expect(try LocalSave.decode(original.encoded()) == original)
        try store.delete()
        #expect(try store.load() == LocalSave())
        try store.delete()
    }

    @Test func badImportsCannotOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalSaveStore(url: dir.appendingPathComponent("save.json"))
        let original = LocalSave(bests: ["Sundial": 7])
        try store.write(original)
        let bytes = try Data(contentsOf: store.url)
        let cases = [Data("broken".utf8),
                     Data("{\"version\":2,\"bests\":{},\"motionEnabled\":false,\"sensitivity\":1}".utf8),
                     Data("{\"version\":1,\"bests\":{\"unknown\":5},\"motionEnabled\":true,\"sensitivity\":1}".utf8),
                     Data("{\"version\":1,\"bests\":{\"Switchback\":-1},\"motionEnabled\":true,\"sensitivity\":1}".utf8)]
        for data in cases {
            #expect(throws: Error.self) { try store.write(LocalSave.decode(data)) }
            #expect(try Data(contentsOf: store.url) == bytes)
            #expect(try store.load() == original)
        }
        // Corruption on disk is reported, never silently treated as an empty save.
        try Data("broken".utf8).write(to: store.url, options: .atomic)
        #expect(throws: Error.self) { try store.load() }
    }
}
