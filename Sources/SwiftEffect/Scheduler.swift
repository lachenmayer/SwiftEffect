typealias Continuation = @Sendable () -> Void

public struct Scheduler: Sendable {
  static let shared = Self()

  func schedule(_ continuation: @escaping Continuation) {
    Task { await MainActor.run { continuation() } }
  }
}
