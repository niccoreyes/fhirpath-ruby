# FHIRPath Ruby API reference

Status: pre-release API contract (`0.2.0.pre1`)

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
  model: :r4,
  capability: FHIRPath::Capability.current,
  functions: FHIRPath::FunctionRegistry.standard
)
```

Returns a frozen `FHIRPath::CompiledExpression`. Parsing happens once; each `evaluate` or `call` creates fresh per-evaluation context. A compiled expression must not retain a resource, variables, focus, trace state, or mutable evaluation cache between calls.

`compile` likewise never freezes the caller's source `String`: it snapshots the expression internally. Mutating the string you passed after calling `compile` does not change the compiled program, and passing an already-frozen string works normally.

`model` defaults to `FHIRPath::FHIR::R4::ModelProvider`. Pass `model: nil`
to opt out and use `FHIRPath::PlainModel` for model-independent navigation,
or pass a custom provider object.

### `FHIRPath.evaluate`

```ruby
result = FHIRPath.evaluate(
  resource,
  expression,
  variables: {},
  model: :r4,
  capability: FHIRPath::Capability.current,
  functions: FHIRPath::FunctionRegistry.standard,
  options: {},
  host: nil
)
```

Returns a `FHIRPath::Collection`. Empty results are collections with `empty? == true`, not `nil`. `to_a` returns a copy of the ordered values.

The `resource` argument may be an already-parsed Hash/Array (used directly, never re-serialized) or a raw JSON document String. Strings that open with `{` or `[` after leading whitespace are parsed with `JSON.parse` once per call; a malformed document raises `FHIRPath::JSONInputError` (code `:invalid_json`) with a generic public message that does not echo document contents, while `original_cause` retains the underlying `JSON::ParserError` for programmatic diagnostics. Any other String — plain text, JSON scalar text such as `"null"` or `"123"`, or a quoted JSON primitive like `"\"Ada\""` — keeps its pre-existing meaning as a singleton FHIRPath string value and is never parsed. Parsing builds a fresh structure per call; the caller's String and any Hash/Array resource are never mutated or frozen. `CompiledExpression#evaluate` and `#call` apply the same resource handling.

**Resource input handling summary:**

| Input type | Behavior |
|------------|----------|
| `Hash` / `Array` | Used directly (never re-serialized) |
| String starting with `{` or `[` (after whitespace) | Parsed as JSON document via `JSON.parse` once per call; malformed JSON raises `JSONInputError` code `invalid_json` |
| Any other String | Treated as a singleton FHIRPath string value (never parsed) |

```ruby
# Hash input — used directly
FHIRPath.evaluate({ "resourceType" => "Patient" }, "Patient.id")

# JSON object string — parsed as JSON document
json = '{ "resourceType": "Patient", "id": "123" }'
FHIRPath.evaluate(json, "Patient.id")  # => ["123"]

# JSON array string — parsed as JSON document
FHIRPath.evaluate('[1, 2, 3]', 'count()')  # => [3]

# Whitespace before { or [ is ignored
FHIRPath.evaluate("  \n{ \"resourceType\": \"Patient\" }", "Patient.id")

# Plain string — NOT parsed, treated as FHIRPath string value
FHIRPath.evaluate("just text", "$this")  # => ["just text"]

# JSON scalar text — NOT parsed (not an object/array)
FHIRPath.evaluate("123", "$this")        # => ["123"] (string, not number)
FHIRPath.evaluate("true", "$this")       # => ["true"] (string, not Boolean)
FHIRPath.evaluate("null", "$this")       # => ["null"] (string, not empty)

# Quoted JSON primitive — NOT parsed
FHIRPath.evaluate('"Ada"', "$this")      # => ["\"Ada\""] (string with quotes)
```

**Error handling:**

```ruby
# Malformed JSON raises structured JSONInputError
begin
  FHIRPath.evaluate('{ "resourceType": "Patient", invalid: }', "Patient.id")
rescue FHIRPath::JSONInputError => e
  e.code           # => :invalid_json
  e.message        # => "resource string is not valid JSON" (no document contents)
  e.to_h[:code]    # => :invalid_json
  e.original_cause # => JSON::ParserError (for programmatic diagnostics)
end
```

`variables:` supplies external constants using either String or Symbol keys:

```ruby
FHIRPath.evaluate({}, "%enabled", variables: { enabled: false }).to_a
# => [false]
```

`host:` is reserved for explicit host services. Pure evaluation does not perform network I/O.

### Model selection

By default, `FHIRPath.evaluate` uses the R4 model adapter, which enables
choice navigation (e.g. `Observation.value` resolves over `valueString`,
`valueQuantity`, etc.) and logical-type `is`/`as` metadata. Pass
`model: nil` to use `PlainModel` for plain Hash/Array navigation without
FHIR choice resolution:

```ruby
observation = { 'resourceType' => 'Observation', 'valueString' => 'high' }

# R4 model (default) — choice navigation
FHIRPath.evaluate(observation, 'Observation.value').to_a
# => ['high']

# Plain model — direct property lookup only
FHIRPath.evaluate(observation, 'Observation.value', model: nil).to_a
# => []
```

### Host constants

External constants can be supplied by an immutable `HostServices` configuration:

```ruby
provider = Class.new(FHIRPath::ConstantProvider) do
  def fetch(name, mode:, context:)
    { 'tenant' => 'example' }.fetch(name)
  end
end.new

host = FHIRPath::HostServices.new(constant_provider: provider)
FHIRPath.evaluate({}, '%tenant', host: host).to_a
# => ["example"]
```

`ConstantProvider#fetch(name, mode:, context:)` is the only provider boundary used by this slice. The engine does not discover constants or perform filesystem/network I/O. `variables:` takes precedence over the provider. Without a provider, `%name` raises `UnknownConstantError` with code `:unknown_constant`. Constant-provider failures raise a generic `HostError`; exceptions raised by the constant provider are not retained as public causes, and their detail is omitted from the public error message, `full_message`, and `to_h` serialization. Reference resolution, terminology, tracing, and cache ownership remain deferred host-service slices.

### `FHIRPath.evaluate_first`

Has the same options as `evaluate` and returns the first item or `nil` for an empty result. It is a convenience at the API boundary; it does not permit multi-item singleton coercion inside the evaluator.

## Errors

All public engine errors derive from `FHIRPath::Error` and carry a stable symbolic `code`, optional `span`, optional original `expression`, and `to_h` serialization.

| Error | Meaning |
|---|---|
| `ParseError` | Invalid token, malformed syntax, unsupported escape, trailing input, or expression nesting exceeding the parser depth budget (code `nesting_depth_exceeded`) |
| `JSONInputError` | The resource argument opened like a JSON object or array (after whitespace) but was not valid JSON (code `invalid_json`) |
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

Most current public results are ordinary Ruby values. `FHIRPath::Value::*` and `FHIRPath::TypeInfo` provide extension boundaries for semantic values and model metadata. By default, the engine uses the dependency-free R4 adapter, which supports JSON choice navigation for `Observation.value[x]`; a resolved choice value carries its FHIR logical type (for example `Quantity` for `valueQuantity`), so `is`/`as` type operators can test it. Pass `model: nil` to use `PlainModel` for model-independent navigation without choice metadata. `Collection` may carry positional model-type metadata alongside items without changing item values; the metadata is attached when a collection is produced directly by model navigation, and operators that rebuild collections (such as `union`) do not yet propagate it. Date/time, quantity, resource hierarchy and recursive resource-type `is`/`as`, and other FHIR releases remain deferred. `ofType()` is supported for filtering by built-in types and FHIR resource types recorded during navigation (see the feature matrix for the exact supported scope).

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

`FHIRPath::Capability.current` declares the default `fhirpath` release
(`2.0.0`) and the bundled FHIR model release (`R4`). It lists `trial_use`,
`model_releases`, and `host_features`. Capabilities are immutable.

The normative 2.0.0 core keeps `fhirpath: '2.0.0'` and an unchanged
`capability_set`. As a documented, default-on exception, the standard registry
ships the FHIRPath 3.0.0 STU3 aggregate functions `sum()`, `avg()`, `max()`,
and `min()` (normative 2.0.0 contains only `count()`). `Capability.current`
surfaces this subset in `trial_use` under the marker
`stu3-aggregate-functions`, so the capability report (`Capability#to_h`) names
the STU3 behavior it ships instead of silently folding it into the normative
claims. Construct `FHIRPath::Capability.new(trial_use: [])` to obtain a
declaration without the subset; `supports?('stu3-aggregate-functions')`
reports whether a capability declares it.

`trial_use` is a surface declaration, not a registry gate: it does not enable
or disable functions in `FHIRPath::FunctionRegistry.standard`, and passing a
strict-2.0 capability to `parse`/`compile`/`evaluate` does not remove the
aggregate functions from the standard registry. A caller that requires a hard
2.0.0-only function set must supply its own registry that omits them.
A capability declaration is not proof that all standard functions or FHIR
model behavior is implemented; consult [the feature matrix](feature-matrix.md).

## Stability policy

The pre-1.0 API may change between releases. Changes to result shape, keyword arguments, error fields, or supported expressions must be recorded in `CHANGELOG.md`, covered by API tests, and called out in release notes. No compatibility promise is made for internal AST node classes beyond their current immutable/source-span design.
