import Foundation

struct AgentInfo: Identifiable, Equatable {
    let sessionId: String
    let pid: Int
    let workingDirectory: String
    let repository: String?
    let branch: String?
    let summary: String
    let statusText: String
    let turnCount: Int
    let lastActivity: Date
    let color: AgentColor

    var id: String { sessionId }

    static func shortStatus(from summary: String?, latestEvent: String?) -> String {
        if let event = latestEvent, !event.isEmpty {
            return String(event.prefix(20)).uppercased()
        }
        if let summary = summary, !summary.isEmpty {
            let words = summary.split(separator: " ").prefix(3).joined(separator: " ")
            return String(words.prefix(20)).uppercased()
        }
        return "IDLE"
    }

    // Equatable conformance (exclude color for comparison)
    static func == (lhs: AgentInfo, rhs: AgentInfo) -> Bool {
        lhs.sessionId == rhs.sessionId &&
        lhs.pid == rhs.pid &&
        lhs.statusText == rhs.statusText &&
        lhs.turnCount == rhs.turnCount
    }
}
