import Archivist

/// The declaration of a structure.
public struct StructDeclaration: TypeDeclaration, Scope {

  /// The introducer of this declaration.
  public let introducer: Token

  /// The name of the declared struct.
  public let identifier: Parsed<String>

  /// The compile-time parameters of the struct.
  public let staticParameters: StaticParameters

  /// The members of the declared struct.
  public let members: [DeclarationIdentity]

  /// The site from which `self` was parsed.
  public let site: SourceSpan

  /// Returns a parsable representation of `self`, which is a node of `program`.
  public func show(readingChildrenFrom program: Program) -> String {
    let w = staticParameters.isEmpty ? "" : program.show(staticParameters)
    let m = members.map(program.show(_:)).lazy
      .map(\.indented)
      .joined(separator: "\n")

    return """
    struct\(w) \(identifier) {
    \(m)
    }
    """
  }

}

extension StructDeclaration: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.introducer = try archive.read(Token.self, in: &context)
    self.identifier = try archive.read(Parsed<String>.self, in: &context)
    self.staticParameters = try archive.read(StaticParameters.self, in: &context)
    self.members = try archive.read([DeclarationIdentity].self, in: &context)
    self.site = try archive.read(SourceSpan.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(introducer, in: &context)
    try archive.write(identifier, in: &context)
    try archive.write(staticParameters, in: &context)
    try archive.write(members, in: &context)
    try archive.write(site, in: &context)
  }

}
