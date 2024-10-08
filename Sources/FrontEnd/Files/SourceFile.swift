import Algorithms
import Archivist
import Foundation
import Utilities

/// A source file.
public struct SourceFile: Hashable {

  /// The name of the file that the source came from.
  public let name: FileName

  /// The contents of the file.
  public let text: String

  /// The start position of each line.
  private let lineStarts: [Index]

  /// Creates a source file with the given name and contents.
  private init(name: FileName, contents: String) {
    self.name = name
    self.text = contents
    self.lineStarts = contents.lineBoundaries()
  }

  /// Creates a source file with the contents of the file at `path`.
  public init(contentsOf path: URL) throws {
    try self.init(name: .local(path), contents: .init(contentsOf: path))
  }

  /// Creates a virtual source file with the given contents.
  public init(contents: String) {
    var hasher = FNV()
    hasher.combine(contents)
    self.init(name: .virtual(hasher.state), contents: contents)
  }

  /// The name of the source file, sans path qualification or extension.
  public var baseName: String {
    switch name {
    case .local(let u):
      return u.deletingPathExtension().lastPathComponent
    case .virtual(let i):
      return String(UInt(bitPattern: i), radix: 36)
    }
  }

  /// The number of lines in `self`.
  public var lineCount: Int {
    lineStarts.count
  }

  /// A span covering the whole contents of `self`.
  public var span: SourceSpan {
    .init(startIndex ..< endIndex, in: self)
  }

  /// Projects the contents of `self` in `span`.
  public subscript(site: SourceSpan) -> Substring {
    text[site.region]
  }

  /// The bounds of given `line`, including any trailing newline.
  public func bounds(of line: SourceLine) -> SourceSpan {
    let end = line.number < lineStarts.count ? lineStarts[line.number] : text.endIndex
    return SourceSpan(lineStarts[line.number - 1] ..< end, in: self)
  }

  /// Returns the line containing `i`.
  ///
  /// - Requires: `i` is a valid index in `contents`.
  /// - Complexity: O(log N) where N is the number of lines in `self`.
  public func line(containing i: Index) -> SourceLine {
    SourceLine(lineStarts.partitioningIndex(where: { $0 > i }), in: self)
  }

  /// Returns the line at 1-based index `lineNumber`.
  public func line(_ lineNumber: Int) -> SourceLine {
    SourceLine(lineNumber, in: self)
  }

  /// Returns the 1-based line and column numbers corresponding to `i`.
  ///
  /// - Requires: `i` is a valid index in `contents`.
  ///
  /// - Complexity: O(log N) + O(C) where N is the number of lines in `self` and C is the returned
  ///   column number.
  func lineAndColumn(_ i: Index) -> (line: Int, column: Int) {
    let lineNumber = line(containing: i).number
    let columnNumber = text.distance(from: lineStarts[lineNumber - 1], to: i) + 1
    return (lineNumber, columnNumber)
  }

  /// Calls `action` on each source file URL in `directory` having the extension `pathExtension`.
  public static func forEachURL(
    in directory: URL, withPathExtension pathExtension: String = "hylo",
    _ action: (URL) throws -> Void
  ) rethrows {
    let items = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants])!

    for case let f as URL in items where f.pathExtension == pathExtension {
      try action(f)
    }
  }

  /// Calls `action` on each source file in `directory` having the extension `pathExtension`.
  public static func forEach(
    in directory: URL, withPathExtension pathExtension: String = "hylo",
    _ action: (SourceFile) throws -> Void
  ) throws {
    try forEachURL(in: directory, { (u) in try action(SourceFile(contentsOf: u)) })
  }

}

extension SourceFile: RandomAccessCollection {

  public typealias Element = Character

  public typealias Index = String.Index

  public var startIndex: Index { text.startIndex }

  public var endIndex: Index { text.endIndex }

  public func index(after i: Index) -> Index { text.index(after: i) }

  public func index(before i: Index) -> Index { text.index(before: i) }

  public subscript(i: Index) -> Element { text[i] }

}

extension SourceFile: ExpressibleByStringLiteral {

  /// Creates a virtual source file with the given contents.
  public init(stringLiteral contents: String) {
    self.init(contents: contents)
  }

}

extension SourceFile: Archivable {

  public init<A>(from archive: inout ReadableArchive<A>, in context: inout Any) throws {
    let n = try archive.read(FileName.self)
    let s = try archive.read(String.self)
    self.init(name: n, contents: s)
  }

  public func write<A>(to archive: inout WriteableArchive<A>, in context: inout Any) throws {
    try archive.write(name)
    try archive.write(text)
  }

}
