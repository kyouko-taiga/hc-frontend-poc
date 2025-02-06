import Archivist

/// The expression of a witness produced by implicit resolution.
public struct WitnessExpression: Hashable, Sendable {

  /// The expression of a witness.
  public indirect enum Value: Hashable, Sendable {

    /// An existing term.
    case identity(ExpressionIdentity)

    /// An abstract given.
    case abstract

    /// An assumed given.
    case assumed(Int)

    /// A reference to a term declaration.
    case reference(DeclarationReference)

    /// A context function applied to a term.
    case termApplication(WitnessExpression, WitnessExpression)

    /// A type abstraction applied to type arguments.
    case typeApplication(WitnessExpression, TypeApplication.Arguments)

    /// The selection of a nested witness.
    case nested(WitnessExpression)

    /// Returns a copy of `self` in which occurrences of assumed given identified by `i` have been
    /// substituted for `new`.
    public func substituting(assumed i: Int, for new: Value) -> Self {
      switch self {
      case .identity, .abstract:
        return self
      case .assumed(let j):
        return i == j ? new : self
      case .reference:
        return self
      case .termApplication(let w, let a):
        return .termApplication(
          w.substituting(assumed: i, for: new), a.substituting(assumed: i, for: new))
      case .typeApplication(let w, let ts):
        return .typeApplication(
          w.substituting(assumed: i, for: new), ts)
      case .nested(let w):
        return .nested(
          w.substituting(assumed: i, for: new))
      }
    }

    /// Returns a copy of `self` in which occurrences of `m` have been substituted for `n`.
    internal func substituting(_ m: ExpressionIdentity, for n: ExpressionIdentity) -> Self {
      switch self {
      case .identity(let x):
        return .identity(x == m ? n : m)
      case .abstract, .assumed:
        return self
      case .reference(let d):
        return .reference(d.substituting(m, for: n))
      case .termApplication(let w, let a):
        return .termApplication(w.substituting(m, for: n), a.substituting(m, for: n))
      case .typeApplication(let w, let a):
        return .typeApplication(w.substituting(m, for: n), a)
      case .nested(let w):
        return .nested(w.substituting(m, for: n))
      }
    }

  }

  /// The (synthesized) syntax of the witness.
  public let value: Value

  /// The type of the witness.
  public let type: AnyTypeIdentity

  /// Creates an instance with the given properties.
  public init(value: Value, type: AnyTypeIdentity) {
    self.value = value
    self.type = type
  }

  /// Creates a reference to a built-in entity.
  public init(builtin entity: BuiltinEntity, type: AnyTypeIdentity) {
    self.value = .reference(.builtin(entity))
    self.type = type
  }

  /// `true` iff this expression mentions open variable.
  public var hasVariable: Bool {
    if type[.hasVariable] { return true }

    switch value {
    case .identity, .abstract, .assumed:
      return false
    case .reference(let r):
      return r.hasVariable
    case .termApplication(let w, let a):
      return w.hasVariable || a.hasVariable
    case .typeApplication(let w, let a):
      return w.hasVariable || a.values.contains(where: { (t) in t[.hasVariable] })
    case .nested(let w):
      return w.hasVariable
    }
  }

  /// A measure of the size of the deduction tree used to produce the witness.
  public var elaborationCost: Int {
    switch value {
    case .identity, .abstract, .assumed, .reference:
      return 0
    case .termApplication(let w, let a):
      return 1 + w.elaborationCost + a.elaborationCost
    case .typeApplication(let w, _):
      return w.elaborationCost
    case .nested(let w):
      return 1 + w.elaborationCost
    }
  }

  /// The declaration of the witness evaluated by this expression, if any.
  public var declaration: DeclarationIdentity? {
    switch value {
    case .identity, .abstract, .assumed:
      return nil
    case .reference(let r):
      return r.target
    case .termApplication(let w, _), .typeApplication(let w, _):
      return w.declaration
    case .nested(let w):
      return w.declaration
    }
  }

  /// Returns a copy of `self` in which occurrences of `m` have been substituted for `n`.
  internal func substituting(_ m: ExpressionIdentity, for n: ExpressionIdentity) -> Self {
    .init(value: value.substituting(m, for: n), type: type)
  }

  /// Returns a copy of `self` in which occurrences of assumed given identified by `i` have been
  /// substituted for `new`.
  internal func substituting(assumed i: Int, for new: Value) -> Self {
    .init(value: value.substituting(assumed: i, for: new), type: type)
  }

}

extension WitnessExpression: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    printer.show(value)
  }

}

extension WitnessExpression: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    self.value = try archive.read(Value.self, in: &context)
    self.type = try archive.read(AnyTypeIdentity.self, in: &context)
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    try archive.write(self.value)
    try archive.write(self.type)
  }

}

extension WitnessExpression.Value: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    switch self {
    case .identity(let e):
      return printer.show(e)
    case .abstract:
      return "$<abstract given>"
    case .assumed(let i):
      return "$<assumed given \(i)>"
    case .reference(let d):
      return printer.show(d)
    case .termApplication(let w, let a):
      return "\(printer.show(w))(\(printer.show(a)))"
    case .typeApplication(let w, let ts):
      return "\(printer.show(w))<\(printer.show(ts.values))>"
    case .nested(let w):
      return "$<nested given>(\(printer.show(w))"
    }
  }

}

extension WitnessExpression.Value: Archivable {

  public init<T>(from archive: inout ReadableArchive<T>, in context: inout Any) throws {
    fatalError()
  }

  public func write<T>(to archive: inout WriteableArchive<T>, in context: inout Any) throws {
    fatalError()
  }

}
