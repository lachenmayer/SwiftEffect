# SwiftEffect

An experiment to implement an effect system similar to [zio](https://zio.dev/) or [Effect](https://effect.website/) in Swift.

This is definitely not usable by anyone else at this point, but my notes might be useful for anyone attempting something similar. (If you are, please do reach out to me!)

The dream is to achieve a "tri-functor" like `ZIO[R, E, A]` (Scala) or `Effect<A, E, R>` (TypeScript). This represents an effectful computation, which can either succeed with value `A`, or fail with error `E`, and additionally has access to the resources `R`. This represents an effectful computation as a value, which allows us to easily manipulate and compose smaller computations into bigger, more complex programs.

I am sorely missing this abstraction in Swift after experiencing how incredibly powerful it is, using Effect in TypeScript. The [Bow](https://bow-swift.io/) library has a similar [`EnvIO`](https://bow-swift.io/docs/dependency-management/side-effectful-dependency-management/) type, but this is several years old, and has not caught up with the latest Swift features.

## 2025-02-26: Initial `Effect<A>` functor

My hunch is that everything except dependency injection using `R` is relatively achievable: ZIO has already paved the way here, and the Scala and Swift type systems are not too dissimilar. Swift's biggest weakness here is lack of support for union types, but I think it should be possible to emulate some of this using protocols. For any service `Foo`, we can define the protocol `protocol HasFoo { var foo: Foo }`, and combine these using `typealias Resource = HasFoo & HasBar`.

The "ZIO from scratch" series is incredibly helpful: I followed along with [part 1](https://www.youtube.com/watch?v=wsTIcHxJMeQ), attempting to make the API more "Swifty" overall. Instead of traits and case classes, we have protocols and structs, but overall the solution looks very similar, and it's actually pretty Swifty!

I am trying to make `Effect` structs look a lot like SwiftUI's `View`. Instead of `var body: some View`, we have `func run(_ continuation: @Sendable @escaping (Value) -> Void)`:

```swift
public protocol Effectful: Sendable {
  associatedtype Value: Sendable

  func run(_ continuation: @Sendable @escaping (Value) -> Void)
}
```

We can then implement specific effects as simple structs, exactly like SwiftUI:

```swift
public struct Succeed<A: Sendable>: Effectful {
  let value: @Sendable () -> A

  public func run(_ continuation: (A) -> Void) {
    continuation(value())
  }
}
```

The basic `succeed`, `zip`, `map` and `flatMap` operators are easy to implement once this is up and running.

(Swift 6 `Sendable` annotations are absolutely everywhere, as you'd expect...)

I was hoping that we could implement a `@EffectBuilder` analagous to SwiftUI's `@ViewBuilder`, but it seems like it's impossible to implement a monadic bind with result builders ([see this thread from 2019](https://forums.swift.org/t/monadic-dsl-based-on-function-builders/25497), has anything changed since then?). More specifically, we would like to be able to extract the value from an effect, so that we don't need to `flatMap` over the value, eg:

```swift
// The dream:
let x: AnyEffect<Int> = effectBuilder { 
  let result = Effect.succeed(12)
  Effect.succeed(result * 2)
}

// The reality:
let x = effectBuilder { 
  let result = Effect.succeed(12)
  Effect.succeed(result * 2) // ERROR: Binary operator '*' cannot be applied to operands of type 'Succeed<Int>' and 'Int'
}
let works = Effect.succeed(12)
  .map { result in result * 2 }
```

Effect fakes monadic `do`-notation using [generators](https://effect.website/docs/getting-started/using-generators/), which Swift does not support, and zio uses Scala's [for comprehensions](https://zio.dev/overview/basic-operations/#for-comprehensions). This is a real shame. It feels like result builders were hacked together specifically for SwiftUI, and are not powerful enough to have any other real applications.

At least we can lift `Effect` into the "`async` monad" (lol), using `withCheckedContinuation`:

```swift
extension Effectful {
  public var value: Value {
    get async {
      await withCheckedContinuation { continuation in
        self.run { value in continuation.resume(returning: value) }
      }
    }
  }
}
```

This means we can at least use `await` without any hassle.

Anyway, even with this basic setup, we have all the basic primitives to write some real code:

```swift
@Test func example() async throws {
  let num = Effect.succeed(3)
  let str = Effect.succeed("hello")
  let eff = Effect.zip(num, str)
    .map { num, str in "got a number: \(num) and a string: \(str)" }
    .flatMap { str in
      Effect.async { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation(str)
        }
      }
    }
    .flatMap { delayed in Effect.succeed(print("here it is, finally: \(delayed)")) }
    .map { "success" }
  let x = await eff.value
  #expect(x == "success")
}
```

For now, this is effectively just a lazy `Task`, which is already not bad (though not terribly useful).

The type for `eff` is pretty crazy, so I implemented a type-erased `AnyEffect<A>`:

```swift
let eff: Map<FlatMap<FlatMap<Map<Zip<Succeed<Int>, Succeed<String>>, String>, Async<String>>, Succeed<()>>, String>

let erased: AnyEffect<String> = eff.erase()
```

Again, this is exactly the same as SwiftUI's `AnyView`, which is essential for writing any meaningfully composable SwiftUI code. I really wish protocols with generics weren't so obtuse in Swift. If I have a protocol `Effectful`, I would like to be able to write `Effectful<A>`, but this is not possible: I have to do some crazy gymnastics with `where` clauses in the type definitions, which is impossible in some cases. I also can't assign a protocol as a field in a struct, because this turns into `any Effectful`, losing the type parameter. So for any useful generic type, we have to manually derive the equivalent type-erased type, and use this everywhere we pass around these types. I wish the compiler could do this for us (we're effectively manually implementing dynamic dispatch here!).

I am going to try continuing along with the "ZIO from scratch" series, the next step is to implement basic fibers, so that it's possible to fork/join `Effect`s. I feel like this should be doable using `Task`s: Swift's task system is basically already a fiber runtime, so it shouldn't be too challenging to get a naïve implementation working.
