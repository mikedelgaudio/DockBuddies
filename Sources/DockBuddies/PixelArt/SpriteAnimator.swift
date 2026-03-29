import SwiftUI
import Combine

final class SpriteAnimator: ObservableObject {
    @Published var bounceOffset: CGFloat = 0
    @Published var isBlinking: Bool = false
    @Published var antennaGlow: Double = 1.0

    private var cancellables = Set<AnyCancellable>()
    private let agentIndex: Int

    init(agentIndex: Int) {
        self.agentIndex = agentIndex
        startAnimations()
    }

    private func startAnimations() {
        let bounceDelay = Double(agentIndex) * 0.3
        Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .map { date in
                let t = date.timeIntervalSinceReferenceDate + bounceDelay
                return CGFloat(sin(t * 2.5)) * 3.0
            }
            .assign(to: &$bounceOffset)

        startBlinkLoop()

        Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .map { date in
                let t = date.timeIntervalSinceReferenceDate + bounceDelay
                return 0.6 + 0.4 * sin(t * 3.0)
            }
            .assign(to: &$antennaGlow)
    }

    private func startBlinkLoop() {
        let interval = Double.random(in: 2.5...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self else { return }
            self.isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.isBlinking = false
                self.startBlinkLoop()
            }
        }
    }
}
