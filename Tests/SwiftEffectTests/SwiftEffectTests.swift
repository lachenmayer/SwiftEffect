import Foundation
import SwiftEffect
import Testing

@Test func basicOperators() async throws {
  let num = Effect.success(3)
  let str = Effect.success("hello")
  let eff = num.zip(str)
    .map { num, str in "got a number: \(num) and a string: \(str)" }
    .flatMap { str in
      Effect.async {
        try? await Task.sleep(for: .seconds(0.5))
        return .success(str)
      }
    }
    .flatMap { delayed in Effect.success(print("here it is, finally: \(delayed)")) }
    .map { "success" }

  let x = try await eff.value.get()
  #expect(x == "success")
}

@Test func forkJoin() async throws {
  let someAsyncWork = Effect.async {
    print("starting async work")
    try? await Task.sleep(for: .seconds(2))
    return .success(50)
  }
  let one = someAsyncWork.fork
  let two = someAsyncWork.fork
  let result = one.zip(two)
    .flatMap { one, two in
      print("nice")
      return one.join.zip(two.join)
    }
  let value = try await result.value.get()
  #expect(value == (50, 50))
}

@Test func zipPar() async throws {
  let someAsyncWork = Effect.async {
    print("zipPar start: \(Date.now)")
    try? await Task.sleep(for: .seconds(2))
    return .success(50)
  }
  let result = someAsyncWork.zipPar(someAsyncWork)
  let value = try await result.value.get()
  print("zipPar end: \(Date.now)")
  #expect(value == (50, 50))
}

@Test func stackSafety() async throws {
  let result = await Effect.success(print("howdy")).repeat(times: 100000).value
  print("result: \(result)")
}

@Test func failure() async throws {
  class SomeError: EffectError, @unchecked Sendable {
    init(_ message: String) {
      super.init(tag: "SomeError", message: message)
    }

    required init(tag: String, message: String) {
      super.init(tag: tag, message: message)
    }
  }

  class SubError: SomeError, @unchecked Sendable {
    override init(_ message: String) {
      super.init(tag: "SubError", message: message)
    }

    required init(tag: String, message: String) {
      super.init(tag: tag, message: message)
    }
  }

  let effect = Effect.failure(SubError("x"))
  switch await effect.value {
  case .success:
    #expect(Bool(false))
  case .failure(let error):
    #expect(error is SubError)
    #expect(error is SomeError)
    #expect(error.tag == "SubError")
  }
}
