import XCTest
@testable import DockBuddies

final class DockPositionManagerTests: XCTestCase {
    func testDetectsDockPosition() {
        let manager = DockPositionManager()
        let position = manager.detectDockPosition()
        XCTAssertTrue([DockPosition.bottom, .left, .right].contains(position))
    }

    func testDockAreaFrameIsValid() {
        let manager = DockPositionManager()
        let frame = manager.dockAreaFrame()
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
    }

    func testOverlayFrameAboveDock() {
        let manager = DockPositionManager()
        let dockFrame = manager.dockAreaFrame()
        let overlayFrame = manager.overlayFrame(agentCount: 4, agentSize: 48)
        XCTAssertGreaterThanOrEqual(overlayFrame.origin.y, dockFrame.origin.y)
    }
}
