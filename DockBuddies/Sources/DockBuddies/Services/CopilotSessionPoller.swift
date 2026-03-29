import Foundation
import Combine

final class CopilotSessionPoller: ObservableObject {
    @Published var activeAgents: [AgentInfo] = []

    private var timer: AnyCancellable?
    private let copilotDir: URL
    private let maxAgents: Int

    init(maxAgents: Int = 4) {
        self.maxAgents = maxAgents
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

        let dbPath = copilotDir.appendingPathComponent("session-store.db").path
        let db = SQLiteReader(path: dbPath)

        let colors = AgentColor.allCases
        var agents: [AgentInfo] = []

        for (index, session) in activeSessions.prefix(maxAgents).enumerated() {
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

            agents.append(AgentInfo(
                sessionId: session.uuid,
                pid: session.pid,
                workingDirectory: row?.string("cwd") ?? "",
                repository: row?.string("repository"),
                branch: row?.string("branch"),
                summary: summary,
                statusText: statusText,
                turnCount: turnRows?.first?.int("cnt") ?? 0,
                lastActivity: Date(),
                color: colors[index % colors.count]
            ))
        }

        return agents.sorted { $0.lastActivity > $1.lastActivity }
    }

    private func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }
}
