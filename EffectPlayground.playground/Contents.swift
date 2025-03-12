protocol Tagged {
  typealias Tag = String
  static var tag: Tag { get }
}

protocol Resource: Tagged {}

protocol TaggedError: Tagged, Error {}

struct ResourceContext {
  private let provided: [Resource.Tag: Resource]

  struct NotProvidedError: TaggedError {
    static let tag = "NotProvidedError"
    let resource: Resource.Tag
  }

  static func empty() -> Self {
    ResourceContext(provided: [:])
  }

  func provide<R: Resource>(_ resource: R) -> Self {
    var provided = self.provided
    provided[R.tag] = resource
    return Self(provided: provided)
  }

  func get<R: Resource>(_ resource: R.Type) throws -> R {
    if let provided = provided[R.tag] as? R {
      return provided
    } else {
      throw NotProvidedError(resource: R.tag)
    }
  }
}

struct Console: Resource {
  static let tag = "Console"
  let print: (String) -> Void
}

struct Timer: Resource {
  static let tag = "Timer"
  let now: () -> UInt64
}

func helloWorld(context: ResourceContext) {
  let console = try! context.get(Console.self)
  console.print("Hello!")
}

let resources: [Resource.Type] = [Console.self, Timer.self]

struct FooError: TaggedError {
  static let tag = "FooError"
}
struct BarError: TaggedError {
  static let tag = "BarError"
}

let errors: [Error.Type] = [FooError.self, BarError.self]

struct EffectType {
  let values: [Any.Type]
  let errors: [TaggedError.Type]
  let resources: [Resource.Type]

  func join(_ other: EffectType) -> EffectType {
    var values = self.values
    for value in other.values where !values.contains(where: { $0 == value }) {
      values.append(value)
    }
    var errors = self.errors
    for error in other.errors where !errors.contains(where: { $0 == error }) {
      errors.append(error)
    }
    var resources = self.resources
    for resource in other.resources where !resources.contains(where: { $0 == resource }) {
      resources.append(resource)
    }
    return EffectType(values: values, errors: errors, resources: resources)
  }
}

// quadratic set operations for da hax
// doesn't work because types aren't equatable - we _could_ use ObjectIdentifier + dict to implement sets
//extension Array where Element {
//  func set() -> Self {
//    var values = Self()
//    for value in self where !values.contains(where: { $0 == value }) {
//      values.append(value)
//    }
//    return values
//  }
//
//  func union(_ other: Self) -> Self {
//    (self + other).set()
//  }
//
//  func intersection(_ other: Self) -> Self {
//    var values = Self()
//    for value in self where other.contains(where: { $0 == value }) {
//      values.append(value)
//    }
//    return values.set()
//  }
//}

let prints = EffectType(values: [Void.self], errors: [], resources: [Console.self])

struct NoSuchElementError: TaggedError {
  static let tag = "NoSuchElementError"
}

let maybeInt = EffectType(values: [Int.self], errors: [NoSuchElementError.self], resources: [])

func typeCheck<ToCheck>(_ value: ToCheck, _ types: [Any.Type]) -> Bool {
  for type in types where ToCheck.self == type { return true }
  return false
}

let x = typeCheck(5, [Int.self, String.self]) == true

func foo() {
  print(typeCheck([], [Int.self, String.self]))
}
foo()

let consoleLive = Console(print: { print($0) })
let context = ResourceContext.empty().provide(consoleLive)

helloWorld(context: context)

func extract<In, Out>(_ f: (In) -> Out) -> (In.Type, Out.Type) {
  (In.self, Out.self)
}

func x(_ x: String) -> Int { x.count }
let string = extract(x).0

enum Either<Left, Right> {
  case left(Left)
  case right(Right)

  var left: Left? {
    if case let .left(l) = self { return l }
    return nil
  }
  var right: Right? {
    if case let .right(r) = self { return r }
    return nil
  }
}

typealias Union2_<A, B> = Union2<A, B, ()>

//struct Union2<A, B, C> {
//  let a: (A) -> C
//  let b: (B) -> C
//  
//  init(_ a: @escaping (A) -> C, _ b: @escaping (B) -> C) {
//    self.a = a
//    self.b = b
//  }
//  
//  func get(_ value: A) -> C {
//    a(value)
//  }
//  func get(_ value: B) -> C {
//    b(value)
//  }
//}
//
//let union2 = Union2(
//  { (n: Int) in "\(n)" },
//  { (str: String) in str }
//)
//let unions = union2.get(5) == union2.get("5")
//
//struct Null {
//  static let null = Self()
//  private init() {}
//}
//
//func optionUnion<T>() -> Union2<T, Null, Optional<T>> {
//  Union2({ $0 }, { _ in nil })
//}
//
//func eitherUnion<A, B>() -> Union2<A, B, Either<A, B>> {
//  Union2({ .left($0) }, { .right($0) })
//}


enum Union2<A, B> {
  
  
  static func assign(_ value: A) -> Union2<A, B> {
    
  }
  
}
