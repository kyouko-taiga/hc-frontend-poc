/// An entity built in the compiler.
public enum BuiltinEntity: Hashable, Sendable {

  /// The witness of a coercion.
  case coercion

  /// A built-in type alias.
  case alias

}
