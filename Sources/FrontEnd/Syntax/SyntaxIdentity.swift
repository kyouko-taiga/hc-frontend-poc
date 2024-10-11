import Archivist
import Utilities

/// A type denoting the identity of a node in an abstract syntax tree.
public protocol SyntaxIdentity: Hashable, Archivable {

  /// The type-erased value of this identity.
  var erased: AnySyntaxIdentity { get }

  /// Creates an identifying the same node as `erased`.
  init(fromErased erased: AnySyntaxIdentity)

}

extension SyntaxIdentity {

  /// The module offset of the node represented by `self` in its containing collection.
  public var module: Program.ModuleIdentity {
    erased.module
  }

  /// The file offset of the node represented by `self` in its containing collection.
  public var file: Program.SourceFileIdentity {
    erased.file
  }

  /// The offset of the node represented by `self` in its containing collection.
  public var offset: Int {
    erased.offset
  }

  /// Returns `true` iff `l` denotes the same node as `r`.
  public static func == <T: SyntaxIdentity>(l: Self, r: T) -> Bool {
    l.erased == r.erased
  }

  /// Returns `true` iff `l` denotes the same node as `r`.
  public static func == <T: SyntaxIdentity>(l: T, r: Self) -> Bool {
    l.erased == r.erased
  }

  public init<A>(from archive: inout ReadableArchive<A>, in context: inout Any) throws {
    self.init(fromErased: try archive.read(AnySyntaxIdentity.self, in: &context))
  }

  public func write<A>(to archive: inout WriteableArchive<A>, in context: inout Any) throws {
    try archive.write(erased, in: &context)
  }

}

/// The type-erased identity of an abstract syntax tree.
///
/// An identity is composed of three offsets, are stored contiguously within a 64-bit integer:
/// - `module`: a 16-bit offset identifying the module in which the node is contained.
/// - `file`  : a 16-bit offset identifying the file in which the node is contained.
/// - `node`  : a 32-bit offset identifying the node itself.
public struct AnySyntaxIdentity {

  /// The bit representation of `self`.
  public let bits: UInt64

  /// Creates an instance with the given bit representation.
  public init(bits: UInt64) {
    self.bits = bits
  }

  /// Creates an instance identifying the node at offset `n` in file `f`.
  public init(file f: Program.SourceFileIdentity, offset n: Int) {
    precondition(n < (1 << 32))
    self.bits = UInt64(f.rawValue) + (UInt64(n) << 32)
  }

  /// Creates an identifying the same node as `other`.
  public init<T: SyntaxIdentity>(_ other: T) {
    self.bits = other.erased.bits
  }

  /// The module offset of the node represented by `self` in its containing collection.
  public var module: Program.ModuleIdentity {
    .init(bits & 0xffff)
  }

  /// The file offset of the node represented by `self` in its containing collection.
  public var file: Program.SourceFileIdentity {
    .init(rawValue: UInt32(bits & 0xffffffff))
  }

  /// The offset of the node represented by `self` in its containing collection.
  public var offset: Int {
    .init(bits >> 32)
  }

}

extension AnySyntaxIdentity: SyntaxIdentity {

  /// Creates an instance with the given type-erased value.
  public init(fromErased erased: AnySyntaxIdentity) {
    self = erased
  }

  /// The type-erased value of this identity.
  public var erased: AnySyntaxIdentity {
    self
  }

}

extension AnySyntaxIdentity: ExpressibleByIntegerLiteral {

  public init(integerLiteral value: UInt64) {
    self.init(bits: value)
  }

}

extension AnySyntaxIdentity: Archivable {

  public init<A>(from archive: inout ReadableArchive<A>, in context: inout Any) throws {
    let c = context as? Module.SerializationContext ?? fatalError("bad context")
    let b = try archive.read(UInt64.self)
    let m = UInt64(c.modules[Int(b & 0xffff)]!)
    self.bits = b & ~0xffff | m
  }

  public func write<A>(to archive: inout WriteableArchive<A>, in context: inout Any) throws {
    let c = context as? Module.SerializationContext ?? fatalError("bad context")
    let m = UInt64(c.modules[Int(bits & 0xffff)]!)
    try archive.write(bits & ~0xffff | m)
  }

}

extension AnySyntaxIdentity: CustomStringConvertible {

  public var description: String { bits.description }

}

/// The identity of a node in an abstract syntax tree.
public struct ConcreteSyntaxIdentity<T: Syntax>: SyntaxIdentity {

  /// The type-erased value of this identity.
  public let erased: AnySyntaxIdentity

  /// Creates an identifying the same node as `erased`.
  public init(fromErased erased: AnySyntaxIdentity) {
    self.erased = erased
  }

}

/// The type-erased identity of an abstract syntax tree denoting a declaration.
public struct DeclarationIdentity: SyntaxIdentity {

  /// The type-erased value of this identity.
  public let erased: AnySyntaxIdentity

  /// Creates an identifying the same node as `erased`.
  public init(fromErased erased: AnySyntaxIdentity) {
    self.erased = erased
  }

  /// Creates an instance equal to `other`.
  public init<T: Declaration>(_ other: T.ID) {
    self.erased = other.erased
  }

}

/// The type-erased identitiy of an abstract syntax tree denoting an expression.
public struct ExpressionIdentity: SyntaxIdentity {

  /// The type-erased value of this identity.
  public let erased: AnySyntaxIdentity

  /// Creates an identifying the same node as `erased`.
  public init(fromErased erased: AnySyntaxIdentity) {
    self.erased = erased
  }

  /// Creates an instance equal to `other`.
  public init<T: Expression>(_ other: T.ID) {
    self.erased = other.erased
  }

}

/// The type-erased identity of an abstract syntax tree denoting a scope.
public struct ScopeIdentity: SyntaxIdentity {

  /// The type-erased value of this identity.
  public let erased: AnySyntaxIdentity

  /// Creates an identifying the same node as `erased`.
  public init(fromErased erased: AnySyntaxIdentity) {
    self.erased = erased
  }

  /// Creates an instance equal to `other`.
  public init<T: Scope>(_ other: T.ID) {
    self.erased = other.erased
  }

}
