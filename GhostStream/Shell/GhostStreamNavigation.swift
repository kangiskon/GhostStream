import SwiftUI

enum GhostStreamSection: Int, CaseIterable, Hashable {
    case home, library, devices, intelligence, more

    var title: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .devices: return "Devices"
        case .intelligence: return "Intelligence"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "rectangle.stack.fill"
        case .devices: return "rectangle.connected.to.line.below"
        case .intelligence: return "waveform.path.ecg.rectangle.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}
