import AppKit
import Foundation

/// Finds and focuses the terminal window that is running a given process.
/// Walks up the process tree from a PID to find the parent terminal app,
/// then activates that app's window and switches to the correct tab.
struct TerminalFocuser {

    private static let knownTerminals: [String: String] = [
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "iTerm2",
        "dev.warp.Warp-Stable": "Warp",
        "com.mitchellh.ghostty": "Ghostty",
        "co.zeit.hyper": "Hyper",
        "com.github.wez.wezterm": "WezTerm",
        "net.kovidgoyal.kitty": "kitty",
        "io.alacritty": "Alacritty",
    ]

    /// Check and request Accessibility permission (needed for tab switching).
    /// Returns true if already trusted.
    @discardableResult
    static func ensureAccessibilityPermission(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func focusTerminal(forPID pid: Int) -> Bool {
        guard pid > 0 else { return false }

        let ancestors = getAncestorPIDs(of: pid)
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  knownTerminals.keys.contains(bundleId) else { continue }

            let appPID = Int(app.processIdentifier)
            if ancestors.contains(appPID) {
                // Activate the terminal app first
                app.activate()

                // Tab switching needs Accessibility — prompt only on first attempt
                let needsTabSwitch = ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty"]
                if needsTabSwitch.contains(bundleId) {
                    if !ensureAccessibilityPermission(prompt: true) {
                        // Permission not granted yet; terminal is at least activated.
                        // The system dialog will guide the user.
                        return true
                    }
                }

                // Small delay to let the app become frontmost before sending keystrokes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    switch bundleId {
                    case "com.apple.Terminal":
                        focusTerminalAppWindow(pid: pid)
                    case "com.googlecode.iterm2":
                        focusITermWindow(pid: pid)
                    case "com.mitchellh.ghostty":
                        focusGhosttyTab(pid: pid, ghosttyPID: appPID)
                    default:
                        break
                    }
                }

                return true
            }
        }

        return focusTerminalByProcessGroup(pid: pid)
    }

    // MARK: - Process tree walking

    private static func getAncestorPIDs(of pid: Int) -> Set<Int> {
        var ancestors = Set<Int>()
        var current = pid

        for _ in 0..<50 {
            let parent = getParentPID(of: current)
            if parent <= 1 || ancestors.contains(parent) { break }
            ancestors.insert(parent)
            current = parent
        }

        return ancestors
    }

    private static func getParentPID(of pid: Int) -> Int {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return 0 }

        return Int(info.kp_eproc.e_ppid)
    }

    /// Get the TTY name for a process (e.g. "ttys004")
    private static func getProcessTTY(pid: Int) -> String? {
        guard let output = runShellCommand("/bin/ps", args: ["-o", "tty=", "-p", "\(pid)"]) else { return nil }
        let tty = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return (tty.isEmpty || tty == "??") ? nil : tty
    }

    // MARK: - Ghostty tab focus

    /// Virtual key codes for number keys 1-9
    private static let numberKeyCodes: [Int: UInt16] = [
        1: 0x12, 2: 0x13, 3: 0x14, 4: 0x15, 5: 0x17,
        6: 0x16, 7: 0x1A, 8: 0x1C, 9: 0x19,
    ]

    /// Finds which Ghostty tab owns the copilot process's TTY and switches to it via Cmd+N.
    private static func focusGhosttyTab(pid: Int, ghosttyPID: Int) {
        guard let targetTTY = getProcessTTY(pid: pid) else { return }

        // Parse full process table to find Ghostty's direct children with TTYs.
        // Ghostty spawns: ghostty → /usr/bin/login → /bin/zsh (per tab)
        // Direct children of Ghostty each have a unique TTY = one tab.
        guard let psOutput = runShellCommand("/bin/ps", args: ["-eo", "pid,ppid,tty"]) else { return }

        var tabEntries: [(pid: Int, tty: String)] = []

        for line in psOutput.split(separator: "\n") {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 3,
                  let childPID = Int(parts[0]),
                  let ppid = Int(parts[1]) else { continue }

            let tty = parts[2]
            if ppid == ghosttyPID && tty != "??" && !tty.isEmpty {
                tabEntries.append((pid: childPID, tty: tty))
            }
        }

        // Sort by PID — earlier PID = earlier tab (tabs are spawned in order)
        tabEntries.sort { $0.pid < $1.pid }

        // Deduplicate by TTY
        var seen = Set<String>()
        let uniqueTabs = tabEntries.filter { seen.insert($0.tty).inserted }

        guard let tabIndex = uniqueTabs.firstIndex(where: { $0.tty == targetTTY }),
              tabIndex + 1 <= 9 else { return }

        let tabNumber = tabIndex + 1
        sendCmdNumber(tabNumber, toProcessID: pid_t(ghosttyPID))
    }

    /// Send Cmd+<number> keystroke to a specific process via CGEvent.
    private static func sendCmdNumber(_ number: Int, toProcessID processID: pid_t) {
        guard let keyCode = numberKeyCodes[number],
              let source = CGEventSource(stateID: .combinedSessionState) else { return }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.postToPid(processID)
        keyUp.postToPid(processID)
    }

    // MARK: - Terminal.app tab focus

    private static func focusTerminalAppWindow(pid: Int) {
        let script = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set tabProcesses to processes of t
                        repeat with p in tabProcesses
                            if p contains "\(pid)" then
                                set selected of t to true
                                set index of w to 1
                                return
                            end if
                        end repeat
                    end try
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - iTerm2 tab focus

    private static func focusITermWindow(pid: Int) {
        let script = """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s contains "" then
                                set thePID to (do shell script "ps -o pid= -t " & tty of s & " | grep \(pid)")
                                if thePID is not "" then
                                    select s
                                    select t
                                    set index of w to 1
                                    return
                                end if
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - Fallback

    private static func focusTerminalByProcessGroup(pid: Int) -> Bool {
        let pgid = getpgid(Int32(pid))
        guard pgid > 0 else { return false }

        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  knownTerminals.keys.contains(bundleId) else { continue }
            app.activate()
            return true
        }

        return false
    }

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }

    private static func runShellCommand(_ path: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
