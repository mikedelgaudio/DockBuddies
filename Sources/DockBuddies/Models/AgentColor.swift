import SwiftUI

enum PixelType: Hashable {
    case clear
    case body
    case bodyDark
    case eye
    case eyePupil
    case antenna
    case antennaTop
    case feet
    case mouth
}

enum AgentColor: String, CaseIterable, Identifiable {
    case orange, green, red, teal

    var id: String { rawValue }

    var palette: [PixelType: Color] {
        switch self {
        case .orange:
            return [
                .body: Color(red: 0.85, green: 0.55, blue: 0.20),
                .bodyDark: Color(red: 0.65, green: 0.40, blue: 0.15),
                .eye: Color.white,
                .eyePupil: Color(red: 0.15, green: 0.10, blue: 0.10),
                .antenna: Color(red: 0.50, green: 0.35, blue: 0.15),
                .antennaTop: Color(red: 1.0, green: 0.8, blue: 0.3),
                .feet: Color(red: 0.65, green: 0.40, blue: 0.15),
                .mouth: Color(red: 0.45, green: 0.30, blue: 0.15),
            ]
        case .green:
            return [
                .body: Color(red: 0.30, green: 0.75, blue: 0.30),
                .bodyDark: Color(red: 0.20, green: 0.55, blue: 0.20),
                .eye: Color.white,
                .eyePupil: Color(red: 0.10, green: 0.15, blue: 0.10),
                .antenna: Color(red: 0.20, green: 0.50, blue: 0.20),
                .antennaTop: Color(red: 0.5, green: 1.0, blue: 0.3),
                .feet: Color(red: 0.20, green: 0.55, blue: 0.20),
                .mouth: Color(red: 0.15, green: 0.40, blue: 0.15),
            ]
        case .red:
            return [
                .body: Color(red: 0.85, green: 0.25, blue: 0.25),
                .bodyDark: Color(red: 0.65, green: 0.18, blue: 0.18),
                .eye: Color.white,
                .eyePupil: Color(red: 0.15, green: 0.10, blue: 0.10),
                .antenna: Color(red: 0.55, green: 0.15, blue: 0.15),
                .antennaTop: Color(red: 1.0, green: 0.3, blue: 0.3),
                .feet: Color(red: 0.65, green: 0.18, blue: 0.18),
                .mouth: Color(red: 0.50, green: 0.15, blue: 0.15),
            ]
        case .teal:
            return [
                .body: Color(red: 0.20, green: 0.75, blue: 0.70),
                .bodyDark: Color(red: 0.15, green: 0.55, blue: 0.50),
                .eye: Color.white,
                .eyePupil: Color(red: 0.10, green: 0.10, blue: 0.15),
                .antenna: Color(red: 0.15, green: 0.50, blue: 0.45),
                .antennaTop: Color(red: 0.3, green: 1.0, blue: 0.9),
                .feet: Color(red: 0.15, green: 0.55, blue: 0.50),
                .mouth: Color(red: 0.10, green: 0.40, blue: 0.35),
            ]
        }
    }
}
