/// The identity of a lexical scope.
public struct ScopeIdentity: Hashable {

  /// The internal representation of this identity.
  private var representation: AnySyntaxIdentity

  /// Creates an instance representing the scope formed by `file`.
  public init(file: Program.SourceFileIdentity) {
    self.representation = .scope(of: file)
  }

  /// Creates an instance representing the scope formed by `syntax`.
  public init<T: Scope>(node: T.ID) {
    self.representation = node.erased
  }

  /// Creates an instance representing the scope formed by `syntax`, assuming it is a scope.
  public init(uncheckedFrom node: AnySyntaxIdentity) {
    self.representation = node
  }

  /// The source file containing this scope.
  public var file: Program.SourceFileIdentity {
    representation.file
  }

  /// The syntax tree that `self` represents, or `nil` if `self` represents a file.
  public var node: AnySyntaxIdentity? {
    if representation.offset != UInt32.max {
      return .init(uncheckedFrom: representation)
    } else {
      return nil
    }
  }

}
