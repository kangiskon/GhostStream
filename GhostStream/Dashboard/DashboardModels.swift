import Foundation

enum DashboardSourceHealth: Equatable {
    case disconnected
    case loading
    case connected
    case attention(String)

    var title: String {
        switch self {
        case .disconnected: return "No Source"
        case .loading: return "Checking"
        case .connected: return "Connected"
        case .attention: return "Needs Attention"
        }
    }

    var detail: String {
        switch self {
        case .disconnected:
            return "Add or connect a source to begin."
        case .loading:
            return "GhostStream is refreshing your media library."
        case .connected:
            return "The active source is responding and its library is available."
        case .attention(let message):
            return message
        }
    }
}

struct DashboardLibraryCounts: Equatable {
    let live: Int
    let movies: Int
    let series: Int

    var total: Int { live + movies + series }
}
