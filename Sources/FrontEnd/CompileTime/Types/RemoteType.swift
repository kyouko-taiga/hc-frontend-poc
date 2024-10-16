/// The type of a value projected from another context.
public struct RemoteType: TypeTree {

  /// The type of the projected value.
  public let projectee: AnyTypeIdentity

  /// The capabilities of the projection.
  public let access: AccessEffect

  /// Properties about `self`.
  public var properties: ValueProperties {
    projectee.properties
  }

  /// Returns a parsable representation of `self`, which is a type in `program`.
  public func show(readingChildrenFrom program: Program) -> String {
    "\(access) \(program.show(projectee))"
  }

}
