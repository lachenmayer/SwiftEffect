// - MARK: Constructors

public enum Effect {
  public static func success<A: Sendable>(_ value: @Sendable @autoclosure @escaping () -> A)
    -> Success<A>
  {
    Success(value: value)
  }

  public static func failure<E: EffectError>(_ value: @Sendable @autoclosure @escaping () -> E)
    -> Failure<E>
  {
    Failure(value: value)
  }

  public static func `async`<A: Sendable>(
    _ effect: @Sendable @escaping (_ continuation: @Sendable @escaping (A) -> Void) ->
      Void
  )
    -> Async<A, EffectError>
  {
    Async(effect: { continuation in
      effect({ value in continuation(.success(value)) })
    })
  }

  public static func `async`<A: Sendable, E: EffectError>(
    _ effect: @Sendable @escaping (_ continuation: @Sendable @escaping (Result<A, E>) -> Void) ->
      Void
  )
    -> Async<A, E>
  {
    Async(effect: effect)
  }

  public static func `async`<A: Sendable, E: EffectError>(
    _ asyncFn: @Sendable @escaping () async -> Result<A, E>
  ) -> Async<A, E> {
    Effect.async { continuation in
      Task {
        let value = await asyncFn()
        continuation(value)
      }
    }
  }
}

// - MARK: Combinators

extension Effectful {
  public func map<Out: Sendable>(
    _ f: @Sendable @escaping (Self.Val) -> Out
  )
    -> Map<Self, Out>
  {
    Map(effect: self, f: f)
  }

  public func flatMap<Out: Effectful>(
    _ f: @Sendable @escaping (Self.Val) -> Out
  )
    -> FlatMap<Self, Out>
  {
    FlatMap(effect: self, f: f)
  }

  public func flatten<A: Effectful>() -> FlatMap<Self, A> where Val == A {
    flatMap { $0 }
  }

  public func zip<Right: Effectful>(_ right: Right)
    -> AnyEffect<(Self.Val, Right.Val), Self.Err>
  {
    zipWith(right, { a, b in (a, b) }).erase()
  }

  public func zipWith<Right: Effectful, Out: Sendable, Err: EffectError>(
    _ right: Right,
    _ combine: @Sendable @escaping (Self.Val, Right.Val) -> Out
  ) -> AnyEffect<Out, Err> {
    self.flatMap { l in
      right.map { r in
        combine(l, r)
      }
    }.erase() as! AnyEffect<Out, Err>  // FIXME: This is probably wrong...
  }

  public func zipPar<Right: Effectful, Err: EffectError>(_ right: Right)
    -> AnyEffect<(Self.Val, Right.Val), Err>
  {
    self.fork.zipWith(right.fork) { left, right in
      left.join.zip(right.join)
    }
    .flatten()
    .erase() as! AnyEffect<(Self.Val, Right.Val), Err>  // FIXME: This is probably wrong...
  }

  public func then<Next: Effectful>(_ next: @autoclosure @Sendable @escaping () -> Next)
    -> AnyEffect<Next.Val, Next.Err>
  {
    self.zipWith(Effect.success(next()).flatten()) { _, value in value }
      .erase()
  }

  public func `repeat`(times: Int) -> AnyEffect<Void, EffectError> {
    if times <= 0 { return Effect.success(()).erase() }
    return self.then(self.repeat(times: times - 1))
  }
}

public struct Success<A: Sendable>: Effectful {
  public typealias Val = A
  public typealias Err = EffectError

  let value: @Sendable () -> A

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Res) -> Void
  ) {
    scheduler.schedule { continuation(.success(value())) }
  }
}

public struct Failure<E: EffectError>: Effectful {
  public typealias Val = Never
  public typealias Err = EffectError

  let value: @Sendable () -> E

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Res) -> Void
  ) {
    scheduler.schedule { continuation(.failure(value())) }
  }
}

public struct Async<A: Sendable, E: EffectError>: Effectful {
  public typealias Val = A
  public typealias Err = E

  let effect: @Sendable (_ continuation: @Sendable @escaping (Res) -> Void) -> Void

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Res) -> Void
  ) {
    scheduler.schedule { effect(continuation) }
  }
}

public struct Map<In: Effectful, Out: Sendable>: Effectful {
  public typealias Val = Out
  public typealias Err = In.Err

  let effect: In
  let f: @Sendable (In.Val) -> Out

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Result<Out, In.Err>) -> Void
  ) {
    effect.run(scheduler: scheduler) { value in
      scheduler.schedule {
        continuation(value.map { f($0) })
      }
    }
  }
}

public struct FlatMap<In: Effectful, Out: Effectful>: Effectful {
  public typealias Val = Out.Val
  public typealias Err = Out.Err

  let effect: In
  let f: @Sendable (In.Val) -> Out

  public func run(
    scheduler: Scheduler,
    _ continuation: @Sendable @escaping (Out.Res) -> Void
  ) {
    effect.run(scheduler: scheduler) { value in
      scheduler.schedule {
        switch value {
        case .success(let val):
          f(val).run(scheduler: scheduler, continuation)
        case .failure(let err):
          if let expectedError = err as? Out.Err {
            continuation(Result.failure(expectedError))
          } else {
            continuation(Result.failure(Out.Err.die("Could not cast error")))
          }
        }
      }
    }
  }
}
