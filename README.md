# FHIRPath for Ruby

[![CI](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/ci.yml)
[![Release](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/release.yml/badge.svg)](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/niccoreyes/fhirpath-ruby/blob/main/LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%20%7C%203.3-blue.svg)](https://github.com/niccoreyes/fhirpath-ruby/blob/main/.github/workflows/ci.yml)

A Ruby-native implementation of the [HL7 FHIRPath](https://hl7.org/fhirpath/) expression language.

This repository is an intentionally small, pre-release implementation. It provides a tested compatibility slice with stable boundaries for the public API, lexer/parser, immutable AST, collections, evaluation context, plain-model navigation, a dependency-free FHIR R4 model adapter, values, structured errors, and function registration. It does not claim complete FHIRPath conformance or complete FHIR release-model support.

## Status at a glance

- Version: `0.1.0.pre1`
- Normative language target: FHIRPath `2.0.0`
- Ruby support policy: Ruby `3.2` and `3.3` are tested in CI; newer Ruby versions are supported only after CI coverage is added.
- Release status: pre-release; not published to RubyGems.
- License: [MIT](LICENSE).

The exact release-facing target, capability identifiers, Ruby support matrix,
and host/model limitations are maintained in the [release support matrix](docs/support-matrix.md).

## Installation

The gem is not yet published. To use a checkout:

```sh
git clone https://github.com/niccoreyes/fhirpath-ruby.git
cd fhirpath-ruby
bundle install
bundle exec rake test
```

Once a release is published, the intended consumer workflow will be:

```ruby
# Gemfile
gem "fhirpath"
```

The pre-release status and incomplete conformance scope still apply; review the
documented limitations before using this implementation in production.

## Quick start

```ruby
require "fhirpath"

patient = {
  "resourceType" => "Patient",
  "name" => [
    { "use" => "official", "family" => "Lovelace", "given" => ["Ada", "Augusta"] },
    { "use" => "nickname", "given" => ["Addie"] }
  ]
}

FHIRPath.evaluate(patient, "Patient.name.where(use = 'official').given").to_a
# => ["Ada", "Augusta"]

FHIRPath.evaluate_first(patient, "Patient.name.family")
# => "Lovelace"
```

FHIR R4 JSON can be selected explicitly through the versioned provider. The
adapter exposes the logical `Observation.value` property over R4 choice keys
such as `valueString` and `valueQuantity`:

```ruby
observation = {
  "resourceType" => "Observation",
  "valueQuantity" => { "value" => 120, "unit" => "mmHg" }
}

FHIRPath.evaluate(observation, "Observation.value.value", model: :r4).to_a
# => [120]
```

The R4 adapter is dependency-free and does not perform Ruby method dispatch;
plain-model navigation remains the default. Its supported release and model
selection are visible through `FHIRPath::Capability.current` and
`FHIRPath.available_models`.

## Public API

The API is intentionally Ruby-native rather than source-compatible with `fhirpath-py`:

```ruby
FHIRPath.parse(expression, capability: FHIRPath::Capability.current)
FHIRPath.compile(expression, model: nil, capability: ..., functions: ...)
FHIRPath.evaluate(resource, expression, variables: {}, model: nil,
                 capability: ..., functions: ..., options: {}, host: nil)
FHIRPath.evaluate_first(resource, expression, variables: {}, model: nil,
                        capability: ..., functions: ..., options: {}, host: nil)
```

A compiled expression is immutable and reusable:

```ruby
program = FHIRPath.compile("Patient.name.family")
program.evaluate({ "resourceType" => "Patient", "name" => [{ "family" => "Lovelace" }] }).to_a
# => ["Lovelace"]
program.call({ "resourceType" => "Patient", "name" => [{ "family" => "Hopper" }] }).to_a
# => ["Hopper"]
```

See [API reference](docs/api.md) for result, error, extension, and immutability contracts, and [architecture](docs/architecture.md) for the implementation boundaries.

### Explicit host constants

External constant lookup is opt-in and stays behind an injected provider:

```ruby
class TenantConstants < FHIRPath::ConstantProvider
  def fetch(name, mode:, context:)
    constants.fetch(name)
  end

  private

  def constants
    { 'tenant' => 'example' }
  end
end

host = FHIRPath::HostServices.new(constant_provider: TenantConstants.new)
FHIRPath.evaluate({}, '%tenant', host: host).to_a
# => ["example"]
```

`ConstantProvider#fetch` is the only boundary at which an embedding application may perform external work. The engine does not discover constants, read files, or make network requests. If no provider is supplied, an external constant raises `UnknownConstantError` with code `:unknown_constant`. Provider failures raise a generic `HostError`; the original exception is retained in `original_cause` for controlled diagnostics but provider messages are excluded from the public error serialization. `variables:` takes precedence over the provider, so explicitly supplied values do not trigger provider work.

## Supported slice

The current tested slice includes:

- primitive string, Boolean, integer, decimal, and scientific-notation literals;
- empty and comma-separated collections;
- plain Ruby Hash/Array and simple object navigation, including resource-type roots such as `Patient`;
- dependency-free FHIR R4 model navigation selected with `model: :r4`, including the logical `Observation.value` choice property over `valueQuantity` and `valueString`;
- unary and numeric arithmetic (`+`, `-`, `*`, `/`, `div`, and `mod`), plus string `+` when both operands are strings; a zero divisor for `/`, `div`, `mod` returns an empty collection, while `+`, `-`, `*` treat zero as a normal operand;
- numeric/string relational comparison, collection-aware equality, equivalence, and empty-aware Boolean operators; a finite JSON `Float` is treated as a `Decimal`;
- union, string concatenation (`+` and `&`), membership (`in`/`contains`), and primitive type operators (`is`/`as`); union removes duplicate values from both operands using `=` equality in first-seen order, and `in`/`contains` require a singleton operand; and
- indexers with non-negative integer indexes;
- `where`, `select`, `first`, `last`, `tail`, `take`, `skip`, `exists`, `count`, `empty`, `not`, `all`, and Boolean aggregate functions;
- `$this`, `$index`, and `$total` focus variables;
- explicitly supplied external constants through `variables:` or an injected `FHIRPath::HostServices` constant provider; and
- immutable parse/compile boundaries with structured errors and source spans.

The [feature matrix](docs/feature-matrix.md) is the executable-scope companion to this list, and the [release support matrix](docs/support-matrix.md) is the publication contract. If a behavior is not listed as supported, callers should handle a specific `FHIRPath::Error` rather than assume permissive fallback.

## Explicit limitations

This is not yet a complete FHIRPath engine. The following remain deferred or host-dependent:

- official HL7 shared-suite import and complete FHIRPath 2.0 conformance;
- FHIR R5 model adapters, broader FHIR R4 metadata such as primitive extensions and type-aware navigation, terminology, and `resolve()`;
- date/time and quantity/UCUM values;
- advanced conversion, math, string, regular-expression, navigation, and aggregate functions;
- complex literals and additional standard value types;
- standard environment variables beyond explicitly supplied external constants;
- FHIRPath 3.0 STU3 features; capability recognition does not enable them silently;
- network I/O from pure evaluation and global evaluator state; and
- production support guarantees, until the support matrix and release gates are complete.

Unsupported operations raise `UnsupportedFeatureError`, `UnknownFunctionError`, or another specific `FHIRPath::Error`. Malformed or trailing source raises `ParseError`; the parser does not accept a valid prefix and silently ignore trailing input.

## Development and verification

Install development dependencies and run the complete local checks:

```sh
bundle install
bundle exec rake test
bundle exec rubocop
bundle exec rake vectors
bundle exec rake build
bundle exec ./script/verify_gem_install.sh pkg/fhirpath-*.gem
```

The optional vector workflow is deterministic and does not require Python:

```sh
bundle exec ruby script/run_vectors.rb conformance/core.jsonl
```

It reports `pass`, `defect`, `unsupported`, `host-dependent`, and `not-run` separately. These hand-authored JSONL vectors are compatibility evidence, not a replacement for the official HL7 shared suite. See [Conformance workflow](docs/conformance.md).

Coverage is opt-in and uses Ruby's standard `Coverage` library:

```sh
COVERAGE=1 bundle exec rake test
bundle exec ruby script/check_coverage.rb coverage/summary.json
```

For a clean-checkout reproduction, use the exact commands in [CONTRIBUTING.md](CONTRIBUTING.md). CI runs the supported Ruby matrix, tests, RuboCop, vectors, package build, gem-install smoke test, and coverage report generation.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. New language behavior should be delivered as a small vertical slice: add a focused failing test, implement the smallest change, run the complete checks, and update the feature matrix and limitations when scope changes.

Security reports should follow [SECURITY.md](SECURITY.md). Release readiness,
versioning, publication, and remaining conformance gates are recorded in
[`docs/release-checklist.md`](docs/release-checklist.md) and
[`docs/releasing.md`](docs/releasing.md).

## License

This project is licensed under the [MIT License](LICENSE). The gem is still a
pre-release and does not claim complete FHIRPath conformance; those limitations
are independent of the license.
