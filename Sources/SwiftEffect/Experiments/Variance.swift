struct Marker<T> {}

struct Covariant<T> {
  private let marker: Marker<() -> T> = Marker()
}

struct Contravariant<T> {
  private let marker: Marker<(T) -> Void> = Marker()
}

struct Foo<T> {
  let x: T
  private let marker: Contravariant<T> = Contravariant()
}

enum Eff<A, E, R> {
  private static var val: Covariant<A> { Covariant() }
  private static var err: Covariant<E> { Covariant() }
  private static var ret: Contravariant<R> { Contravariant() }

  case succeed(A)
  case fail(E)
}

struct SomeError: Error {}
struct OtherError: Error {}

protocol FooError: Error {}
protocol BarError: FooError {}

func x() {
}
