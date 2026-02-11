import Foundation

nonisolated enum StatusUpdateResult: Identifiable, Sendable {
    case success(workspaceName: String)
    case failure(workspaceName: String, error: String)

    var id: String {
        switch self {
        case .success(let name): return "success-\(name)"
        case .failure(let name, _): return "failure-\(name)"
        }
    }
}
