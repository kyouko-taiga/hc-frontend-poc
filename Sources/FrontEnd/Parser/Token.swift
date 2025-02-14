import Archivist
import Utilities

/// A terminal symbol of the syntactic grammar.
public struct Token: Hashable, Sendable {

  /// The tag of a token.
  public enum Tag: UInt8, Sendable {

    // Identifiers
    case name
    case underscore

    // Reserved keywords
    case `extension`
    case `false`
    case fun
    case given
    case `import`
    case infix
    case `init`
    case `inout`
    case `internal`
    case `let`
    case postfix
    case prefix
    case `private`
    case `public`
    case `return`
    case set
    case sink
    case `static`
    case `struct`
    case `subscript`
    case trait
    case `true`
    case type
    case `typealias`
    case `var`
    case `where`

    // Pound keyords and literals
    case exactly
    case poundLiteral

    // Operators
    case ampersand
    case arrow
    case assign
    case conversion
    case equal
    case `operator`

    // Punctuation
    case comma
    case dot
    case colon
    case doubleColon
    case semicolon

    // Delimiters
    case leftAngle
    case rightAngle
    case leftBrace
    case rightBrace
    case leftBracket
    case rightBracket
    case leftParenthesis
    case rightParenthesis

    // Errors
    case error
    case unterminatedBlockComment

  }

  /// The tag of the token.
  public let tag: Tag

  /// The site from which `self` was extracted.
  public let site: SourceSpan

  /// Creates an instance with the given properties.
  public init(tag: Tag, site: SourceSpan) {
    self.tag = tag
    self.site = site
  }

  /// The text of this token.
  public var text: Substring { site.text }

  /// `true` iff `self` is a reserved keyword.
  public var isKeyword: Bool {
    (tag.rawValue >= Tag.false.rawValue) && (tag.rawValue <= Tag.type.rawValue)
  }

  /// `true` iff `self` is a binding introducer.
  public var isBindingIntroducer: Bool {
    switch tag {
    case .inout, .let, .set, .sink, .var:
      return true
    default:
      return false
    }
  }

  /// `true` iff `self` may be at the beginning of a declaration.
  public var isDeclarationHead: Bool {
    switch tag {
    case .given:
      return true
    case .import, .struct, .trait, .type, .typealias:
      return true
    case .fun, .subscript:
      return true
    default:
      return isBindingIntroducer || isDeclarationModifier
    }
  }

  /// `true` iff `self` is a declaration modifier.
  public var isDeclarationModifier: Bool {
    switch tag {
    case .static, .private, .internal, .public:
      return true
    default:
      return false
    }
  }

  /// `true` iff `self` is an operator notation.
  public var isOperatorNotation: Bool {
    switch tag {
    case .infix, .postfix, .prefix:
      return true
    default:
      return false
    }
  }

  /// `true` iff `self` may be part of an operator.
  public var isOperator: Bool {
    switch tag {
    case .ampersand, .equal, .operator, .leftAngle, .rightAngle:
      return true
    default:
      return false
    }
  }

  /// `true` iff `self` is a valid argument label.
  public var isArgumentLabel: Bool {
    (tag == .name) || (tag == .underscore) || isKeyword
  }

  /// `true` iff `self` is an access effect.
  public var isAccessEffect: Bool {
    switch tag {
    case .let, .inout, .set, .sink:
      return true
    default:
      return false
    }
  }

}

extension Token: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    let k = try archive.read(rawValueOf: Token.Tag.self, in: &context)
      .unwrapOrThrow(ArchiveError.invalidInput)
    let s = try archive.read(SourceSpan.self, in: &context)
    self.init(tag: k, site: s)
  }
  
  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(rawValueOf: tag, in: &context)
    try archive.write(site, in: &context)
  }

}
