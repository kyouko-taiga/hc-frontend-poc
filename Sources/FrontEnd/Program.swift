import Archivist
import OrderedCollections
import Utilities

/// A Hylo program.
public struct Program {

  /// The identity of a module in loaded in a program.
  public typealias ModuleIdentity = Int

  /// The identity of a file added to a module.
  public struct SourceFileIdentity: Hashable, RawRepresentable {

    /// The raw value of this identity.
    public let rawValue: UInt32

    /// Creates an instance from its raw value.
    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    /// Creates an instance identifying the file at offset `f` in module `m`.
    public init(module m: Program.ModuleIdentity, offset f: Int) {
      precondition(m < (1 << 16))
      precondition(f < (1 << 16))
      self.rawValue = UInt32(m & 0xffff) + (UInt32(f & 0xffff) << 16)
    }

    /// Creates an instance identifying the file containing `n`.
    public init<T: SyntaxIdentity>(containing n: T) {
      self.rawValue = UInt32(truncatingIfNeeded: n.erased.bits)
    }

    /// The module offset of the node represented by `self` in its containing collection.
    public var module: Program.ModuleIdentity {
      .init(rawValue & 0xffff)
    }

    /// The file offset of the node represented by `self` in its containing collection.
    public var offset: Int {
      .init((rawValue & 0xffff0000) >> 16)
    }

  }

  /// The modules loaded in this program.
  public private(set) var modules = OrderedDictionary<Module.Name, Module>()

  /// The types in the program.
  public internal(set) var types = TypeStore()

  /// Creates an empty program.
  public init() {}

  /// `true` if the program has errors.
  public var containsError: Bool {
    modules.values.contains(where: \.diagnostics.containsError)
  }

  /// The diagnostics of the issues in the program.
  public var diagnostics: some Collection<Diagnostic> {
    modules.values.map(\.diagnostics.elements).joined()
  }

  /// Returns the identities of the modules in `self`.
  public var moduleIdentities: Range<Int> {
    modules.values.indices
  }

  /// Returns the identity of the module named `moduleName`.
  public mutating func demandModule(_ moduleName: Module.Name) -> ModuleIdentity {
    if let m = modules.index(forKey: moduleName) {
      return m
    } else {
      let m = modules.count
      modules[moduleName] = Module(name: moduleName, identity: m)
      return m
    }
  }

  /// Returns the identity of the module named `moduleName` or `nil` if no such module exists.
  public func identity(module moduleName: Module.Name) -> ModuleIdentity? {
    modules.index(forKey: moduleName)
  }

  /// Computes the scoping relationships in `m`.
  public mutating func assignScopes(_ m: ModuleIdentity) async {
    await Scoper().visit(m, in: &self)
  }

  /// Assigns types to the syntax trees of `m`.
  public mutating func assignTypes(_ m: ModuleIdentity) {
    var typer = Typer(typing: m, in: consume self)
    typer.apply()
    self = typer.release()
  }

  /// Projects the module identified by `m`.
  public subscript(m: ModuleIdentity) -> Module {
    _read { yield modules.values[m] }
    _modify { yield &modules.values[m] }
  }

  /// Projects the source file identified by `f`.
  internal subscript(f: Program.SourceFileIdentity) -> Module.SourceContainer {
    _read { yield modules.values[f.module][f] }
    _modify { yield &modules.values[f.module][f] }
  }

  /// Projects the node identified by `n`.
  public subscript<T: SyntaxIdentity>(n: T) -> any Syntax {
    _read { yield modules.values[n.module][n] }
  }

  /// Projects the node identified by `n`.
  public subscript<T: Syntax>(n: T.ID) -> T {
    modules.values[n.module][n]
  }

  /// Returns the elements in `ns` that identify nodes of type `T`.
  public func collect<S: Sequence, T: Syntax>(
    _ t: T.Type, in ns: S
  ) -> [T.ID] where S.Element: SyntaxIdentity {
    ns.compactMap({ (n) in cast(n, to: t) })
  }

  /// Returns the contents of `s`.
  public func show(_ s: SourceFileIdentity) -> String {
    self[s].source.text
  }

  /// Returns a parsable representation of `v`.
  public func show(_ v: Value) -> String {
    switch v {
    case .term(let t): show(t)
    case .type(let t): show(t)
    }
  }

  /// Returns a parsable representation of `t`.
  public func show(_ t: AnyTerm) -> String {
    t.wrapped.show(readingChildrenFrom: self)
  }

  /// Returns a parsable representation of `t`.
  public func show<T: Term>(_ t: T) -> String {
    t.show(readingChildrenFrom: self)
  }

  /// Returns a parsable representation of `t`.
  public func show<T: TypeIdentity>(_ t: T) -> String {
    types[t].show(readingChildrenFrom: self)
  }

  /// Returns a source-like representation of `s`.
  public func show(_ s: ScopeIdentity) -> String {
    s.node.map(show(_:)) ?? show(s.file)
  }

  /// Returns a parsable representation of `n`.
  public func show<T: SyntaxIdentity>(_ n: T) -> String {
    self[n].show(readingChildrenFrom: self)
  }

  /// Returns the kind of `n`.
  public func kind<T: SyntaxIdentity>(of n: T) -> SyntaxKind {
    modules.values[n.module].kind(of: n)
  }

  /// `true` iff `f` has gone through scoping.
  public func isScoped(_ f: SourceFileIdentity) -> Bool {
    self[f].syntaxToParent.count == self[f].syntax.count
  }

  /// Returns `true` iff `n` denotes a declaration.
  public func isDeclaration<T: SyntaxIdentity>(_ n: T) -> Bool {
    kind(of: n).value is any Declaration.Type
  }

  /// Returns `true` iff `n` denotes a type declaration.
  public func isTypeDeclaration<T: SyntaxIdentity>(_ n: T) -> Bool {
    kind(of: n).value is any TypeDeclaration.Type
  }

  //// Returns `true` iff `n` denotes an extension or conformance declaration.
  public func isTypeExtendingDeclaration<T: SyntaxIdentity>(_ n: T) -> Bool {
    kind(of: n).value is any TypeExtendingDeclaration.Type
  }

  /// Returns `true` iff `n` introduces a name that can be overloaded.
  public func isOverloadable<T: SyntaxIdentity>(_ n: T) -> Bool {
    switch kind(of: n) {
    case FunctionDeclaration.self:
      return true
    default:
      return false
    }
  }

  /// Returns `true` iff `n` denotes a scope.
  public func isScope<T: SyntaxIdentity>(_ n: T) -> Bool {
    kind(of: n).value is any Scope.Type
  }

  /// Returns `true` iff `n` is a trait requirement.
  public func isRequirement<T: SyntaxIdentity>(_ n: T) -> Bool {
    switch kind(of: n) {
    case AssociatedTypeDeclaration.self:
      return true
    case FunctionDeclaration.self:
      return parent(containing: n, as: TraitDeclaration.self) != nil
    case InitializerDeclaration.self:
      return parent(containing: n, as: TraitDeclaration.self) != nil
    default:
      return false
    }
  }

  /// Returns `true` iff `n` occurs at the top-level of a source file.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func isTopLevel<T: SyntaxIdentity>(_ n: T) -> Bool {
    parent(containing: n).node == nil
  }

  /// Returns `true` iff `n` declares non-static a member entity.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func isMember(_ n: FunctionDeclaration.ID) -> Bool {
    if let m = parent(containing: n).node {
      return isTypeDeclaration(m) || isTypeExtendingDeclaration(m)
    } else {
      return false
    }
  }

  /// Returns `true` iff `n` is a foreign function interface.
  public func isFFI(_ n: FunctionDeclaration.ID) -> Bool {
    false
  }

  /// Returns `true` iff `n` has an external implementation.
  public func isExternal(_ n: FunctionDeclaration.ID) -> Bool {
    false
  }

  /// Returns `true` iff `n` denotes an expression.
  public func isExpression<T: SyntaxIdentity>(_ n: T) -> Bool {
    kind(of: n).value is any Expression.Type
  }

  /// Returns `true` iff `n` is the expression of a value marked for mutation.
  public func isMarkedMutating(_ n: ExpressionIdentity) -> Bool {
    switch kind(of: n) {
    default:
      return false
    }
  }

  /// Returns `true` iff `t` is a type constructor accepting parameters.
  public func isHigherKinded(_ t: AnyTypeIdentity) -> Bool {
    switch types[t] {
    case let u as Struct:
      return !self[u.declaration].parameters.isEmpty
    case is Trait:
      return true
    default:
      return false
    }
  }

  /// Returns `n` if it identifies a node of type `U`; otherwise, returns `nil`.
  public func cast<T: SyntaxIdentity, U: Syntax>(_ n: T, to: U.Type) -> U.ID? {
    if kind(of: n) == .init(U.self) {
      return .init(uncheckedFrom: n.erased)
    } else {
      return nil
    }
  }

  /// Returns `n` assuming it identifies a node of type `U`.
  public func castUnchecked<T: SyntaxIdentity, U: Syntax>(_ n: T, to: U.Type = U.self) -> U.ID {
    assert(kind(of: n) == .init(U.self))
    return .init(uncheckedFrom: n.erased)
  }

  /// Returns `n` if it identifies a declaration; otherwise, returns `nil`.
  public func castToDeclaration<T: SyntaxIdentity>(_ n: T) -> DeclarationIdentity? {
    if isDeclaration(n) {
      return .init(uncheckedFrom: n.erased)
    } else {
      return nil
    }
  }

  /// Returns `n` if it identifies an expression; otherwise, returns `nil`.
  public func castToExpression<T: SyntaxIdentity>(_ n: T) -> ExpressionIdentity? {
    if isExpression(n) {
      return .init(uncheckedFrom: n.erased)
    } else {
      return nil
    }
  }

  /// Returns `n` if it identifies a scope; otherwise, returns `nil`.
  public func castToScope<T: SyntaxIdentity>(_ n: T) -> ScopeIdentity? {
    if isScope(n) {
      return .init(uncheckedFrom: n.erased)
    } else {
      return nil
    }
  }

  /// Returns the innermost scope that strictly contains `n`.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func parent(containing s: ScopeIdentity) -> ScopeIdentity? {
    s.node.map(parent(containing:))
  }

  /// Returns the innermost scope that strictly contains `n`.
  ///
  /// - Requires: The module containing `n` is scoped.
  public func parent<T: SyntaxIdentity>(containing n: T) -> ScopeIdentity {
    assert(isScoped(n.file), "unscoped module")
    let p = self[n.file].syntaxToParent[n.offset]
    if p >= 0 {
      return .init(uncheckedFrom: .init(file: n.file, offset: p))
    } else {
      return .init(file: n.file)
    }
  }

  /// Returns the innermost scope that contains `n` iff it is an instance of `U`. Otherwise,
  /// returns `nil`.
  ///
  /// - Requires: The module containing `n` is scoped.
  public func parent<T: SyntaxIdentity, U: Syntax>(containing n: T, as: U.Type) -> U.ID? {
    if let m = parent(containing: n).node {
      return cast(m, to: U.self)
    } else {
      return nil
    }
  }

  /// Returns a sequence containing `s` and its ancestors, from inner to outer.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func scopes(from s: ScopeIdentity) -> some Sequence<ScopeIdentity> {
    var next: Optional = s
    return AnyIterator {
      if let n = next {
        next = n.node.map(parent(containing:))
        return n
      } else {
        return nil
      }
    }
  }

  /// Returns the declarations directly contained in `s`.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func declarations(lexicallyIn s: ScopeIdentity) -> [DeclarationIdentity] {
    if let n = s.node {
      return self[n.file].scopeToDeclarations[n.offset] ?? preconditionFailure("unscoped module")
    } else {
      return self[s.file].topLevelDeclarations
    }
  }

  /// Returns the declarations direactly contained in `s` that identify nodes of type `T`.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func declarations<T: Declaration>(
    of t: T.Type, lexicallyIn s: ScopeIdentity
  ) -> [T.ID] {
    collect(t, in: declarations(lexicallyIn: s))
  }

  /// Returns the binding declaration that contains `d`, if any.
  ///
  /// - Requires: The module containing `s` is scoped.
  public func bindingDeclaration(containing d: VariableDeclaration.ID) -> BindingDeclaration.ID? {
    assert(isScoped(d.file), "unscoped module")
    return self[d.file].variableToBindingDeclaration[d.offset]
  }

  /// Returns the names introduced by `d`.
  public func names(introducedBy d: DeclarationIdentity) -> [Name] {
    switch kind(of: d) {
    case AssociatedTypeDeclaration.self:
      return [name(of: castUnchecked(d, to: AssociatedTypeDeclaration.self))]
    case BindingDeclaration.self:
      return names(introducedBy: castUnchecked(d, to: BindingDeclaration.self))
    case ParameterDeclaration.self:
      return [name(of: castUnchecked(d, to: ParameterDeclaration.self))]
    case TraitDeclaration.self:
      return [name(of: castUnchecked(d, to: TraitDeclaration.self))]
    case FunctionDeclaration.self:
      return [name(of: castUnchecked(d, to: FunctionDeclaration.self))]
    case InitializerDeclaration.self:
      return [name(of: castUnchecked(d, to: InitializerDeclaration.self))]
    case StructDeclaration.self:
      return [name(of: castUnchecked(d, to: StructDeclaration.self))]
    case TypeAliasDeclaration.self:
      return [name(of: castUnchecked(d, to: TypeAliasDeclaration.self))]
    default:
      return []
    }
  }

  /// Returns the names introduced by `d`.
  public func names(introducedBy d: BindingDeclaration.ID) -> [Name] {
    var result: [Name] = []
    forEachVariable(introducedBy: self[self[d].pattern].pattern) { (v, _) in
      result.append(.init(identifier: self[v].identifier.value))
    }
    return result
  }

  /// Returns the name of the unique entity declared by `d`, or `nil` if `d` declares zero or more
  /// than one named entity.
  public func name(of d: DeclarationIdentity) -> Name? {
    switch kind(of: d) {
    case AssociatedTypeDeclaration.self:
      return name(of: castUnchecked(d, to: AssociatedTypeDeclaration.self))
    case ParameterDeclaration.self:
      return name(of: castUnchecked(d, to: ParameterDeclaration.self))
    case TraitDeclaration.self:
      return name(of: castUnchecked(d, to: TraitDeclaration.self))
    case FunctionDeclaration.self:
      return name(of: castUnchecked(d, to: FunctionDeclaration.self))
    case InitializerDeclaration.self:
      return name(of: castUnchecked(d, to: InitializerDeclaration.self))
    case StructDeclaration.self:
      return name(of: castUnchecked(d, to: StructDeclaration.self))
    case TypeAliasDeclaration.self:
      return name(of: castUnchecked(d, to: TypeAliasDeclaration.self))
    default:
      return nil
    }
  }

  /// Returns the name of `d`.
  public func name<T: TypeDeclaration>(of d: T.ID) -> Name {
    Name(identifier: self[d].identifier.value)
  }

  /// Returns the name of `d`.
  public func name(of d: FunctionDeclaration.ID) -> Name {
    switch self[d].identifier.value {
    case .simple(let x):
      return Name(identifier: x, labels: .init(self[d].parameters.map(read(\.label?.value))))
    case .operator(let n, let x):
      return Name(identifier: x, notation: n)
    }
  }

  /// Returns the name of `d`.
  public func name(of d: InitializerDeclaration.ID) -> Name {
    var labels: [String?] = []
    if self[d].isMemberwise {
      let s = parent(containing: d, as: StructDeclaration.self)!
      forEachStoredProperty(of: s, do: { (v, _) in labels.append(self[v].identifier.value) })
    } else {
      labels.append(contentsOf: self[d].parameters.map(read(\.label?.value)))
    }
    return Name(identifier: "new", labels: .init(labels))
  }

  /// Returns the name of `d`.
  public func name(of d: ParameterDeclaration.ID) -> Name {
    Name(identifier: self[d].identifier.value)
  }

  /// Returns `(suffix: s, prefix: p)` where `s` contains the nominal components of `n` from right
  /// to left and `p` is the non-nominal prefix of `n`, if any.
  public func components(
    of n: NameExpression.ID
  ) -> (suffix: [NameExpression.ID], prefix: NameExpression.Qualification) {
    var suffix = [n]
    while true {
      let prefix = self[suffix.last!].qualification
      if case .explicit(let e) = prefix, let m = cast(e, to: NameExpression.self) {
        suffix.append(m)
      } else {
        return (suffix, prefix)
      }
    }
  }

  /// If `n` is a function or subscript call, returns its callee. Otherwise, returns `nil`.
  public func callee(_ n: ExpressionIdentity) -> ExpressionIdentity? {
    switch kind(of: n) {
    case Call.self:
      return self[castUnchecked(n, to: Call.self)].callee
    //case SubscriptCall.self:
    default:
      return nil
    }
  }

  /// Calls `action` for each stored property declaration in `d`.
  ///
  /// `action` accepts a variable declaration and an index path identifying its abstract position
  /// in a record value having the type declared by `d`.
  public func forEachStoredProperty(
    of d: StructDeclaration.ID,
    do action: (VariableDeclaration.ID, IndexPath) -> Void
  ) {
    for m in self[d].members {
      if let b = cast(m, to: BindingDeclaration.self) {
        forEachVariable(introducedBy: self[self[b].pattern].pattern, do: action)
      }
    }
  }

  /// Calls `action` for each variable declaration introduced by `d`.
  ///
  /// `action` accepts a variable declaration and an index path identifying its abstract position
  /// in the a record value having the type of `d`.
  public func forEachVariable(
    introducedBy d: BindingDeclaration.ID,
    do action: (VariableDeclaration.ID, IndexPath) -> Void
  ) {
    forEachVariable(introducedBy: self[self[d].pattern].pattern, do: action)
  }

  /// Calls `action` for each variable declaration introduced in `p`.
  ///
  /// `action` accepts a variable declaration and an index path identifying its abstract position
  /// in the a record value having the type of `p`.
  public func forEachVariable(
    introducedBy p: PatternIdentity,
    at path: IndexPath = [],
    do action: (VariableDeclaration.ID, IndexPath) -> Void
  ) {
    switch kind(of: p) {
    case BindingPattern.self:
      let q = castUnchecked(p, to: BindingPattern.self)
      forEachVariable(introducedBy: self[q].pattern, at: path, do: action)

    case TuplePattern.self:
      let q = castUnchecked(p, to: TuplePattern.self)
      for (i, e) in self[q].elements.enumerated() {
        forEachVariable(introducedBy: e.value, at: path + [i], do: action)
      }

    case VariableDeclaration.self:
      action(castUnchecked(p), path)

    default:
      assert(isExpression(p))
    }
  }

  /// Returns a lambda accessing `path` on an instance of `T`.
  public func read<T: Syntax, U>(_ path: KeyPath<T, U>) -> (_ n: T.ID) -> U {
    { (n) in self[n][keyPath: path] }
  }

  /// Reports that `n` was not expected in the current executation path and exits the program.
  public func unexpected<T: SyntaxIdentity>(
    _ n: T, file: StaticString = #file, line: UInt = #line
  ) -> Never {
    unreachable("unexpected node '\(kind(of: n))' at \(self[n].site)", file: file, line: line)
  }

  /// Reports that `t` was not expected in the current executation path and exits the program.
  public func unexpected(
    _ t: AnyTypeIdentity, file: StaticString = #file, line: UInt = #line
  ) -> Never {
    unreachable("unexpected type '\(show(t))'", file: file, line: line)
  }

  /// Returns a source span suitable to emit a disgnostic related to `n` as a whole.
  public func spanForDiagnostic<T: SyntaxIdentity>(about n: T) -> SourceSpan {
    switch kind(of: n) {
    case AssociatedTypeDeclaration.self:
      return self[castUnchecked(n, to: AssociatedTypeDeclaration.self)].identifier.site
    case BindingDeclaration.self:
      return self[self[castUnchecked(n, to: BindingDeclaration.self)].pattern].introducer.site
    case ConformanceDeclaration.self:
      return spanForDiagnostic(about: castUnchecked(n, to: ConformanceDeclaration.self))
    case ExtensionDeclaration.self:
      return self[castUnchecked(n, to: ExtensionDeclaration.self)].introducer.site
    case FunctionDeclaration.self:
      return self[castUnchecked(n, to: FunctionDeclaration.self)].identifier.site
    case ImportDeclaration.self:
      return self[castUnchecked(n, to: ImportDeclaration.self)].identifier.site
    case StructDeclaration.self:
      return self[castUnchecked(n, to: StructDeclaration.self)].identifier.site
    case TraitDeclaration.self:
      return self[castUnchecked(n, to: TraitDeclaration.self)].identifier.site
    case TypeAliasDeclaration.self:
      return self[castUnchecked(n, to: TypeAliasDeclaration.self)].identifier.site

    case Return.self:
      return .empty(at: self[castUnchecked(n, to: Return.self)].introducer.site.start)

    default:
      return self[n].site
    }
  }

  /// Returns a source span suitable to emit a disgnostic related to `n` as a whole.
  public func spanForDiagnostic(about n: ConformanceDeclaration.ID) -> SourceSpan {
    self[n].introducer?.site ?? .empty(at: self[n].site.start)
  }

  /// Returns `message` with placeholders replaced by their corresponding values in `arguments`.
  ///
  /// Use this method to generate strings containing one or several elements whose description is
  /// computed by one of `show(_:)`'s overloads.
  ///
  /// ```swift
  /// let t = AnyTypeIdentity.void
  /// let s = program.format("'%T' is a type", [t])
  /// assert(s == "'Void' is a type")
  /// ```
  ///
  /// Each element to show is represented by a placehoder, which is a string starting with "%". The
  /// i-th placeholder occurring in `message` (except `%%`) must have a corresponding value at the
  /// i-th position of `arguments`.
  ///
  /// Valid placehoders are:
  /// - `%S`: The textual description of an arbitrary value.
  /// - `%T`: A type.
  /// - `%%`: The percent sign; does not consume any argument.
  public func format(
    _ message: String, _ arguments: [Any], file: StaticString = #file, line: UInt = #line
  ) -> String {
    var output = ""
    var s = message[...]
    var a = arguments[...]
    while let head = s.popFirst() {
      if head == "%" {
        output.append(take(s.popFirst(), from: &a))
      } else {
        output.append(head)
      }
    }
    return output

    /// Converts the next element in `arguments` based on `placeholder`.
    func take(_ placeholder: Character?, from arguments: inout ArraySlice<Any>) -> String {
      switch placeholder {
      case "S":
        return String(describing: arguments.popFirst() ?? expected("item"))
      case "T":
        return show((arguments.popFirst() as? AnyTypeIdentity) ?? expected("type"))
      case "%":
        return "%"
      case let c:
        let s = c.map(String.init(_:)) ?? ""
        fatalError("invalid placeholder '%\(s)'", file: file, line: line)
      }
    }

    /// Reports that an argument of type `s` was expected and exits the program.
    func expected(_ s: String) -> Never {
      fatalError("expected \(s)", file: file, line: line)
    }
  }

}

extension Program {

  internal typealias ModuleIdentityMap = [Module.Name: ModuleIdentity]

  /// Serializes `m` to `archive`.
  public func write<A>(module m: ModuleIdentity, to archive: inout WriteableArchive<A>) throws {
    var context: Any = ModuleIdentityMap(
      uniqueKeysWithValues: modules.values.map({ (m) in (m.name, m.identity) }))
    try self[m].write(to: &archive, in: &context)
  }

  /// Serializes `m`.
  public func archive(module m: ModuleIdentity) throws -> BinaryBuffer {
    var w = WriteableArchive(BinaryBuffer())
    try write(module: m, to: &w)
    return w.finalize()
  }

  /// Loads the module named `moduleName` from `archive`.
  ///
  /// - Note: `self` is not modified if an exception is thrown.
  /// - Requires: `moduleName` is the name of the module stored in `archive`.
  @discardableResult
  public mutating func load<A>(
    module moduleName: Module.Name, from archive: inout ReadableArchive<A>
  ) throws -> (loaded: Bool, identity: ModuleIdentity) {
    // Nothing to do if the module is already loaded.
    if let m = modules.index(forKey: moduleName) { return (false, m) }

    let m = modules.count
    var c: ModuleIdentityMap = [moduleName: m]
    for n in modules.values { c[n.name] = n.identity }

    var context: Any = c
    let instance = try archive.read(Module.self, in: &context)
    precondition(moduleName == instance.name)
    modules[moduleName] = instance
    return (true, m)
  }

  /// Loads the module named `moduleName` from `archive`.
  ///
  /// - Note: `self` is not modified if an exception is thrown.
  /// - Requires: `moduleName` is the name of the module stored in `archive`.
  @discardableResult
  public mutating func load(
    module moduleName: Module.Name, from archive: BinaryBuffer
  ) throws -> (loaded: Bool, identity: ModuleIdentity) {
    var r = ReadableArchive(archive)
    return try load(module: moduleName, from: &r)
  }

}

extension Program {

  public func select(_ filter: SyntaxFilter) -> some Collection<AnySyntaxIdentity> {
    modules.values
      .map(\.syntax).joined().lazy
      .filter({ (i) in filter(i, in: self) })
  }

}

/// A selector identifying nodes in a syntax tree.
public indirect enum SyntaxFilter {

  /// Matches any node.
  case all

  /// Matches any node in the given module.
  case from(Module.Name)

  /// Matches any node with the given kind.
  case kind(any Syntax.Type)

  /// Matches top-level declarations.
  case topLevel

  /// Matches any node satisfying the given predicate.
  case satisfies((AnySyntaxIdentity) -> Bool)

  /// Returns `true` if the node `n` of program `p` satisfies `self`.
  public func callAsFunction(_ n: AnySyntaxIdentity, in p: Program) -> Bool {
    switch self {
    case .all:
      return true
    case .from(let m):
      return p.identity(module: m) == n.module
    case .kind(let k):
      return p.kind(of: n) == k
    case .topLevel:
      return p.isTopLevel(n)
    case .satisfies(let p):
      return p(n)
    }
  }

}
