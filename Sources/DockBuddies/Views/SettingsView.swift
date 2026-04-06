import SwiftUI

struct SettingsView: View {
    @ObservedObject var poller: CopilotSessionPoller
    @State private var showDebug = false

    var body: some View {
        TabView {
            // MARK: - General tab
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text("DockBuddies")
                            .font(.title2.bold())
                        Text("Copilot agent companions for your dock")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)

                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(poller.activeAgents.isEmpty ? .orange : .green)
                                .font(.system(size: 8))
                            Text("\(poller.activeAgents.count) active agent\(poller.activeAgents.count == 1 ? "" : "s")")
                        }

                        HStack {
                            Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(accessibilityGranted ? .green : .orange)
                            Text(accessibilityGranted ? "Accessibility: Granted" : "Accessibility: Not granted (needed for tab switching)")
                                .font(.system(size: 11))
                        }

                        if !accessibilityGranted {
                            Button("Grant Accessibility Permission") {
                                TerminalFocuser.ensureAccessibilityPermission(prompt: true)
                            }
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                Spacer()

                HStack {
                    Spacer()
                    Button("Quit DockBuddies") {
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding(20)
            .tabItem { Label("General", systemImage: "gear") }

            // MARK: - Active Agents tab
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Agents")
                    .font(.headline)

                if poller.activeAgents.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No active Copilot sessions")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(poller.activeAgents) { agent in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(agent.color.palette[.body] ?? .gray)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.summary)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    if let repo = agent.repository, !repo.isEmpty {
                                        Label(repo, systemImage: "arrow.triangle.branch")
                                    }
                                    Label(agent.statusText, systemImage: "bolt.fill")
                                        .foregroundColor(.blue)
                                }
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                TerminalFocuser.focusTerminal(forPID: agent.pid)
                            } label: {
                                Image(systemName: "terminal.fill")
                            }
                            .buttonStyle(.borderless)
                            .help("Focus terminal")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("Agents", systemImage: "cpu") }

            // MARK: - Debug tab
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug")
                    .font(.headline)

                GroupBox("Process Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(poller.activeAgents) { agent in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.summary)
                                    .font(.system(size: 11, weight: .semibold))
                                debugRow("Session", agent.sessionId)
                                debugRow("PID", "\(agent.pid)")
                                debugRow("TTY", getTTY(pid: agent.pid))
                                debugRow("Status", agent.statusText)
                                debugRow("CWD", agent.workingDirectory)
                                if let repo = agent.repository { debugRow("Repo", repo) }
                                if let branch = agent.branch { debugRow("Branch", branch) }
                                debugRow("Turns", "\(agent.turnCount)")
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                GroupBox("Accessibility") {
                    VStack(alignment: .leading, spacing: 4) {
                        debugRow("AXIsProcessTrusted", accessibilityGranted ? "✅ Yes" : "❌ No")
                        debugRow("Bundle ID", Bundle.main.bundleIdentifier ?? "none")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                Spacer()

                Button("Copy Debug Info") {
                    copyDebugInfo()
                }
                .controlSize(.small)
            }
            .padding(20)
            .tabItem { Label("Debug", systemImage: "ladybug") }
        }
        .frame(width: 480, height: 400)
    }

    private var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func getTTY(pid: Int) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "tty=", "-p", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
    }

    private func copyDebugInfo() {
        var info = "DockBuddies Debug Info\n"
        info += "======================\n"
        info += "AXIsProcessTrusted: \(accessibilityGranted)\n"
        info += "Bundle ID: \(Bundle.main.bundleIdentifier ?? "none")\n"
        info += "Active agents: \(poller.activeAgents.count)\n\n"

        for agent in poller.activeAgents {
            info += "Agent: \(agent.summary)\n"
            info += "  Session: \(agent.sessionId)\n"
            info += "  PID: \(agent.pid)\n"
            info += "  TTY: \(getTTY(pid: agent.pid))\n"
            info += "  Status: \(agent.statusText)\n"
            info += "  CWD: \(agent.workingDirectory)\n"
            info += "  Repo: \(agent.repository ?? "none")\n"
            info += "  Branch: \(agent.branch ?? "none")\n\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}
