import Foundation
import SwiftEffect
import Testing

@Test func basicOperators() async throws {
  let num = Effect.succeed(3)
  let str = Effect.succeed("hello")
  let eff = num.zip(str)
    .map { num, str in "got a number: \(num) and a string: \(str)" }
    .flatMap { str in
      Effect.async {
        try? await Task.sleep(for: .seconds(0.5))
        return str
      }
    }
    .flatMap { delayed in Effect.succeed(print("here it is, finally: \(delayed)")) }
    .map { "success" }

  let x = await eff.value
  #expect(x == "success")
}

@Test func forkJoin() async throws {
  let someAsyncWork = Effect.async {
    print("starting async work")
    try? await Task.sleep(for: .seconds(2))
    return 50
  }
  let one = someAsyncWork.fork
  let two = someAsyncWork.fork
  let result = one.zip(two)
    .flatMap { one, two in
      print("nice")
      return one.join.zip(two.join)
    }
  let value = await result.value
  #expect(value == (50, 50))
}

@Test func zipPar() async throws {
  let someAsyncWork = Effect.async {
    print("zipPar start: \(Date.now)")
    try? await Task.sleep(for: .seconds(2))
    return 50
  }
  let result = someAsyncWork.zipPar(someAsyncWork)
  let value = await result.value
  print("zipPar end: \(Date.now)")
  #expect(value == (50, 50))
}

@Test func stackSafety() async throws {
  await Effect.succeed(print("howdy")).repeat(times: 100000).value
}
