# FHIRPath Ruby API reference

Status: pre-release API contract (`0.1.0.pre1`)

This document describes the Ruby-native public surface. It is a contract for this project, not a claim of source compatibility with `fhirpath-py`, `fhirpath.js`, HAPI, or Firely.

## Entry points

```ruby
require "fhirpath"
```

### `FHIRPath.parse`

```ruby
parsed = FHIRPath.parse(expression, capability: FHIRPath::Capability.current)
```

Returns an immutable `FHIRPath::ParsedExpression` with:

- `source`: the original expression;
- `ast`: immutable `FHIRPath::AST` nodes; and
- `source_map`: a node-to-`FHIRPath::SourceSpan` map.

A blank, malformed, unsupported-token, or trailing-input expression raises `FHIRPath::ParseError`. The error exposes `code`, `span`, `expression`, and `to_h`.

Passing a `String` to `parse` never freezes that string: `parse` retains an internal frozen snapshot of the expression. You may mutate your own source string after calling `parse` without affecting the returned `ParsedExpression`.

### `FHIRPath.compile`

```ruby
program = FHIRPath.compile(
  expression,
  model: nil,
  capability: FHIRPath::Capability.current,
  functions: FHIRPath::FunctionRegistry.standard
)
```

Returns a frozen `FHIRPath::CompiledExpression`. Parsing happens once; each `evaluate` or `call` creates fresh per-evaluation context. A compiled expression must not retain a resource, variables, focus, trace state, or mutable evaluation cache between calls.

`compile` likewise never freezes the caller's source `String`: it snapshots the expression internally. Mutating the string you passed after calling `compile` does not change the compiled program, and passing an already-frozen string works normally.

`model` defaults to `FHIRPath::PlainModel`. Pass `model: :r4` (or `model: 'R4'`)
to select the dependency-free `FHIRPath::FHIR::R4::ModelProvider`. Passing a
provider object remains supported for custom model adapters. `functions` is an
immutable function registry snapshot.

### `FHIRPath.evaluate`

```ruby
result = FHIRPath.evaluate(
  resource,
  expression,
  variables: {},
  model: nil,
  capability: FHIRPath::Capability.current,
  functions: FHIRPath::FunctionRegistry.standard,
  options: {},
  host: nil
)
```

Returns a `FHIRPath::Collection`. Empty results are collections with `empty? == true`, not `nil`. `to_a` returns a copy of the ordered values.

`variables:` supplies external constants using either String or Symbol keys:

```ruby
FHIRPath.evaluate({}, "%enabled", variables: { enabled: false }).to_a
# => [false]
```

`host:` is reserved for explicit host services. Pure evaluation does not perform network I/O.

### `FHIRPath.evaluate_first`

Has the same options as `evaluate` and returns the first item or `nil` for an empty result. It is a convenience at the API boundary; it does not permit multi-item singleton coercion inside the evaluator.

## Errors

All public engine errors derive from `FHIRPath::Error` and carry a stable symbolic `code`, optional `span`, optional original `expression`, and `to_h` serialization.

| Error | Meaning |
|---|---|
| `ParseError` | Invalid token, malformed syntax, unsupported escape, trailing input, or expression nesting exceeding the parser depth budget (code `nesting_depth_exceeded`) |
| `EvaluationError` | Valid syntax cannot be evaluated for the current input |
| `SingletonError` | A singleton value was required but the collection had multiple items |
| `FHIRPath::TypeError` | A value has an incompatible FHIRPath type |
| `UnknownFunctionError` | No standard or registered function exists |
| `UnknownConstantError` | An external constant was not supplied |
| `ModelError` | Model navigation or type resolution failed |
| `HostError` | An injected host service failed |
| `UnsupportedFeatureError` | The construct is known but not implemented or enabled |

The project defines `FHIRPath::TypeError` inside its namespace; callers should qualify it to avoid confusion with Ruby's built-in `TypeError`.

## Collections and values

`FHIRPath::Collection` is ordered, enumerable, immutable, and flattening at construction. `singleton!` returns the only item or raises `SingletonError`; `first_item` returns the first item or `nil`. The evaluator preserves FHIRPath empty/singleton/multi-item semantics instead of using Ruby truthiness.

For the implemented string operators, `+` concatenates two singleton strings but propagates an empty operand, while `&` treats each empty operand as the empty string. Thus `'a' + {}` is empty, whereas `'a' & {}` returns `['a']`. String escapes follow the FHIRPath `\\uXXXX` form; valid UTF-16 surrogate pairs are combined, and unknown forms such as `\\U0001F600` are rejected with `ParseError`.

Most current public results are ordinary Ruby values. `FHIRPath::Value::*` and `FHIRPath::TypeInfo` provide extension boundaries for semantic values and model metadata. The dependency-free R4 adapter supports JSON choice navigation for `Observation.value[x]`; date/time, quantity, broader type-aware model behavior, and other FHIR releases remain deferred.

## Custom functions

Create a new immutable registry rather than mutating the standard registry:

```ruby
registry = FHIRPath::FunctionRegistry.standard.register(
  FHIRPath::FunctionSpec.new(
    name: "triple",
    arity: 0,
    receiver: :collection,
    implementation: ->(_receiver, _arguments, _context) { [3] }
  )
)

FHIRPath.evaluate({}, "triple()", functions: registry).to_a
# => [3]
```

`arity` may be an integer or range. `parameters` describes argument kinds; delayed arguments are passed as AST expressions. Standard functions cannot be replaced. Function callbacks should raise `FHIRPath::Error` subclasses when reporting engine-level failures and must not mutate the resource or shared registry.

## Capability

`FHIRPath::Capability.current` declares the default `fhirpath` release (`2.0.0`)
and the bundled FHIR model release (`R4`). It lists `trial_use`, `model_releases`,
and `host_features`. Capabilities are immutable. A capability declaration is
not proof that all standard functions or FHIR model behavior is implemented;
consult [the feature matrix](feature-matrix.md).

## Stability policy

The pre-1.0 API may change between releases. Changes to result shape, keyword arguments, error fields, or supported expressions must be recorded in `CHANGELOG.md`, covered by API tests, and called out in release notes. No compatibility promise is made for internal AST node classes beyond their current immutable/source-span design.
