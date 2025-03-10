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

struct EffectType<Value> {
  let value: Value.Type
  let errors: [TaggedError.Type]
  let resources: [Resource.Type]
}

struct EffectType<Value> {
  let value: Value.Type
  let resources: [Resource.Type]
}

let prints = EffectType(
  value: Void.self,
  errors: [FooError.self, BarError.self],
  resources: [Console.self, Timer.self]
)

func foo() {
  let type = prints.errors[0].self

  let value = FooError()

  if value.self as type {
    print("???")
  }
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
