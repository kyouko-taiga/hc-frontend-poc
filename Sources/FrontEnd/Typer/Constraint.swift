/// An equation involving compile-time values.
internal protocol Constraint {

  /// The site from which the constraint originates.
  var site: SourceSpan { get }

  /// `true` iff `self` trivially holds and solving it will not enable any new deductions.
  var isTrivial: Bool { get }

  /// Applies `transform` on constituent types of `self`.
  mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity)

  /// Returns a textual representation of `self`, reading contents from `program`.
  func show(using program: Program) -> String

}

extension Constraint {

  /// `true` iff `self` trivially holds and solving it will not enable any new deductions.
  internal var isTrivial: Bool { false }

  /// Returns a copy of `self` with its constituent types modified by `transform`.
  internal func updated(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) -> Self {
    var clone = self
    clone.update(transform)
    return clone
  }

}

extension Program {

  /// Returns a debug representation of `k`.
  internal func show(_ k: any Constraint) -> String {
    k.show(using: self)
  }

  /// Returns a debug representation of the elements in `ks`.
  internal func show<S: Sequence<any Constraint>>(_ ks: S) -> String {
    ks.map(show(_:)).joined(separator: "\n")
  }

}

/// A constraint stating that two types are equal.
internal struct EqualityConstraint: Constraint {

  /// The left operand.
  internal private(set) var lhs: AnyTypeIdentity

  /// The right operand.
  internal private(set) var rhs: AnyTypeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// `true` iff `self` trivially holds and solving it will not enable any new deductions.
  internal var isTrivial: Bool {
    lhs == rhs
  }

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    lhs = transform(lhs)
    rhs = transform(rhs)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("%T =:= %T", [lhs, rhs])
  }

}

/// A constraint stating that a value of type `T` can be coerced to a value of type `U`.
internal struct CoercionConstraint: Constraint {

  /// The reason for a coercion constraint.
  internal enum Reason {

    /// A type ascription.
    case ascription

    /// A return value.
    case `return`

    /// An unspecified reason.
    case unspecified

  }

  /// The expression of the value whose type must be corced from `lhs` to `rhs`.
  internal let origin: ExpressionIdentity

  /// The type of the value to coerce.
  internal private(set) var lhs: AnyTypeIdentity

  /// The type to which the value is coerced.
  internal private(set) var rhs: AnyTypeIdentity

  /// The reason for this constraint.
  internal let reason: Reason

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Creates an instance with the given properties.
  init(
    on origin: ExpressionIdentity, from lhs: AnyTypeIdentity, to rhs: AnyTypeIdentity,
    reason: Reason = .unspecified, at site: SourceSpan
  ) {
    self.origin = origin
    self.lhs = lhs
    self.rhs = rhs
    self.reason = reason
    self.site = site
  }

  /// `true` iff `self` trivially holds and solving it will not enable any new deductions.
  internal var isTrivial: Bool {
    lhs == rhs
  }

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    lhs = transform(lhs)
    rhs = transform(rhs)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("%T ~:~ %T", [lhs, rhs])
  }

}

/// A constraint stating that there exists a compiler-known conversion from values a type to values
/// of another (wider) type.
internal struct WideningConstraint: Constraint {

  /// The left operand.
  internal private(set) var lhs: AnyTypeIdentity

  /// The right operand.
  internal private(set) var rhs: AnyTypeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// `true` iff `self` trivially holds and solving it will not enable any new deductions.
  internal var isTrivial: Bool {
    lhs == rhs
  }

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    lhs = transform(lhs)
    rhs = transform(rhs)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("%T <:< %T", [lhs, rhs])
  }

}

/// a constraint stating that `T` is the type of an initializer that is convertible to a
/// constructor of type `U`.
internal struct ConstructorConversionConstraint: Constraint {

  /// The type of the initializer.
  internal private(set) var lhs: AnyTypeIdentity

  /// The type of the constructor.
  internal private(set) var rhs: AnyTypeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    lhs = transform(lhs)
    rhs = transform(rhs)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("constructor(%T) =:= %T", [lhs, rhs])
  }

}

/// A constraint stating that a value of type `F` can be applied to values of types `A1, ..., An`
/// for producing a value of type `R`.
internal struct CallConstraint: Constraint {

  /// The label, type, and site of an argument passed to a callable object.
  internal struct Argument: Hashable {

    /// The label of the argument, if any.
    internal let label: String?

    /// The type of the argument.
    internal var type: AnyTypeIdentity

  }

  /// The type of an entity being applied.
  internal private(set) var callee: AnyTypeIdentity

  /// The labels and types of the arguments.
  internal private(set) var arguments: [Argument]

  /// The expected type of the application.
  internal private(set) var output: AnyTypeIdentity

  /// The expression of the application from which the constraint originates.
  internal let origin: Call.ID

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// The expected labels of `callee`.
  internal var labels: some Sequence<String?> {
    arguments.lazy.map(\.label)
  }

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    callee = transform(callee)
    for i in 0 ..< arguments.count {
      arguments[i].type = transform(arguments[i].type)
    }
    output = transform(output)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    var s = program.show(callee)
    // if program.tag(of: origin) == SubscriptCall
    s.write(" applied to (")
    for i in 0 ..< arguments.count {
      if i != 0 { s.write(", ") }
      if let l = arguments[i].label { s.write("\(l): ") }
      s.write(program.show(arguments[i].type))
    }
    s.write(") gives ")
    s.write(program.show(output))
    return s
  }

}

/// A constraint stating that a value of type `A` can be passed to a parameter of type `A`.
internal struct ArgumentConstraint: Constraint {

  /// The expression of the argument passed as an argument.
  internal let origin: ExpressionIdentity

  /// The type of the argument.
  internal private(set) var lhs: AnyTypeIdentity

  /// The type of the parameter.
  internal private(set) var rhs: AnyTypeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    lhs = transform(lhs)
    rhs = transform(rhs)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("%T ↓ %T", [lhs, rhs])
  }

}

/// A constraint stating that a value of type `F` can be applied to values of types `A1, ..., An`
/// at compile-time for producing a value of type `R`.
internal struct StaticCallConstraint: Constraint {

  /// The type of an entity being applied.
  internal private(set) var callee: AnyTypeIdentity

  /// The types of the arguments.
  internal private(set) var arguments: [AnyTypeIdentity]

  /// The expected type of the application.
  internal private(set) var output: AnyTypeIdentity

  /// The expression of the application from which the constraint originates.
  internal let origin: StaticCall.ID

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    callee = transform(callee)
    for i in 0 ..< arguments.count {
      arguments[i] = transform(arguments[i])
    }
    output = transform(output)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    var s = program.show(callee)
    s.write(" applied to <")
    for i in 0 ..< arguments.count {
      if i != 0 { s.write(", ") }
      s.write(program.show(arguments[i]))
    }
    s.write("> gives ")
    s.write(program.show(output))
    return s
  }

}

/// A constraint stating that a value of given type can be summoned in a given scope.
internal struct Summonable: Constraint {

  /// The type of the value to summon.
  internal private(set) var type: AnyTypeIdentity

  /// The scope in which the value can be summoned.
  internal let scope: ScopeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    type = transform(type)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("\u{22A9} %T", [type])
  }

}

/// A constraint stating that a value of type `Q` has a member `m` of type `R`.
internal struct MemberConstraint: Constraint {

  /// The expression of the member.
  internal let member: NameExpression.ID

  /// The role of the member in the syntax tree.
  internal let role: SyntaxRole

  /// The qualification of the member.
  internal private(set) var qualification: TypedQualification

  /// The type of the member.
  internal private(set) var type: AnyTypeIdentity

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    qualification = .init(value: qualification.value, type: transform(qualification.type))
    type = transform(type)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    program.format("%T.\(program[member].name) =:= %T", [qualification.type, type])
  }

}

/// A constraint stating that a a name expression refers to a declaration in an overload set.
internal struct OverloadConstraint: Constraint {

  /// The overloaded expression.
  internal let name: NameExpression.ID

  /// The type of the overloaded expression.
  internal private(set) var type: AnyTypeIdentity

  /// The set containing the declaration referred to by `name`.
  internal let candidates: [NameResolutionCandidate]

  /// The site from which the constraint originates.
  internal let site: SourceSpan

  /// Applies `transform` on constituent types of `self`.
  internal mutating func update(_ transform: (AnyTypeIdentity) -> AnyTypeIdentity) {
    type = transform(type)
  }

  /// Returns a textual representation of `self`, reading contents from `program`.
  internal func show(using program: Program) -> String {
    let cs = candidates.lazy.map { (c) in
      "(\(program.show(c.reference)) : \(program.show(c.type)))"
    }
    return "(\(program.show(name)) : \(program.show(type))) \u{21A6} {\(list: cs)}"
  }

}
