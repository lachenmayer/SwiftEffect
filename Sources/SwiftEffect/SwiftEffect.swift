//protocol HasConsole {
//  var console: Console { get }
//}
//
//protocol Console {
//  func print(_ message: String) -> Effect<Void, Never, Any>
//}
//
//struct ConsoleLive: Console {
//  func print(_ message: String) -> Effect<Void, Never, Any> {
//    Effect { _ in Result.success(Swift.print(message)) }
//  }
//}

struct Effect<A>: Sendable {
  let run: @Sendable (_ continuation: (A) -> Void) -> Void
}

extension Effect {
  static func succeed(_ value: A) -> Effect<A> where A: Sendable {
    Effect { continuation in continuation(value) }
  }
}

let fakeEff = Effect.succeed(42)

func main() {
  fakeEff.run { value in print("hey, \(value)") }
}
