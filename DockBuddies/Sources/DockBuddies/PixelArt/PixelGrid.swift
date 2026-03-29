import SwiftUI

struct PixelGridView: View {
    let grid: [[PixelType]]
    let palette: [PixelType: Color]
    let pixelSize: CGFloat

    init(grid: [[PixelType]], palette: [PixelType: Color], pixelSize: CGFloat = 3) {
        self.grid = grid
        self.palette = palette
        self.pixelSize = pixelSize
    }

    var body: some View {
        Canvas { context, size in
            for (row, rowData) in grid.enumerated() {
                for (col, pixel) in rowData.enumerated() {
                    guard pixel != .clear,
                          let color = palette[pixel] else { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(grid.first?.count ?? 0) * pixelSize,
            height: CGFloat(grid.count) * pixelSize
        )
    }
}
