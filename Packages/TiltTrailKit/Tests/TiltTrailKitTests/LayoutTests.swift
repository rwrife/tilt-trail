import Testing
@testable import TiltTrailKit

@Test("portrait regions cover workspace without overlap")
func portraitLayout() throws {
    let layout = try #require(TiltWorkspaceLayout(width: 390, height: 844))
    #expect(layout.course.width == 390)
    #expect(layout.course.height == layout.controls.y)
    #expect(layout.controls.height >= 64)
    #expect(layout.controls.y + layout.controls.height == 844)
}

@Test("invalid dimensions rejected, tiny workspace retains positive course")
func invalidLayout() throws {
    #expect(TiltWorkspaceLayout(width: .nan, height: 844) == nil)
    #expect(TiltWorkspaceLayout(width: 390, height: .infinity) == nil)
    #expect(TiltWorkspaceLayout(width: -1, height: 844) == nil)
    let tiny = try #require(TiltWorkspaceLayout(width: 1, height: 1))
    #expect(tiny.course.height > 0)
}
