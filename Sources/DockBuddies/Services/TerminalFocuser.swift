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

    /// Finds which Ghostty window and tab owns the copilot process's TTY,
    /// raises the correct window, then switches to the correct tab via Cmd+N.
    private static func focusGhosttyTab(pid: Int, ghosttyPID: Int) {
        guard let targetTTY = getProcessTTY(pid: pid) else { return }

        // Build a map of all Ghostty child processes → TTYs
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

        tabEntries.sort { $0.pid < $1.pid }
        var seen = Set<String>()
        let uniqueTabs = tabEntries.filter { seen.insert($0.tty).inserted }

        // Try AX-based window targeting when we have Accessibility permission.
        // This handles multiple Ghostty windows correctly.
        if AXIsProcessTrusted() {
            let appElement = AXUIElementCreateApplication(pid_t(ghosttyPID))
            var windowsRef: CFTypeRef?

            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {

                // Strategy: Count tabs per window using AX, then partition our
                // global tab list to find which window + local index has our TTY.
                var windowInfos: [(element: AXUIElement, tabCount: Int)] = []

                for window in windows {
                    let tabCount = getGhosttyWindowTabCount(window)
                    if tabCount > 0 {
                        windowInfos.append((element: window, tabCount: tabCount))
                    }
                }

                if !windowInfos.isEmpty {
                    // Partition global tab list across windows.
                    // Ghostty windows are ordered newest-first in AX, but tabs within
                    // each window follow PID creation order. We reverse to match PID order.
                    windowInfos.reverse()

                    var globalIdx = 0
                    for info in windowInfos {
                        for localIdx in 0..<info.tabCount {
                            if globalIdx < uniqueTabs.count && uniqueTabs[globalIdx].tty == targetTTY {
                                // Found it! Raise this window, then switch to the local tab.
                                AXUIElementPerformAction(info.element, kAXRaiseAction as CFString)
                                if info.tabCount > 1 {
                                    sendCmdNumber(localIdx + 1, toProcessID: pid_t(ghosttyPID))
                                }
                                return
                            }
                            globalIdx += 1
                        }
                    }
                }

                // Fallback: if tab counting didn't work, try matching by window title
                // (Ghostty shows the focused tab's CWD/command in the title)
                let targetDir = getProcessCWD(pid: pid)
                for window in windows {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let title = titleRef as? String, !title.isEmpty {
                        if let dir = targetDir, title.contains(dir) {
                            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                            // Find the local tab index within this window
                            // (best effort: use global index as fallback)
                            if let idx = uniqueTabs.firstIndex(where: { $0.tty == targetTTY }), idx + 1 <= 9 {
                                sendCmdNumber(idx + 1, toProcessID: pid_t(ghosttyPID))
                            }
                            return
                        }
                    }
                }
            }
        }

        // Fallback: global tab index (works for single-window Ghostty)
        if let tabIndex = uniqueTabs.firstIndex(where: { $0.tty == targetTTY }), tabIndex + 1 <= 9 {
            sendCmdNumber(tabIndex + 1, toProcessID: pid_t(ghosttyPID))
        }
    }

    /// Count the number of tabs in a Ghostty AX window by inspecting its children.
    private static func getGhosttyWindowTabCount(_ window: AXUIElement) -> Int {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return 0 }

        // Look for a tab group (standard AX pattern)
        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            if let role = roleRef as? String {
                if role == "AXTabGroup" {
                    var tabsRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXTabsAttribute as CFString, &tabsRef) == .success,
                       let tabs = tabsRef as? [AXUIElement] {
                        return tabs.count
                    }
                    // Try AXChildren of the tab group
                    var tabChildrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &tabChildrenRef) == .success,
                       let tabChildren = tabChildrenRef as? [AXUIElement] {
                        // Count children that look like tabs
                        var count = 0
                        for tc in tabChildren {
                            var tcRoleRef: CFTypeRef?
                            AXUIElementCopyAttributeValue(tc, kAXRoleAttribute as CFString, &tcRoleRef)
                            if let tcRole = tcRoleRef as? String,
                               tcRole == "AXRadioButton" || tcRole == "AXTab" || tcRole == "AXButton" {
                                count += 1
                            }
                        }
                        if count > 0 { return count }
                    }
                }
            }
        }

        // Ghostty may not use standard AXTabGroup — assume 1 tab per window
        // if we can't determine the tab structure
        return 0
    }

    /// Get the current working directory of a process
    private static func getProcessCWD(pid: Int) -> String? {
        guard let output = runShellCommand("/bin/ps", args: ["-o", "comm=", "-p", "\(pid)"]) else { return nil }
        // Try lsof to get the cwd
        guard let lsofOutput = runShellCommand("/usr/sbin/lsof", args: ["-p", "\(pid)", "-Fn", "-d", "cwd"]) else { return nil }
        for line in lsofOutput.split(separator: "\n") {
            if line.hasPrefix("n") {
                let path = String(line.dropFirst())
                // Return just the last component for matching
                return URL(fileURLWithPath: path).lastPathComponent
            }
        }
        return nil
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
