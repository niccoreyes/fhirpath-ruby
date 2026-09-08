# FHIRPath for Ruby

[![CI](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/ci.yml)
[![Release](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/release.yml/badge.svg)](https://github.com/niccoreyes/fhirpath-ruby/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/niccoreyes/fhirpath-ruby/blob/main/LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%20%7C%203.3-blue.svg)](https://github.com/niccoreyes/fhirpath-ruby/blob/main/.github/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/fhirpath?logo=rubygems&logoColor=white)](https://rubygems.org/gems/fhirpath)
[![Gem Downloads](https://img.shields.io/gem/dt/fhirpath)](https://rubygems.org/gems/fhirpath)

A Ruby-native implementation of the [HL7 FHIRPath](https://hl7.org/fhirpath/) expression language.

This repository is an intentionally small, pre-release implementation. It provides a tested compatibility slice with stable boundaries for the public API, lexer/parser, immutable AST, collections, evaluation context, plain-model navigation, a dependency-free FHIR R4 model adapter, values, structured errors, and function registration. It does not claim complete FHIRPath conformance or complete FHIR release-model support.

## Status at a glance

* Version: `0.2.0.pre7`
- Normative language target: FHIRPath `2.0.0`
- Ruby support policy: Ruby `3.2` and `3.3` are tested in CI; newer Ruby versions are supported only after CI coverage is added.
- Release status: pre-release; published to [RubyGems](https://rubygems.org/gems/fhirpath).
- License: [MIT](LICENSE).

## Installation

The gem is published on [RubyGems.org](https://rubygems.org/gems/fhirpath):

```shell
gem install fhirpath
```

Or in a Gemfile:

```ruby
gem "fhirpath"
```

The pre-release status and incomplete conformance scope still apply; review the documented limitations before using this implementation in production.

## Quick start

```ruby
require "fhirpath"

# Plain Ruby Hash/Array navigation
data = { items: [1, 2, 3, 4, 5] }
FHIRPath.evaluate(data, "items.where($this > 3)")   # => [4, 5]

# FHIR R4 model adapter — Ruby Hash
observation = {
  "resourceType" => "Observation",
  "id" => "obs-1",
  "status" => "final",
  "code" => { "coding" => [{ "system" => "http://loinc.org", "code" => "8480-6" }] },
  "valueQuantity" => { "value" => 5.5, "unit" => "mmol/L", "system" => "http://unitsofmeasure.org", "code" => "mmol/L" }
}

# Navigate FHIR JSON with R4 model adapter
FHIRPath.evaluate(observation, "valueQuantity.value > 5.0")  # => [true]
FHIRPath.evaluate(observation, "valueQuantity.unit")         # => ["mmol/L"]
FHIRPath.evaluate(observation, "code.coding.system")         # => ["http://loinc.org"]

# Raw JSON string input — evaluate FHIR resources directly from HTTP responses (uses R4 model by default)
patient_json = <<~JSON
  {
    "resourceType": "Patient",
    "name": [{ "family": "Chalmers" }]
  }
JSON
FHIRPath.evaluate(patient_json, "name.family")  # => ["Chalmers"]

# Bundle → typed resources with ofType()
bundle = {
  "resourceType" => "Bundle",
  "entry" => [
    { "resource" => { "resourceType" => "Observation", "id" => "obs-1", "status" => "final" } },
    { "resource" => { "resourceType" => "Patient", "id" => "pat-1" } }
  ]
}
FHIRPath.evaluate(bundle, "entry.resource.ofType(Observation)")  # => [Observation resource]

# Compiled expression reuse
program = FHIRPath.compile("Patient.name.family")
program.evaluate({ "resourceType" => "Patient", "name" => [{ "family" => "Lovelace" }] }).to_a
# => ["Lovelace"]
program.call(patient_json).to_a  # also accepts raw JSON strings
# => ["Chalmers"]
```

## FHIR R4 model adapter (default)

The R4 adapter is dependency-free and does not perform Ruby method dispatch; the R4 model adapter is now the default. Its supported release and model selection are visible through `FHIRPath::Capability.current` and `FHIRPath.available_models`. Plain-model navigation is available via `model: nil`.

```ruby
observation = {
  "resourceType" => "Observation",
  "valueQuantity" => { "value" => 120, "unit" => "mmHg" }
}

FHIRPath.evaluate(observation, "value.value").to_a
# => [120]

# The choice variant carries its FHIR logical type, so `is`/`as` resolve
# against model metadata for the resolved value:
FHIRPath.evaluate(observation, "value is Quantity").to_a
# => [true]
FHIRPath.evaluate(observation, "value as Quantity").to_a
# => [{ "value" => 120, "unit" => "mmHg" }]
```

## Public API

The API is intentionally Ruby-native rather than source-compatible with `fhirpath-py`:

```ruby
FHIRPath.parse(expression, capability: FHIRPath::Capability.current)
FHIRPath.compile(expression, model: :r4, capability: ..., functions: ...)
FHIRPath.evaluate(resource, expression, variables: {}, model: :r4,
                 capability: ..., functions: ..., options: {}, host: nil)
FHIRPath.evaluate_first(resource, expression, variables: {}, model: :r4,
                        capability: ..., functions: ..., options: {}, host: nil)
```

A compiled expression is immutable and reusable:

```ruby
program = FHIRPath.compile("Patient.name.family")
program.evaluate({ "resourceType" => "Patient", "name" => [{ "family" => "Lovelace" }] }).to_a
# => ["Lovelace"]
program.call({ "resourceType" => "Patient", "name" => [{ "family" => "Hopper" }] }).to_a
# => ["Hopper"]
program.call(patient_json).to_a  # also accepts raw JSON strings
# => ["Chalmers"]
```

The compiled expression carries its own model, capability, and function registry — call-site overrides are not required.

## Supported feature slice

The current tested slice includes:

- primitive string, Boolean, integer, decimal, and scientific-notation literals;
- empty and comma-separated collections;
- plain Ruby Hash/Array and simple object navigation, including resource-type roots such as `Patient`;
- dependency-free FHIR R4 model navigation (now the default), including the logical `Observation.value` choice property over `valueQuantity` and `valueString`;
- unary and numeric arithmetic (`+`, `-`, `*`, `/`, `div`, and `mod`), plus string `+` when both operands are strings; a zero divisor for `/`, `div`, `mod` returns an empty collection, while `+`, `-`, `*` treat zero as a normal operand;
- bounded FHIRPath `Quantity` values with finite Decimal storage, case-sensitive conversion for the documented dependency-free unit subset, same-dimension comparison/addition/subtraction, scalar multiplication/division, Quantity ratios, and `ofType(Quantity)`/`is Quantity`/`as Quantity`; unsupported units and complete UCUM semantics remain outside this release slice; the parser also accepts double-quoted strings as an extension, uses `^` for supported unit exponents, preserves Quantity `system`/`code` metadata without using it for unit equality, and defers derived-unit composition such as Quantity×Quantity or `km/h`;
- numeric/string relational comparison, collection-aware equality, equivalence, and empty-aware Boolean operators; a finite JSON `Float` is treated as a `Decimal`;
- union, string concatenation (`+` and `&`), membership (`in`/`contains`), and type operators (`is`/`as`); union removes duplicate values from both operands using `=` equality in first-seen order, and `in`/`contains` require a singleton operand; `is`/`as` test built-in primitive types directly and also resolve the FHIR logical type of a navigated choice value (for example `Observation.value is Quantity` over `valueQuantity`), returning the value unchanged on a successful `as` and the empty collection otherwise; and
- indexers with non-negative integer indexes;
- `where`, `select`, `first`, `last`, `tail`, `take`, `skip`, `exists`, `count`, `empty`, `not`, `all`, and Boolean aggregate functions;
- the FHIRPath 3.0.0 STU3 aggregate functions `sum()`, `avg()`, `max()`, and `min()` (empty input yields the empty collection; `sum`/`avg` require numeric items and `max`/`min` compare numeric and string items with comparison-operator semantics), shipped as a declared, documented exception: `Capability.current` keeps the FHIRPath 2.0.0 target and reports this subset in `trial_use` under the marker `stu3-aggregate-functions`;
- `$this`, `$index`, and `$total` focus variables;
- explicitly supplied external constants through `variables:` or an injected `FHIRPath::HostServices` constant provider; and
- immutable parse/compile boundaries with structured errors and source spans.

The [feature matrix](docs/feature-matrix.md) is the executable-scope companion to this list, and the [release support matrix](docs/support-matrix.md) is the publication contract. If a behavior is not listed as supported, callers should handle a specific `FHIRPath::Error` rather than assume permissive fallback.

## Explicit limitations

This is not yet a complete FHIRPath engine. The following remain deferred or host-dependent:

- complete FHIRPath 2.0 conformance; the checked-in importer covers only the pinned official subset;
- broader FHIR R4 metadata such as primitive extensions, resource-level type tests (`Observation is Resource`/`DomainResource`), and FHIR R5 model adapters; FHIR R4 `is`/`as` over a resolved choice value's logical type (e.g. `Quantity`) is supported by default; terminology and `resolve()` remain host-dependent; and
- temporal arithmetic with Date/Time/DateTime and Quantity/Duration, including calendar-duration arithmetic;
- advanced conversion, math, string, regular-expression, and navigation functions;
- complex literals and additional standard value types;
- standard environment variables beyond explicitly supplied external constants;
- FHIRPath 3.0 STU3 features beyond the shipped `sum`/`avg`/`max`/`min` aggregate functions; capability recognition does not enable them silently;
- network I/O from pure evaluation and global evaluator state; and
- unqualified string escaping beyond the documented UTF-16 surrogate-pair handling.

## License

[MIT](LICENSE).