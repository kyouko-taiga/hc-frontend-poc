import OrderedCollections
import Utilities

/// The application of a type abstraction.
public struct TypeApplication: TypeTree {

  /// The arguments of a type application.
  public typealias Arguments = OrderedDictionary<GenericParameter.ID, AnyTypeIdentity>

  /// The abstraction being applied.
  public var abstraction: AnyTypeIdentity

  /// The arguments of the application.
  public var arguments: Arguments

  /// Properties about `self`.
  public var properties: ValueProperties {
    arguments.values.reduce(abstraction.properties, { (a, i) in a.union(i.properties) })
  }

  /// Returns `self`, which is in `store`, with its parts transformed by `transform(_:_:)`.
  public func modified(
    in store: inout TypeStore,
    by transform: (inout TypeStore, AnyTypeIdentity) -> TypeTransformAction
  ) -> TypeApplication {
    let t = store.map(abstraction, transform)
    let x = arguments.mapValues({ (a) in store.map(a, transform) })
    return .init(abstraction: t, arguments: x)
  }

}

extension TypeApplication: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    "\(printer.show(abstraction))<\(printer.show(arguments.values))>"
  }

}
