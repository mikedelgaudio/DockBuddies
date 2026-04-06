import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayPanel: OverlayPanel?
    private let dockManager = DockPositionManager()
    private let poller = CopilotSessionPoller()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlayPanel()
        poller.startPolling(interval: 2.0)
        observeChanges()

        // Prompt for Accessibility permission on first launch (needed for tab switching)
        TerminalFocuser.ensureAccessibilityPermission(prompt: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stopPolling()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill",
                                   accessibilityDescription: "DockBuddies")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Buddies", action: #selector(toggleOverlay), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DockBuddies", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupOverlayPanel() {
        let agentCount = max(poller.activeAgents.count, 1)
        let frame = dockManager.overlayFrame(agentCount: agentCount)
        overlayPanel = OverlayPanel(contentRect: frame)

        let overlayView = AgentOverlayView(poller: poller)
        let hostView = NSHostingView(rootView: overlayView)
        hostView.layer?.backgroundColor = .clear
        overlayPanel?.contentView = hostView
        overlayPanel?.orderFrontRegardless()
    }

    private func observeChanges() {
        dockManager.$currentOverlayFrame
            .combineLatest(poller.$activeAgents)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _, agents in
                guard let self, let panel = self.overlayPanel else { return }
                let count = max(agents.count, 1)
                let frame = self.dockManager.overlayFrame(agentCount: count)
                panel.setFrame(frame, display: true, animate: true)
            }
            .store(in: &cancellables)
    }

    @objc private func toggleOverlay() {
        if overlayPanel?.isVisible == true {
            overlayPanel?.orderOut(nil)
        } else {
            overlayPanel?.orderFrontRegardless()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
