typealias Run<A> = @Sendable (_ continuation: (A) -> Void) -> Void

protocol Effect: Sendable {
  associatedtype Value: Sendable
  var run: Run<Value> { get }
}

// succeed

struct succeed<A: Sendable>: Effect {
  let run: Run<A>

  init(_ value: @Sendable @autoclosure @escaping () -> A) {
    run = { continuation in continuation(value()) }
  }
}

let testSucceed = succeed(42)

testSucceed.run { value in print("hey, \(value)") }

// zip

struct zip<A: Effect, B: Effect>: Effect {
  let run: Run<(A.Value, B.Value)>

  init(_ a: A, _ b: B) {
    self.run = { continuation in
      a.run { aValue in
        b.run { bValue in
          continuation((aValue, bValue))
        }
      }
    }
  }
}

let testZip = zip(succeed(1), succeed("hi"))

testZip.run { (a, b) in print("\(a), \(b)") }

// map

struct map<In: Effect, Out: Sendable>: Effect {
  let run: Run<Out>

  init(_ effect: In, _ f: @Sendable @escaping (In.Value) -> Out) {
    self.run = { continuation in
      effect.run { value in
        continuation(f(value))
      }
    }
  }
}

let testMap = map(testZip) { a, b in "\(a + 1) - \(b)" }
testMap.run { print($0) }

// flatMap

//func flatMap<In: Effect, Out: Effect>(_ effect: In, _ f: @Sendable @escaping (In.Value) -> Out) -> FlatMap<In, Out> {
//  FlatMap(effect, f)
//}

struct flatMap<In: Effect, Out: Effect>: Effect {
  let run: Run<Out.Value>

  init(_ effect: In, _ f: @Sendable @escaping (In.Value) -> Out) {
    self.run = { continuation in
      effect.run { value in
        f(value).run(continuation)
      }
    }
  }
}

enum Console {
  static let print = { @Sendable (message: String) in succeed(Swift.print(message)) }
}

flatMap(testZip) { value in
  Console.print("flatMapped: \(value)")
}.run {}

struct asyncEffect<A: Sendable>: Effect {
  let run: Run<A>

  init(_ run: @escaping Run<A>) {
    self.run = run
  }
}

asyncEffect { continuation in
  continuation(2)
}
