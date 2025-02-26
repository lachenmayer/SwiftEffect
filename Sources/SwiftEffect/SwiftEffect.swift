public protocol Effectful: Sendable {
  associatedtype Value: Sendable
}

extension Effectful {
  func run(_ continuation: @Sendable @escaping (Value) -> Void) {
    switch self {
    case let succeed as Succeed<Value>:
      continuation(succeed.getValue())
    case let asyncEffect as Async<Value>:
      asyncEffect.effect(continuation)
    case let map as Map<Sendable, Value>:
      map.effect.run { value in
        continuation(map.f(value))
      }
    case let flatMap as FlatMap<Sendable, Self>:
      flatMap.effect.run { value in
        flatMap.f(value).run(continuation)
      }
    case let zip as Zip<Sendable, Sendable>:
      zip.a.run { aValue in
        zip.b.run { bValue in
          continuation((aValue, bValue))
        }
      }
    default:
      // do nothing
    }
  }
}

public enum Effect {
  public static func succeed<A: Sendable>(_ value: @Sendable @autoclosure @escaping () -> A)
    -> Succeed<A>
  {
    Succeed(getValue: value)
  }

  public static func `async`<A: Sendable>(
    _ effect: @Sendable @escaping (_ continuation: @Sendable @escaping (A) -> Void) -> Void
  )
    -> Async<A>
  {
    Async(effect: effect)
  }

  public static func zip<A: Effectful, B: Effectful>(_ a: A, _ b: B)
    -> Zip<A, B>
  {
    Zip(a: a, b: b)
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
    -> Map<Self.Value, Out>
  {
    Map(effect: self.erase(), f: f)
  }

  public func flatMap<Out: Effectful>(
    _ f: @Sendable @escaping (Self.Value) -> Out
  )
    -> FlatMap<Self.Value, Out>
  {
    FlatMap(effect: self.erase(), f: f)
  }
}

public struct Succeed<A: Sendable>: Effectful {
  public typealias Value = A

  let getValue: @Sendable () -> A
}

public struct Async<A: Sendable>: Effectful {
  public typealias Value = A

  let effect: @Sendable (_ continuation: @Sendable @escaping (A) -> Void) -> Void
}

public struct Map<In: Sendable, Out: Sendable>: Effectful {
  public typealias Value = Out

  let effect: AnyEffect<In>
  let f: @Sendable (In) -> Out
}

public struct FlatMap<In: Sendable, Out: Effectful>: Effectful {
  public typealias Value = Out.Value

  let effect: AnyEffect<In>
  let f: @Sendable (In) -> Out
}

public struct Zip<A: Sendable, B: Sendable>: Effectful {
  public typealias Value = (A, B)

  let a: AnyEffect<A>
  let b: AnyEffect<B>

  //  public func run(_ continuation: @Sendable @escaping ((A.Value, B.Value)) -> Void) {
 
  //  }
}
