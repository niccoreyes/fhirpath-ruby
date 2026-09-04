# FHIRPath for Ruby

This repository is the foundation for a Ruby implementation of the [HL7 FHIRPath](https://hl7.org/fhirpath/) expression language.

The project is an intentionally small prototype at this stage. It provides a Ruby-native first parity slice with stable boundaries for the public API, lexer/parser, immutable AST, collections, evaluation context, model navigation, values, errors, and function registry. It does not claim complete FHIRPath conformance; the target and limitations below are explicit.

## Requirements

- Ruby 2.6 or newer
- Bundler

## Setup

```sh
bundle install
```

## Development commands

Run the test suite:

```sh
bundle exec rake test
```

Run the formatter/linter:

```sh
bundle exec rubocop
```

Build the gem locally:

```sh
bundle exec rake build
```

The default Rake task runs the test suite, so `bundle exec rake` is also supported.

## Current scope

The normative default capability is FHIRPath 2.0.0. The API returns a `FHIRPath::Collection` for every evaluation, including a singleton; use `evaluate_first` when an explicit first-item convenience is wanted.

Supported prototype behavior:

- `require "fhirpath"`, `FHIRPath::VERSION`, and `FHIRPath.version`
- `FHIRPath.parse`, with immutable AST nodes and source spans
- `FHIRPath.compile`, reusable compiled expressions, and `CompiledExpression#call`
- `FHIRPath.evaluate` and `FHIRPath.evaluate_first`
- plain Ruby Hash/Array navigation, including resource-type roots such as `Patient`
- string, Boolean, integer, decimal, and scientific-notation numeric literals
- empty and comma-separated collection literals
- unary arithmetic and numeric arithmetic (`+`, `-`, `*`, `/`, `div`, and `mod`)
- numeric/string relational comparison, equality, equivalence, and empty-aware Boolean operators
- expression indexers with non-negative integer indexes
- `where`, `select`, `first`, `exists`, and `count` collection functions
- `$this`, `$index`, and `$total` focus variables for delayed predicates
- external constants through `variables:`, including false and empty values
- explicit `Capability`, `EvaluationContext`, `PlainModel`, `HostServices`, `FunctionRegistry`, `TypeInfo`, and `Value::*` extension boundaries
- structured errors derived from `FHIRPath::Error`, including codes, source spans, and expressions

Explicitly unsupported or deferred:

- complete FHIRPath 2.0 conformance and official shared-suite coverage
- FHIR release adapters, choice-element metadata, terminology, and `resolve()`
- date/time, quantity/UCUM, advanced type/conversion, math functions, regex, and remaining standard functions
- evaluation of union and string-concatenation operators, plus complex literals
- variables beyond `$this`, `$index`, `$total`, and explicitly supplied external constants
- FHIRPath 3.0 STU3 features; capability recognition does not enable them silently
- network I/O from pure evaluation and global evaluator state

Unsupported operations raise a structured `UnsupportedFeatureError`, `UnknownFunctionError`, or another specific `FHIRPath::Error`; malformed or trailing source raises `ParseError`. See `docs/architecture.md`, `docs/roadmap.md`, and `docs/first-slice.md` for the staged conformance plan and this slice's intentional deviations.

## License

No redistribution license has been selected yet. See `LICENSE`; the source is not currently offered for reuse under an open-source license.
