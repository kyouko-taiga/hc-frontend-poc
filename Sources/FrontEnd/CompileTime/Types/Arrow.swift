import Utilities

/// The type of term abstraction returning independent values.
public struct Arrow: TypeTree {

  /// The effect of the abstraction's call operator.
  public let effect: AccessEffect

  /// `true` iff the abstraction is the type of a by-name expression.
  public let isByName: Bool

  /// The environment of the abstraction.
  public let environment: AnyTypeIdentity

  /// The input labels and types of the abstraction.
  public let inputs: [Parameter]

  /// The output type of the abstraction.
  public let output: AnyTypeIdentity

  /// Creates an instance with the given properties.
  internal init(
    effect: AccessEffect = .let,
    environment: AnyTypeIdentity = .void,
    inputs: [Parameter],
    output: AnyTypeIdentity
  ) {
    self.effect = effect
    self.isByName = false
    self.environment = environment
    self.inputs = inputs
    self.output = output
  }

  /// Creates the type of a by-name expression.
  internal init(
    effect: AccessEffect = .let,
    environment: AnyTypeIdentity = .void,
    byName output: AnyTypeIdentity
  ) {
    self.effect = effect
    self.isByName = true
    self.environment = environment
    self.inputs = []
    self.output = output
  }

  /// Properties about `self`.
  public var properties: ValueProperties {
    inputs.reduce(output.properties, { (a, i) in a.union(i.type.properties) })
  }

  /// Returns `self`, which is in `store`, with its parts transformed by `transform(_:_:)`.
  public func modified(
    in store: inout TypeStore,
    by transform: (inout TypeStore, AnyTypeIdentity) -> TypeTransformAction
  ) -> Arrow {
    if isByName {
      return .init(
        effect: effect,
        environment: store.map(environment, transform),
        byName: store.map(output, transform))
    } else {
      return .init(
        effect: effect,
        environment: store.map(environment, transform),
        inputs: inputs.map({ (p) in p.modified(in: &store, by: transform) }),
        output: store.map(output, transform))
    }
  }

}

extension Arrow: Callable {

  public var style: Call.Style {
    .parenthesized
  }

  public func output(calleeIsMutating: Bool) -> AnyTypeIdentity {
    output
  }

}

extension Arrow: Showable {

  /// Returns a textual representation of `self` using `printer`.
  public func show(using printer: inout TreePrinter) -> String {
    let e = printer.show(environment)
    let i = isByName ? "" : "(\(list: inputs.map({ (p) in printer.show(p) })))"
    let o = printer.show(output)
    return "[\(e)]\(i) \(effect) -> \(o)"
  }

}
