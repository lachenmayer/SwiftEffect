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
    _ f: @Sendable @escaping (Self.Value) -> Out
  )
    -> Map<Self, Out>
  {
    Map(effect: self, f: f)
  }

  public func flatMap<Out: Effectful>(
    _ f: @Sendable @escaping (Self.Value) -> Out
  )
    -> FlatMap<Self, Out>
  {
    FlatMap(effect: self, f: f)
  }

  public func flatten<A: Effectful>() -> FlatMap<Self, A> where Value == A {
    flatMap { $0 }
  }

  public func zip<Right: Effectful>(_ right: Right)
    -> Zip<Self, Right>
  {
    ZipWith(left: self, right: right, combine: { a, b in (a, b) })
  }

  public func zipWith<Right: Effectful, C: Sendable>(
    _ right: Right, _ combine: @Sendable @escaping (Self.Value, Right.Value) -> C
  ) -> ZipWith<Self, Right, C> {
    ZipWith(left: self, right: right, combine: combine)
  }

  public func zipPar<Right: Effectful>(_ right: Right)
    -> AnyEffect<(Self.Value, Right.Value)>
  {
    self.fork.zipWith(right.fork) { left, right in
      left.join.zip(right.join)
    }
    .flatten()
    .erase()
  }

  public func then<Next: Effectful>(_ next: @autoclosure @Sendable @escaping () -> Next)
    -> AnyEffect<Next.Value>
  {
    self.zipWith(Effect.succeed(next()).flatten()) { _, value in value }
      .erase()
  }

  public func `repeat`(times: Int) -> AnyEffect<Void> {
    if times <= 0 { return Effect.succeed(()).erase() }
    return self.then(self.repeat(times: times - 1))
  }
}

public struct Succeed<A: Sendable>: Effectful {
  let value: @Sendable () -> A

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (A) -> Void) {
    scheduler.schedule { continuation(value()) }
  }
}

public struct Async<A: Sendable>: Effectful {
  let effect: @Sendable (_ continuation: @Sendable @escaping (A) -> Void) -> Void

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (A) -> Void) {
    scheduler.schedule { effect(continuation) }
  }
}

public struct Map<In: Effectful, Out: Sendable>: Effectful {
  let effect: In
  let f: @Sendable (In.Value) -> Out

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Out) -> Void) {
    scheduler.schedule {
      effect.run(scheduler: scheduler) { value in
        continuation(f(value))
      }
    }
  }
}

public struct FlatMap<In: Effectful, Out: Effectful>: Effectful {
  let effect: In
  let f: @Sendable (In.Value) -> Out

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Out.Value) -> Void) {
    scheduler.schedule {
      effect.run(scheduler: scheduler) { value in
        f(value).run(scheduler: scheduler, continuation)
      }
    }
  }
}

public typealias Zip<Left: Effectful, Right: Effectful> = ZipWith<
  Left, Right, (Left.Value, Right.Value)
>

public struct ZipWith<Left: Effectful, Right: Effectful, Out: Sendable>: Effectful {
  let left: Left
  let right: Right
  let combine: @Sendable (Left.Value, Right.Value) -> Out

  public func run(scheduler: Scheduler, _ continuation: @Sendable @escaping (Out) -> Void) {
    scheduler.schedule {
      left.run(scheduler: scheduler) { aValue in
        scheduler.schedule {
          right.run(scheduler: scheduler) { bValue in
            continuation(combine(aValue, bValue))
          }
        }
      }
    }
  }
}
