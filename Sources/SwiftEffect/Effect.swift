public protocol Effectful: Sendable {
  associatedtype Value: Sendable

  func run(_ continuation: @Sendable @escaping (Value) -> Void)
}

public struct AnyEffect<A: Sendable>: Effectful {
  public typealias Value = A

  private let _run: @Sendable (_ continuation: @Sendable @escaping (A) -> Void) -> Void

  init<E: Effectful>(_ effect: E) where E.Value == A {
    self._run = effect.run
  }

  public func run(_ continuation: @Sendable @escaping (A) -> Void) {
    _run(continuation)
  }
}

extension Effectful {
  public func erase() -> AnyEffect<Value> {
    AnyEffect(self)
  }
}

extension Effectful {
  public var value: Value {
    get async {
      await withCheckedContinuation { continuation in
        self.run { value in continuation.resume(returning: value) }
      }
    }
  }
}
