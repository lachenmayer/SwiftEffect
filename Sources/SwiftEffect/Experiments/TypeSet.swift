protocol Resource {
  typealias Tag = String

  static var tag: Tag { get }
}

struct ResourceContext {
  private let provided: [Resource.Tag: Resource]
  private let required: Set<Resource.Tag>

  static func empty() -> Self {
    ResourceContext(provided: [:], required: [])
  }

  func require(_ resource: Resource.Type) -> Self {
    // Already provided
    if provided[resource.tag] != nil { return self }
    var required = self.required
    required.insert(resource.tag)
    return Self(provided: provided, required: required)
  }

  func provide<R: Resource>(_ resource: R) -> Self {
    var provided = self.provided
    provided[R.tag] = resource
    var required = self.required
    required.remove(R.tag)
    return Self(provided: provided, required: required)
  }

  func get<R: Resource>(_ resource: R.Type) throws -> R {
    if let provided = provided[R.tag] as? R {
      return provided
    } else if required.contains(R.tag) {
      fatalError("Missing required resource \(R.tag) - required resources: \(required)")
    } else {
      fatalError("Trying to get a resource that was not required: \(R.tag)")
    }
  }
}

struct Console: Resource {
  static let tag = "Console"
  let print: (String) -> Void
}

typealias FooX = (String) -> Void

func foo() {
  let context = ResourceContext.empty()
  //  context.require(Console.self)
  print("\(FooX.Type.self)")
}
