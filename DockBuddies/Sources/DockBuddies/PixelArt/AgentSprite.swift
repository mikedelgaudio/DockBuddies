import Foundation

struct AgentSprite {
    typealias Grid = [[PixelType]]

    static let baseGrid: Grid = {
        let raw: [[Character]] = [
            list("......T..T......"),
            list("......A..A......"),
            list("......A..A......"),
            list("....DBBBBBD....."),
            list("...DBBBBBBBD...."),
            list("..DBEEPBEEPBD..."),
            list("..DBEEPBEEPBD..."),
            list("..DBBMMMBBBBD..."),
            list("..DBBBBBBBBD...."),
            list("...DBBBBBBBD...."),
            list("...DBBBBBBD....."),
            list("....DBBBBBD....."),
            list("....DBBBBBD....."),
            list("...FF....FF....."),
            list("...FF....FF....."),
            list("................"),
        ]

        return raw.map { row in
            row.map { ch -> PixelType in
                switch ch {
                case "B": return .body
                case "D": return .bodyDark
                case "E": return .eye
                case "P": return .eyePupil
                case "A": return .antenna
                case "T": return .antennaTop
                case "F": return .feet
                case "M": return .mouth
                default:  return .clear
                }
            }
        }
    }()

    static let blinkGrid: Grid = {
        var grid = baseGrid
        for col in 0..<16 {
            if grid[5][col] == .eye || grid[5][col] == .eyePupil {
                grid[5][col] = .body
            }
            if grid[6][col] == .eye || grid[6][col] == .eyePupil {
                grid[6][col] = .bodyDark
            }
        }
        return grid
    }()

    private static func list(_ s: String) -> [Character] {
        Array(s)
    }
}
