import Foundation
import Combine

final class CopilotSessionPoller: ObservableObject {
    @Published var activeAgents: [AgentInfo] = []

    private var timer: AnyCancellable?
    private let copilotDir: URL

    init() {
        self.copilotDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".copilot")
    }

    func startPolling(interval: TimeInterval = 2.0) {
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    guard let self else { return }
                    let agents = await self.pollOnce()
                    await MainActor.run {
                        self.activeAgents = agents
                    }
                }
            }
        Task {
            let agents = await pollOnce()
            await MainActor.run { self.activeAgents = agents }
        }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    func pollOnce() async -> [AgentInfo] {
        let sessionStateDir = copilotDir.appendingPathComponent("session-state")
        let fm = FileManager.default

        guard let sessionDirs = try? fm.contentsOfDirectory(
            at: sessionStateDir, includingPropertiesForKeys: nil
        ) else { return [] }

        var activeSessions: [(uuid: String, pid: Int, dir: URL)] = []

        for dir in sessionDirs {
            guard dir.hasDirectoryPath else { continue }
            let uuid = dir.lastPathComponent
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }

            for file in contents {
                let name = file.lastPathComponent
                if name.hasPrefix("inuse.") && name.hasSuffix(".lock") {
                    let pidStr = name.replacingOccurrences(of: "inuse.", with: "")
                        .replacingOccurrences(of: ".lock", with: "")
                    if let pid = Int(pidStr), isProcessAlive(pid: pid) {
                        activeSessions.append((uuid: uuid, pid: pid, dir: dir))
                    }
                }
            }
        }

        // Sort by session UUID for stable ordering across polls
        activeSessions.sort { $0.uuid < $1.uuid }

        let dbPath = copilotDir.appendingPathComponent("session-store.db").path
        let db = SQLiteReader(path: dbPath)

        var agents: [AgentInfo] = []

        for session in activeSessions {
            let rows = db?.query(
                "SELECT id, cwd, repository, branch, summary, updated_at FROM sessions WHERE id = ?",
                params: [session.uuid]
            )
            let row = rows?.first

            let turnRows = db?.query(
                "SELECT COUNT(*) as cnt FROM turns WHERE session_id = ?",
                params: [session.uuid]
            )

            let eventStatus = EventStreamParser.latestStatus(sessionDir: session.dir)

            let summary = row?.string("summary") ?? "Working..."
            let statusText = AgentInfo.shortStatus(from: summary, latestEvent: eventStatus)

            // Parse updated_at from DB for stable sorting
            let updatedStr = row?.string("updated_at") ?? ""
            let updatedAt = ISO8601DateFormatter().date(from: updatedStr) ?? Date.distantPast

            // Assign color deterministically from session UUID (stable across polls)
            let colorIndex = stableColorIndex(for: session.uuid)

            agents.append(AgentInfo(
                sessionId: session.uuid,
                pid: session.pid,
                workingDirectory: row?.string("cwd") ?? "",
                repository: row?.string("repository"),
                branch: row?.string("branch"),
                summary: summary,
                statusText: statusText,
                turnCount: turnRows?.first?.int("cnt") ?? 0,
                lastActivity: updatedAt,
                color: AgentColor.allCases[colorIndex]
            ))
        }

        return agents.sorted { $0.lastActivity > $1.lastActivity }
    }

    /// Deterministic color from session UUID — same session always gets the same color
    private func stableColorIndex(for uuid: String) -> Int {
        let hash = uuid.utf8.reduce(0) { ($0 &+ Int($1)) &* 31 }
        return abs(hash) % AgentColor.allCases.count
    }

    private func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }
}
