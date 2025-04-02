let baseTypes: [Any] = [
  Int.self,
  Double.self,
  String.self,
]

typealias TypeMap = [String: Bool]

func typeOf<T>(_ type: T.Type) -> TypeMap {
  [String(describing: type): true]
}

let none: TypeMap = baseTypes.flatMap { type in [String(describing: type): false] }.reduce([:]) {
  previous, current in previous.merging(current, uniquingKeysWith: { _, _ in true })
}

func hasType<T>(_ type: T.Type) -> TypeMap {
  none.merging(typeOf(type), uniquingKeysWith: { _, _ in true })
}

let int = hasType(Int.self)
let double = hasType(Double.self)
