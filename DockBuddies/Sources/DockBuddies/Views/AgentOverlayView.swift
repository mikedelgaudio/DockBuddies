import SwiftUI

struct AgentOverlayView: View {
    @ObservedObject var poller: CopilotSessionPoller

    @State private var selectedAgent: AgentInfo?

    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(displayAgents.enumerated()), id: \.element.id) { index, agent in
                AgentBuddyView(agent: agent, index: index)
                    .onTapGesture {
                        selectedAgent = (selectedAgent?.id == agent.id) ? nil : agent
                    }
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

struct AgentBuddyView: View {
    let agent: AgentInfo
    let index: Int

    @State private var appear = false

    var body: some View {
        VStack(spacing: 2) {
            StatusBubbleView(text: agent.statusText)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)

            AgentCharacterView(color: agent.color, index: index)
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15)) {
                appear = true
            }
        }
    }
}
