import AppKit
import Foundation

/// Finds and focuses the terminal window that is running a given process.
/// Walks up the process tree from a PID to find the parent terminal app,
/// then activates that app's window.
struct TerminalFocuser {

    /// Known terminal bundle identifiers mapped to display names
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

    /// Attempt to focus the terminal running the given PID.
    /// Returns true if a terminal was found and activated.
    @discardableResult
    static func focusTerminal(forPID pid: Int) -> Bool {
        guard pid > 0 else { return false }

        // Walk up the process tree to find a terminal ancestor
        let ancestors = getAncestorPIDs(of: pid)

        // Check each running app against our ancestor PIDs
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  knownTerminals.keys.contains(bundleId) else { continue }

            let appPID = Int(app.processIdentifier)
            if ancestors.contains(appPID) {
                // Found the terminal — activate it
                app.activate()

                // For Terminal.app, try to focus the specific tab via AppleScript
                if bundleId == "com.apple.Terminal" {
                    focusTerminalAppWindow(pid: pid)
                } else if bundleId == "com.googlecode.iterm2" {
                    focusITermWindow(pid: pid)
                }

                return true
            }
        }

        // Fallback: check if any terminal has a child matching our PID's session
        return focusTerminalByProcessGroup(pid: pid)
    }

    /// Walk up the process tree and collect all ancestor PIDs.
    private static func getAncestorPIDs(of pid: Int) -> Set<Int> {
        var ancestors = Set<Int>()
        var current = pid

        for _ in 0..<50 { // safety limit
            let parent = getParentPID(of: current)
            if parent <= 1 || ancestors.contains(parent) { break }
            ancestors.insert(parent)
            current = parent
        }

        return ancestors
    }

    /// Get the parent PID of a process using sysctl.
    private static func getParentPID(of pid: Int) -> Int {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return 0 }

        return Int(info.kp_eproc.e_ppid)
    }

    /// For Terminal.app: use AppleScript to find and focus the window/tab with our process.
    private static func focusTerminalAppWindow(pid: Int) {
        let script = """
        tell application "Terminal"
            activate
            set targetTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set tabProcesses to processes of t
                        repeat with p in tabProcesses
                            if p contains "\(pid)" then
                                set targetTab to t
                                set selected of t to true
                                set index of w to 1
                                exit repeat
                            end if
                        end repeat
                    end try
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    /// For iTerm2: use AppleScript to find the session running our process.
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

    /// Fallback: find terminal by process group — if the copilot process shares a
    /// process group with a terminal's child, activate that terminal.
    private static func focusTerminalByProcessGroup(pid: Int) -> Bool {
        // Get the process group of our target PID
        let pgid = getpgid(Int32(pid))
        guard pgid > 0 else { return false }

        // Check each running terminal app
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  knownTerminals.keys.contains(bundleId) else { continue }

            // Activate the first terminal we find as a last resort
            app.activate()
            return true
        }

        return false
    }

    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
