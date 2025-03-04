// - MARK: Constructors

public enum Effect {
  public static func succeed<A: Sendable>(_ value: @Sendable @autoclosure @escaping () -> A)
    -> Succeed<A>
  {
    Succeed(value: value)
  }

  public static func `async`<A: Sendable>(
    _ effect: @Sendable @escaping (_ continuation: @Sendable @escaping (A) -> Void) -> Void
  )
    -> Async<A>
  {
    Async(effect: effect)
  }

  public static func `async`<A: Sendable>(_ asyncFn: @Sendable @escaping () async -> A) -> Async<A>
  {
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
    -> Zip<Self, Right>
  {
    ZipWith(left: self, right: right, combine: { a, b in (a, b) })
  }

  public func zipWith<Right: Effectful, E1: EffectError, C: Sendable>(
    _ right: Right, _ combine: @Sendable @escaping (Self.Val, Right.Val) -> C
  ) -> AnyEffect<C, E> where Right.Err: EffectError, Right.Err: E1 {
    ZipWith(left: self, right: right, combine: combine)
  }

  public func zipPar<Right: Effectful>(_ right: Right)
    -> AnyEffect<(Self.Value, Right.Value), Never>
  {
    self.fork.zipWith(right.fork) { left, right in
      left.join.zip(right.join)
    }
    .flatten()
    .erase()
  }

  public func then<Next: Effectful>(_ next: @autoclosure @Sendable @escaping () -> Next)
    -> AnyEffect<Next.Value, Next.Err>
  {
    self.zipWith(Effect.succeed(next()).flatten()) { _, value in value }
      .erase()
  }

  public func `repeat`(times: Int) -> AnyEffect<Void, Never> {
    if times <= 0 { return Effect.succeed(()).erase() }
    return self.then(self.repeat(times: times - 1))
  }
}

public struct Succeed<A: Sendable>: Effectful {
  public typealias Val = A
  public typealias Err = Never

  let value: @Sendable () -> A

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (A) -> Void) {
    scheduler.schedule { continuation(value()) }
  }
}

public struct Async<A: Sendable>: Effectful {
  public typealias Val = A
  public typealias Err = Never

  let effect: @Sendable (_ continuation: @Sendable @escaping (A) -> Void) -> Void

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (A) -> Void) {
    scheduler.schedule { effect(continuation) }
  }
}

public struct Map<In: Effectful, Out: Sendable>: Effectful {
  public typealias Val = Out
  public typealias Err = In.Err

  let effect: In
  let f: @Sendable (In.Val) -> Out

  public func run(
    scheduler: Scheduler, _ continuation: @Sendable @escaping (Result<Out, In.Err>) -> Void
  ) {
    effect.run(scheduler: scheduler) { value in
      scheduler.schedule {
        continuation(value.map { f($0) })
      }
    }
  }
}

public struct FlatMap<In: Effectful, Out: Effectful>: Effectful where In.Err == Out.Err {
  public typealias Val = Out.Val
  public typealias Err = Out.Err

  let effect: In
  let f: @Sendable (In.Val) -> Out

  public func run(
    scheduler: Scheduler, _ continuation: @Sendable @escaping (Out.Res) -> Void
  ) {
    effect.run(scheduler: scheduler) { value in
      scheduler.schedule {
        switch value {
        case .success(let val): f(val).run(scheduler: scheduler, continuation)
        case .failure(let err): continuation(Result.failure(err))
        }
      }
    }
  }
}
