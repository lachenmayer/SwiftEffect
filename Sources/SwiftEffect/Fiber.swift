public struct Fiber<E: Effectful>: Sendable {
  private let task: Task<E.Res, Never>

  init(_ effect: E) {
    task = Task<E.Res, Never> {
      await effect.value
    }
  }

  public var join: AnyEffect<E.Val, E.Err> {
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
  public typealias Val = Fiber<E>
  public typealias Err = EffectError

  let effect: E

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Result<Fiber<E>, EffectError>) -> Void
  ) {
    scheduler.schedule { continuation(.success(Fiber(effect))) }
  }
}
