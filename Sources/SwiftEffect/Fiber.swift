public struct Fiber<E: Effectful>: Sendable {
  private let task: Task<E.Val, E.Err>

  init(_ value: E) {
    task = Task<E.Val, E.Err> {
      try await value.value
    }
  }

  public var join: AnyEffect<E.Val, E.Err> {
    Effect.async {
      try await task.value
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

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Fiber<E>) -> Void) {
    scheduler.schedule { continuation(Fiber(effect)) }
  }
}
