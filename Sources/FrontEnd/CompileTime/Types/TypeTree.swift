/// The tree representation of a Hylo type.
public protocol TypeTree: Hashable, Showable, Sendable {

  /// Properties about `self` and its children, which are types in `program`.
  var properties: ValueProperties { get }

  /// Returns `self`, which is in `store`, with its parts transformed by `transform(_:_:)`.
  func modified(
    in store: inout TypeStore,
    by transform: (inout TypeStore, AnyTypeIdentity) -> TypeTransformAction
  ) -> Self

}

extension TypeTree {

  /// The identity of an instance of `Self`.
  public typealias ID = ConcreteTypeIdentity<Self>

  /// `true` iff `self` is a type variable.
  public var isVariable: Bool {
    self is TypeVariable
  }

  /// Returns `true` iff `self` has the same tree representation as `other`.
  public func equals(_ other: any TypeTree) -> Bool {
    self == other as? Self
  }

  /// Returns `self`, which is in `store`, with its parts transformed by `transform(_:_:)`.
  public func modified(
    in store: inout TypeStore,
    by transform: (inout TypeStore, AnyTypeIdentity) -> TypeTransformAction
  ) -> Self { self }

}
