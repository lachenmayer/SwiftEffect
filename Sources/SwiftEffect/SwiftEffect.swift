public protocol Effectful: Sendable {
  associatedtype Value: Sendable

  func run(_ continuation: @Sendable @escaping (Value) -> Void)
}

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

  public static func zip<A: Effectful, B: Effectful>(_ a: A, _ b: B)
    -> Zip<A, B>
  {
    Zip(a: a, b: b)
  }

  public static func zipPar<A: Effectful, B: Effectful>(_ a: A, _ b: B)
    -> AnyEffect<(A.Value, B.Value)>
  {
    Effect.zip(a.fork, b.fork)
      .flatMap { aFiber, bFiber in Effect.zip(aFiber.join, bFiber.join) }
      .erase()
  }
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
}

public struct Succeed<A: Sendable>: Effectful {
  let value: @Sendable () -> A

  public func run(_ continuation: (A) -> Void) {
    continuation(value())
  }
}

public struct Async<A: Sendable>: Effectful {
  let effect: @Sendable (_ continuation: @Sendable @escaping (A) -> Void) -> Void

  public func run(_ continuation: @Sendable @escaping (A) -> Void) {
    effect(continuation)
  }
}

public struct Map<In: Effectful, Out: Sendable>: Effectful {
  let effect: In
  let f: @Sendable (In.Value) -> Out

  public func run(_ continuation: @Sendable @escaping (Out) -> Void) {
    effect.run { value in
      continuation(f(value))
    }
  }
}

public struct FlatMap<In: Effectful, Out: Effectful>: Effectful {
  let effect: In
  let f: @Sendable (In.Value) -> Out

  public func run(_ continuation: @Sendable @escaping (Out.Value) -> Void) {
    effect.run { value in
      f(value).run(continuation)
    }
  }
}

public struct Zip<A: Effectful, B: Effectful>: Effectful {
  let a: A
  let b: B

  public func run(_ continuation: @Sendable @escaping ((A.Value, B.Value)) -> Void) {
    a.run { aValue in
      b.run { bValue in
        continuation((aValue, bValue))
      }
    }
  }
}

// MARK: - Fibers

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
