import Archivist
import Utilities

/// The declaration of a type extension.
public struct ExtensionDeclaration: Declaration, Scope {

  /// The introducer of this declaration.
  public let introducer: Token

  /// The type being extended.
  public let extendee: ExpressionIdentity

  /// The members of the extension.
  public let members: [DeclarationIdentity]

  /// The site from which `self` was parsed.
  public let site: SourceSpan

  /// Returns a parsable representation of `self`, which is a node of `program`.
  public func show(readingChildrenFrom program: Program) -> String {
    let e = program.show(extendee)
    let ms = members.map(program.show(_:)).lazy
      .map(\.indented)
      .joined(separator: "\n")

    return """
    \(introducer.text) \(e) {
    \(ms)
    }
    """
  }

}

extension ExtensionDeclaration: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    fatalError()
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    fatalError()
  }

}
