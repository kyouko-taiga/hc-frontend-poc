import Utilities

/// A function computing the scoping relationships of a module.
public struct Scoper {

  /// Creates an instance.
  public init() {}

  /// Computes the scoping relationships in `m`, which is in `p`.
  public func visit(_ m: Program.ModuleIdentity, in p: inout Program) async {
    let ts = p[m].sources.values.indices.map { (i) in
      Task.detached { [p] in
        let f = Program.SourceFileIdentity(module: m, offset: i)
        var v = Visitor(p[f])
        for o in p[f].syntax.indices {
          let n = AnySyntaxIdentity(file: f, offset: o)
          p.visit(n, calling: &v)
        }
        return v
      }
    }

    for (i, t) in ts.enumerated() {
      let f = Program.SourceFileIdentity(module: m, offset: i)
      var v = await t.value
      modify(&p[f]) { (w) in
        swap(&w.syntaxToParent, &v.syntaxToParent)
        swap(&w.scopeToDeclarations, &v.scopeToDeclarations)
        swap(&w.variableToBindingDeclaration, &v.variableToBindingDeclaration)
      }
      assert(p[f].syntax.count == v.syntaxToParent.count)
    }
  }

  /// The computation of the scoping relationships in a single source file.
  private struct Visitor: SyntaxVisitor {

    /// A table from syntax tree to the scope that contains it.
    var syntaxToParent: [Int]

    /// A table from scope to the declarations that it contains directly.
    var scopeToDeclarations: [Int: [DeclarationIdentity]]

    /// A table from variable declaration to its containing binding declaration, if any.
    var variableToBindingDeclaration: [Int: BindingDeclaration.ID]

    /// The innermost lexical scope currently visited.
    var innermostScope: Int

    /// The binding declarations currently visited, from outermost to innermost.
    var bindingDeclarationsOnStack: [BindingDeclaration.ID]

    /// Creates an instance for computing the relationships of `f`.
    init(_ f: Module.SourceContainer) {
      self.syntaxToParent = f.syntaxToParent
      self.scopeToDeclarations = [:]
      self.variableToBindingDeclaration = [:]
      self.innermostScope = -1
      self.bindingDeclarationsOnStack = []
    }

    mutating func willEnter(_ n: AnySyntaxIdentity, in program: Program) -> Bool {
      syntaxToParent[n.offset] = innermostScope

      switch program.kind(of: n) {
      case BindingDeclaration.self:
        bindingDeclarationsOnStack.append(.init(uncheckedFrom: n))
      case VariableDeclaration.self:
        variableToBindingDeclaration[n.offset] = bindingDeclarationsOnStack.last
      default:
        break
      }

      if let m = program.castToDeclaration(n), innermostScope >= 0 {
        scopeToDeclarations[innermostScope]!.append(m)
      }
      if program.isScope(n) {
        innermostScope = n.offset
        scopeToDeclarations[innermostScope] = []
      }

      return true
    }

    mutating func willExit(_ n: AnySyntaxIdentity, in program: Program) {
      if program.kind(of: n) == BindingDeclaration.self {
        bindingDeclarationsOnStack.removeLast()
      } else if program.isScope(n) {
        innermostScope = syntaxToParent[n.offset]
      }
    }

  }

}
