import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill",
                                   accessibilityDescription: "DockBuddies")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit DockBuddies", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
