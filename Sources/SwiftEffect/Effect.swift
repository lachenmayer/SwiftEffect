public protocol Effectful: Sendable {
  associatedtype Val: Sendable
  associatedtype Err: EffectError

  typealias Res = Result<Val, Err>

  func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Res) -> Void)
}

open class EffectError: Error, @unchecked Sendable {
  public let tag: String
  public let message: String

  public required init(tag: String, message: String) {
    self.tag = tag
    self.message = message
  }

  public static func die(_ message: String) -> Self {
    Self(tag: "@SwiftEffect/die", message: message)
  }
}

public struct AnyEffect<Val: Sendable, Err: EffectError>: Effectful {
  public typealias Val = Val
  public typealias Err = Err

  private let _run:
    @Sendable (
      _ scheduler: Scheduler, _ continuation: @Sendable @escaping (Res) -> Void
    ) ->
      Void

  init<Eff: Effectful>(_ effect: Eff) where Eff.Val == Val, Eff.Err == Err {
    self._run = effect.run
  }

  public func run(
    scheduler: Scheduler, _ continuation: @Sendable @escaping (Res) -> Void
  ) {
    _run(scheduler, continuation)
  }
}

extension Effectful {
  public func erase() -> AnyEffect<Val, Err> {
    AnyEffect(self)
  }
}

extension Effectful {
  public var value: Result<Val, Err> {
    get async {
      await withCheckedContinuation { continuation in
        self.run(scheduler: Scheduler.shared) { value in continuation.resume(returning: value) }
      }
    }
  }
}
