import SwiftUI

struct AgentCharacterView: View {
    let color: AgentColor
    let index: Int

    @StateObject private var animator: SpriteAnimator

    init(color: AgentColor, index: Int) {
        self.color = color
        self.index = index
        _animator = StateObject(wrappedValue: SpriteAnimator(agentIndex: index))
    }

    var body: some View {
        PixelGridView(
            grid: animator.isBlinking ? AgentSprite.blinkGrid : AgentSprite.baseGrid,
            palette: color.palette,
            pixelSize: 3
        )
        .offset(y: animator.bounceOffset)
        .animation(.easeInOut(duration: 0.1), value: animator.isBlinking)
    }
}
