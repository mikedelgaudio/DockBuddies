import SwiftUI

struct AgentDetailPopover: View {
    let agent: AgentInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(agent.color.palette[.body] ?? .gray)
                    .frame(width: 12, height: 12)
                Text(agent.summary)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
            }

            Divider()

            if let repo = agent.repository, !repo.isEmpty {
                Label(repo, systemImage: "folder.fill")
                    .font(.system(size: 10, design: .monospaced))
            }

            if let branch = agent.branch, !branch.isEmpty {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(.system(size: 10, design: .monospaced))
            }

            Label(agent.workingDirectory, systemImage: "terminal.fill")
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            HStack {
                Label("\(agent.turnCount) turns", systemImage: "bubble.left.and.bubble.right")
                Spacer()
                Label("PID \(agent.pid)", systemImage: "cpu")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 280)
    }
}
