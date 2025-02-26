import Foundation
import SwiftEffect
import Testing

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
