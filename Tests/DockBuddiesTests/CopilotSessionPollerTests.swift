import XCTest
@testable import DockBuddies

final class CopilotSessionPollerTests: XCTestCase {
    func testCopilotDirectoryExists() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let copilotDir = home.appendingPathComponent(".copilot/session-state")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copilotDir.path),
                      "~/.copilot/session-state should exist")
    }

    func testPollerFindsActiveSessions() async {
        let poller = CopilotSessionPoller()
        let sessions = await poller.pollOnce()
        XCTAssertGreaterThan(sessions.count, 0, "Should find at least one active session")
    }

    func testAgentInfoHasRequiredFields() async {
        let poller = CopilotSessionPoller()
        let sessions = await poller.pollOnce()
        guard let first = sessions.first else {
            XCTFail("No sessions found"); return
        }
        XCTAssertFalse(first.sessionId.isEmpty)
        XCTAssertFalse(first.statusText.isEmpty)
    }
}
