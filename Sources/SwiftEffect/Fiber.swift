public struct Fiber<E: Effectful>: Sendable {
  private let task: Task<E.Value, Never>

  init(_ value: E) {
    task = Task {
      await value.value
    }
  }

  public var join: AnyEffect<E.Value> {
    Effect.async {
      await task.value
    }.erase()
  }
}

extension Effectful {
  public var fork: Fork<Self> {
    Fork(effect: self)
  }
}

public struct Fork<E: Effectful>: Effectful {
  let effect: E

  public func run(_ continuation: @Sendable @escaping (Fiber<E>) -> Void) {
    continuation(Fiber(effect))
  }
}
