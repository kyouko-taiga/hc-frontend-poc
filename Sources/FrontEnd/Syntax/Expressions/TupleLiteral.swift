import Archivist
import Utilities

/// The expression of a tuple literal.
public struct TupleLiteral: Expression {

  /// The elements of the literal.
  public let elements: [LabeledExpression]

  /// The site from which `self` was parsed.
  public let site: SourceSpan

}

extension TupleLiteral: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    let es = elements.map({ (e) in printer.show(e) })
    if es.count == 1 {
      return "(\(es[0]),)"
    } else {
      return "(\(list: es))"
    }
  }

}

extension TupleLiteral: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.elements = try archive.read([LabeledExpression].self, in: &context)
    self.site = try archive.read(SourceSpan.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(elements, in: &context)
    try archive.write(site, in: &context)
  }

}
