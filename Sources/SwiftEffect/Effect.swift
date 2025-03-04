public protocol Effectful: Sendable {
  associatedtype Val: Sendable
  associatedtype Err: Error

  typealias Res = Result<Val, Err>

  func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Res) -> Void)
}

public class EffectError: Error, @unchecked Sendable {}

extension Effectful where Err == Never {
  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Val) -> Void) {
    self.run(
      scheduler: scheduler,
      { value in continuation(value.get()) }
    )
  }
}

public struct AnyEffect<Val: Sendable, Err: Error>: Effectful {
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
  public var value: Val {
    get async throws(Err) {
      do {
        return try await withCheckedThrowingContinuation { continuation in
          self.run(scheduler: Scheduler.shared) { value in continuation.resume(with: value) }
        }
      } catch {
        throw error as! Err
      }
    }
  }
}
