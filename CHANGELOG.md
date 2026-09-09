# Changelog

All notable changes to this project are documented here. The project is pre-1.0; the API and supported behavior may change between releases.

## [Unreleased]
- Import and execute the full official HL7 FHIRPath R4 shared test suite (935 cases from `fhir-test-cases` commit `ebb15f74f95a4731e59099c4244eeed734c9e447`) with XML fixtures resolved to verified JSON counterparts or converted via the new `FHIRXmlConverter` (fail-closed on unsupported structures). Runner classification: 385 pass, 550 defect (12 from 14 XML-converted fixtures + 462 from 840 JSON-fixture cases + 76 from 81 no-fixture cases), 0 not-run. 14 XML-only fixtures converted; 840 JSON-fixture cases reclassified; 81 no-fixture cases classified. Closes issue #79; part of #75.
- Add `FHIRPath::Conformance::FHIRXmlConverter`: dependency-free FHIR XML to JSON conversion following canonical FHIR JSON representation rules. Primitive element types drawn from a curated table covering elements the official suite exercises; raises `UnsupportedStructureError` for structures it cannot faithfully represent so the importer can fail closed instead of emitting a resource with wrong types.
- Add `FHIRPath::Conformance::FixtureResolver`: resolves XML fixtures to verified JSON counterparts using structural matching (resource type + id equality) rather than basename heuristics, preventing same-named JSON files that are different resource instances from being incorrectly trusted.
- Update `FHIRPath::Conformance::Importer` to use the resolver and converter; `not-run` classification now only applies to structurally unsupported XML, not to missing JSON counterparts.

## [0.2.0.pre7] - 2026-09-08
- Change the default FHIR model from `PlainModel` to `FHIR::R4::ModelProvider`: omitted `model:` now uses R4, enabling choice navigation (`Observation.value`) and logical-type `is`/`as` metadata by default. Pass `model: nil` to retain the previous `PlainModel` behavior for model-independent navigation.

## [0.2.0.pre6] - 2026-09-08
- Add the `aggregate()` function with `$this`, `$total`, and `$index` variables for general-purpose collection aggregation (issue #43). The function signature is `aggregate(expression, initial)` where the expression is evaluated per item with the accumulator as `$total`. Empty collections return the initial value (or empty if omitted). Closes issue #43.
- Add keyword-named functions (`contains`, `in`) usable after member access (`Patient.name.contains('John')`) — the lexer previously classified these as binary operators only, preventing function-call syntax after `.` (issue #66). Also registers both as standard functions with arity 1.
- Accept raw JSON strings in `FHIRPath.evaluate()` and `CompiledExpression#evaluate`: strings starting with `{` or `[` after optional whitespace are parsed via `JSON.parse` once per call; malformed JSON raises `JSONInputError` (code `:invalid_json`); `Hash`/`Array` inputs pass through unchanged; other strings remain singleton string values (issue #56).
- Add bounded Quantity/UCUM support: immutable `BigDecimal`-backed `FHIRPath::Quantity` type with case-sensitive conversion for the explicit subset (`m`, `cm`, `mm`, `km`, `g`, `kg`, `mg`, `Mg`, `ug`, `ng`, `L`, `mL`, `ML`, `uL`, `mol`, `mmol`, `umol`, `s`, `min`, `h` and products/quotients such as `mmol/L`). Same-dimension comparison/addition/subtraction/multiplication by scalar/division; incompatible or unsupported-unit operations return empty. The UCUM parser is dependency-free and exponents are bounded to 12 to prevent CPU/memory amplification (issue #44).
- Expand R4 model adapter choice elements: `Medication`, `Condition`, `Procedure`, and `DiagnosticReport` choice elements now resolve through the FHIRPath navigation layer (issue #46).
- Import and check in the full official HL7 FHIRPath shared test suite (935 cases from `fhir-test-cases` release `1.7.69`) with a new `load_full_suite` importer mode that bypasses the pinned `case_ids` subset (issue #47).
- Document JSON input behavior in `docs/api.md` and add FHIR-native JSON examples to the README Quick Start.
- Clean up redundant README badges and update the version reference to `0.2.0.pre6`.
- Fix the release workflow asset verification to derive the exact gem filename from `RELEASE_TAG` instead of a literal glob (previous `jq index("fhirpath-*.gem")` always failed).

## [0.2.0.pre5] - 2026-09-07
- Add a dependency-free, explicitly bounded FHIRPath `Quantity` type. Quantity values always store a finite `BigDecimal` and expose `value`, `unit`, `system`, and `code`; the supported UCUM unit subset and the maximum exponent bounds are documented in the release support matrix. Same-dimension operations work; incompatible or unsupported-unit operations return an empty collection.
- Accept raw JSON string documents in `FHIRPath.evaluate` and `CompiledExpression#evaluate`. Strings that begin with `{` or `[` after optional whitespace are parsed as JSON; malformed JSON raises `JSONInputError`. All other strings continue to be treated as singleton string values.
- Add `ofType()` and FHIR resource-type filtering.
- Add Date, Time, and DateTime types with literals, functions, timezone support, comparisons, and component extractors.
- Add FHIR primitive extension accessors (`._<name>`).
- Expand R4 model adapter choice elements for `Medication`, `Condition`, `Procedure`, and `DiagnosticReport`.

## [0.2.0.pre4] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre3] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre2] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre1] - 2026-09-05
- Add the `sum()`, `avg()`, `max()`, and `min()` aggregate functions to the
  standard registry. These are FHIRPath 3.0.0 STU3 aggregate additions
  (published 2026-07-28) and the first STU3-subset functions this project
  ships; they are absent from normative FHIRPath 2.0.0 and from the 3.0.0
  ballot. Semantics follow the published 3.0.0 text where it applies: empty
  input returns the empty collection; non-numeric items raise `TypeError` with
  code `expected_number`; `avg()` converts Integer items to Decimal before
  dividing and always yields a Decimal; and `max()`/`min()` reuse the
  comparison-operator semantics so numerics compare across Integer/Decimal and
  strings order lexicographically, with incompatible item types raising
  `TypeError` with code `incompatible_comparison`. The 3.0.0 text requires all
  items to be the same type; this slice records a documented deviation for
  numeric input instead of an exception: mixed Integer/Decimal input is summed
  in Decimal, matching the engine's numeric promotion in arithmetic and
  equality (`1 = 1.0` and `1 + 2.5` both hold), while all-Integer input keeps
  an Integer `sum()` result. The subset ships by default in the standard
  registry as a declared exception: `Capability.current` keeps `fhirpath`
  `2.0.0` and reports the marker `stu3-aggregate-functions` in `trial_use`;
  `docs/support-matrix.md`, `docs/api.md`, and the feature matrix document the
  exception. `count()` (normative FHIRPath 2.0.0, existence functions)
  already existed and now has focused expression tests and checked-in vectors
  alongside the family. No inputs are mutated and every result is a fresh
  frozen `Collection`; the general-purpose `aggregate()` function remains
  deferred.

- Resolve the FHIR logical type of a choice value for the `is`/`as` type
  operators when a model provider is active. `ModelProvider` gains an optional
  `property_logical_type` accessor (safe `nil` default on the base class and
  `PlainModel`); the R4 provider reports the resolved variant's declared type
  from its choice metadata (`valueQuantity` -> `Quantity`, `valueString` ->
  `string`). Navigation records that type per item on the produced collection
  without wrapping or altering the value, so with `model: :r4`,
  `Observation.value is Quantity` yields `[true]` and
  `Observation.value as Quantity` passes the value through unchanged (an empty
  collection when the cast fails). Primitive built-in type tests, empty
  in/empty out for absent choices, and the plain-model default are unchanged.
  `Observation is Resource`/`DomainResource` style tests and `ofType()` remain
  deferred.
- Add the `tail()`, `take(n)`, and `skip(n)` member functions (FHIRPath 2.0.0, subsetting functions; §5.3.5–5.3.7): `tail()` returns all but the first item and is empty for empty/singleton input; `take(n)` returns the first `min(n, size)` items, empty for `n <= 0` or empty input, and the full collection when `n` exceeds the size; `skip(n)` returns the items after the first `n`, the full collection for `n <= 0`, and empty when no items remain. `take`/`skip` require an integer `n` and raise `TypeError` with code `expected_integer` for a non-integer argument.
- Add a dependency-free FHIR R4 model provider selectable with `model: :r4`.
  It maps the R4 `Observation.value[x]` JSON variants `valueQuantity` and
  `valueString` to logical `Observation.value`; an absent choice evaluates to
  the empty collection. The provider is exposed as
  `FHIRPath::FHIR::R4::ModelProvider` and advertised by the capability API.
  Resource-type and release matching accept symbol/string and any-case forms.
- Add the `last()` member function (FHIRPath 2.0.0, existence/navigation functions): it returns the last item in the input collection, an empty collection when the input is empty, and requires zero arguments.
- Harden the external constant boundary with an injectable `ConstantProvider`, predictable `UnknownConstantError` behavior when absent, generic redacted `HostError` messages without retaining constant-provider exceptions as public causes, and no implicit provider I/O; resolve, terminology, tracing, and cache behavior remain deferred.
- Correct numeric arithmetic with a zero right operand: `+`, `-`, `*` treat zero as a normal operand, while `/`, `div`, `mod` divide and a zero divisor returns an empty collection (never an error).
- Correct `union` (`|`) to eliminate duplicate values from both operands using `=` equality in first-seen order, including numerically-equal integers and decimals.
- Accept a finite JSON `Float` as a `Decimal` for comparison, equality, arithmetic, and the `is Decimal` type test; reject `NaN`/`Infinity` as non-numeric.
- Correct `contains` so a multi-item right operand raises a singleton-required error even when the searched collection is empty, and so an empty right operand yields an empty result.
- Correct `&` string concatenation to treat empty operands as empty strings, with regression coverage for both operators' empty-collection behavior.
- Correct parser precedence for relational, union, and type operators to match the FHIRPath grammar.
- Harden documentation, package verification, CI, coverage reporting, and contributor workflows.
- Add the release support matrix, exact package capability metadata, versioning policy, and gated RubyGems/GitHub publication workflow.
- Declare the project under the MIT License and encode the license in gem metadata.
- Bound parser recursion: excessively nested expressions (parentheses, unary chains, function calls, indexers, and deep AST-building flat expressions) now raise `FHIRPath::ParseError` with code `nesting_depth_exceeded` instead of letting `SystemStackError` escape the `FHIRPath::Error` boundary.
- Stop freezing the caller-owned source string: `parse`/`compile` retain an internal frozen snapshot of the expression, so mutating the caller's String afterwards does not affect the compiled program.

## [0.1.0.pre1] - 2026-09-04

- Added the Ruby-native parser, immutable AST, collection-first evaluator, plain model boundary, structured errors, capability object, and function registry.
- Added path navigation, literals, arithmetic, selected comparisons, Boolean operators, indexers, filtering, existence functions, and reusable compiled expressions.
- Added collection-aware equality/equivalence, normalized string and decimal equivalence, empty/not/all functions, string addition, union, membership, primitive type operators, comments, and strict string-escape handling.
- Added a small JSONL differential-vector runner and six checked-in compatibility vectors.
- Documented the prototype scope, architecture, limitations, and staged conformance plan.

[Unreleased]: https://github.com/niccoreyes/fhirpath-ruby/compare/v0.2.0.pre7...HEAD
[0.2.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.2.0.pre1
[0.1.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.1.0.pre1