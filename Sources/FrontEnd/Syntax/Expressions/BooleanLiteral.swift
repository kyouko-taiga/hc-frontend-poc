import Archivist

/// The expression of a Boolean literal.
public struct BooleanLiteral: Expression {

  /// The site from which `self` was parsed.
  public let site: SourceSpan

  /// The value of the literal.
  public var value: Bool { site.text == "true" }

}

extension BooleanLiteral: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    value.description
  }

}

extension BooleanLiteral: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.site = try archive.read(SourceSpan.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(site, in: &context)
  }

}
