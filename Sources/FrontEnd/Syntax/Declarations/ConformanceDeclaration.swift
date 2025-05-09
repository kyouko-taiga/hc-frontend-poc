import Archivist

/// The declaration of a conformance of a type to a trait.
public struct ConformanceDeclaration: TypeExtendingDeclaration {

  /// The introducer of this declaration.
  ///
  /// This token is a `given` keyword if the conformance is declared on its own, or a colon if it
  /// is "adjunct" to a struct. In the latter case, the conformance declaration has no parameters
  /// and no members; those belong to the struct declaration.
  public let introducer: Token

  /// The compile-time parameters of the conformance.
  public let staticParameters: StaticParameters

  /// The expression of the witness defined by the declaration.
  public let witness: StaticCall.ID

  /// The members of the declaration.
  public let members: [DeclarationIdentity]

  /// The site from which `self` was parsed.
  public let site: SourceSpan

  /// Returns `true` iff `self` is a context bound in a struct declaration.
  public var isAdjunct: Bool {
    introducer.tag == .colon
  }

}

extension ConformanceDeclaration: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    let sugared = printer.program.seenAsConformanceTypeExpression(witness)!

    var result = "given"
    if !staticParameters.isEmpty {
      result.append(" " + printer.show(staticParameters))
    }

    result.append(" \(printer.show(sugared.conformer)): \(printer.show(sugared.concept))")
    if !sugared.arguments.isEmpty {
      result.append("<\(printer.show(sugared.arguments))>")
    }

    result.append(" {\n")
    for m in members { result.append(printer.show(m).indented + "\n") }
    result.append("}")

    return result
  }

}

extension ConformanceDeclaration: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.introducer = try archive.read(Token.self, in: &context)
    self.staticParameters = try archive.read(StaticParameters.self, in: &context)
    self.witness = try archive.read(StaticCall.ID.self, in: &context)
    self.members = try archive.read([DeclarationIdentity].self, in: &context)
    self.site = try archive.read(SourceSpan.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(introducer, in: &context)
    try archive.write(staticParameters, in: &context)
    try archive.write(witness, in: &context)
    try archive.write(members, in: &context)
    try archive.write(site, in: &context)
  }

}
