import Archivist

/// A pattern that matches tuples.
public struct TuplePattern: Pattern {

  /// The elements of the pattern.
  public let elements: [LabeledPattern]

  /// The site from which `self` was parsed.
  public let site: SourceSpan

  /// Returns a parsable representation of `self`, which is a node of `program`.
  public func show(readingChildrenFrom program: Program) -> String {
    let es = elements.map(program.show(_:))
    if es.count == 1 {
      return "(\(es[0]),)"
    } else {
      return "(\(list: es))"
    }
  }

}

extension TuplePattern: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.elements = try archive.read([LabeledPattern].self, in: &context)
    self.site = try archive.read(SourceSpan.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(elements, in: &context)
    try archive.write(site, in: &context)
  }

}
