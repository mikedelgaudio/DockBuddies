import AppKit
import Combine

enum DockPosition {
    case bottom, left, right
}

final class DockPositionManager: ObservableObject {
    @Published var dockPosition: DockPosition = .bottom
    @Published var currentOverlayFrame: CGRect = .zero

    private var cancellables = Set<AnyCancellable>()

    init() {
        observeScreenChanges()
        refresh()
    }

    func detectDockPosition() -> DockPosition {
        guard let screen = NSScreen.main else { return .bottom }
        let full = screen.frame
        let visible = screen.visibleFrame

        let bottomGap = visible.origin.y - full.origin.y
        let leftGap = visible.origin.x - full.origin.x
        let rightGap = (full.origin.x + full.width) - (visible.origin.x + visible.width)

        if bottomGap > 50 { return .bottom }
        if leftGap > 50 { return .left }
        if rightGap > 50 { return .right }
        return .bottom
    }

    func dockAreaFrame() -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        let full = screen.frame
        let visible = screen.visibleFrame
        let position = detectDockPosition()

        switch position {
        case .bottom:
            let height = visible.origin.y - full.origin.y
            return CGRect(x: full.origin.x, y: full.origin.y,
                          width: full.width, height: max(height, 70))
        case .left:
            let width = visible.origin.x - full.origin.x
            return CGRect(x: full.origin.x, y: full.origin.y,
                          width: max(width, 70), height: full.height)
        case .right:
            let width = (full.origin.x + full.width) - (visible.origin.x + visible.width)
            let x = visible.origin.x + visible.width
            return CGRect(x: x, y: full.origin.y,
                          width: max(width, 70), height: full.height)
        }
    }

    func overlayFrame(agentCount: Int, agentSize: CGFloat = 48) -> CGRect {
        let dockFrame = dockAreaFrame()
        let spacing: CGFloat = 16
        let totalWidth = CGFloat(agentCount) * agentSize + CGFloat(agentCount - 1) * spacing
        let statusHeight: CGFloat = 24
        let totalHeight = agentSize + statusHeight + 8

        switch detectDockPosition() {
        case .bottom:
            let x = dockFrame.midX - totalWidth / 2
            let y = dockFrame.origin.y + dockFrame.height - 4
            return CGRect(x: x, y: y, width: totalWidth, height: totalHeight)
        case .left:
            let x = dockFrame.origin.x + dockFrame.width - 4
            let y = dockFrame.midY - totalHeight / 2
            return CGRect(x: x, y: y, width: totalWidth, height: totalHeight)
        case .right:
            let x = dockFrame.origin.x - totalWidth + 4
            let y = dockFrame.midY - totalHeight / 2
            return CGRect(x: x, y: y, width: totalWidth, height: totalHeight)
        }
    }

    func refresh() {
        dockPosition = detectDockPosition()
        currentOverlayFrame = overlayFrame(agentCount: 4)
    }

    private func observeScreenChanges() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }
}
