import SwiftUI

struct AgentOverlayView: View {
    @ObservedObject var poller: CopilotSessionPoller

    @State private var selectedAgent: AgentInfo?

    @State private var flashingAgentId: String?

    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(displayAgents.enumerated()), id: \.element.id) { index, agent in
                AgentBuddyView(agent: agent, index: index, isFlashing: flashingAgentId == agent.id)
                    .overlay(
                        ClickInterceptor(
                            onSingleClick: {
                                selectedAgent = (selectedAgent?.id == agent.id) ? nil : agent
                            },
                            onDoubleClick: {
                                // Flash feedback
                                flashingAgentId = agent.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    flashingAgentId = nil
                                }
                                // Focus terminal
                                TerminalFocuser.focusTerminal(forPID: agent.pid)
                            }
                        )
                    )
                    .popover(
                        isPresented: Binding(
                            get: { selectedAgent?.id == agent.id },
                            set: { if !$0 { selectedAgent = nil } }
                        ),
                        arrowEdge: .bottom
                    ) {
                        AgentDetailPopover(agent: agent)
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var displayAgents: [AgentInfo] {
        let active = poller.activeAgents
        if active.isEmpty {
            return [AgentInfo(
                sessionId: "idle-placeholder",
                pid: 0,
                workingDirectory: "",
                repository: nil,
                branch: nil,
                summary: "No active agents",
                statusText: "IDLE",
                turnCount: 0,
                lastActivity: Date(),
                color: .teal
            )]
        }
        return active
    }
}

// MARK: - Instant double-click via NSView (no SwiftUI gesture delay)

/// Intercepts mouse clicks at the AppKit level so double-click fires
/// on the second mouseDown — no 300ms disambiguation delay.
struct ClickInterceptor: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ClickInterceptorNSView {
        let view = ClickInterceptorNSView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ClickInterceptorNSView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

final class ClickInterceptorNSView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    private var singleClickTimer: Timer?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Cancel pending single-click and fire double-click immediately
            singleClickTimer?.invalidate()
            singleClickTimer = nil
            onDoubleClick?()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 1 {
            // Defer single-click to allow double-click detection
            singleClickTimer?.invalidate()
            singleClickTimer = Timer.scheduledTimer(
                withTimeInterval: NSEvent.doubleClickInterval,
                repeats: false
            ) { [weak self] _ in
                self?.onSingleClick?()
            }
        }
    }
}

// MARK: - Agent buddy

struct AgentBuddyView: View {
    let agent: AgentInfo
    let index: Int
    var isFlashing: Bool = false

    @State private var appear = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            StatusBubbleView(text: agent.statusText)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)

            AgentCharacterView(color: agent.color, index: index)
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)
        }
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .shadow(color: isHovered ? (agent.color.palette[.body] ?? .white).opacity(0.6) : .clear,
                radius: isHovered ? 8 : 0)
        // Double-click flash: bright overlay that fades out
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .opacity(isFlashing ? 0.6 : 0)
                .animation(.easeOut(duration: 0.3), value: isFlashing)
                .allowsHitTesting(false)
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15)) {
                appear = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(agent.accessibilityDescription)
        .accessibilityHint("Click to view details. Double-click to focus terminal.")
        .accessibilityAddTraits(.isButton)
    }
}
