# Changelog

All notable changes to this project are documented here. The project is pre-1.0; the API and supported behavior may change between releases.

## [Unreleased]

## [0.2.0.pre5] - 2026-09-07
- Add the `aggregate()` function with `$this`, `$total`, and `$index` variables for general-purpose collection aggregation (issue #43). The function signature is `aggregate(expression, initial)` where the expression is evaluated per item with the accumulator as `$total`. Empty collections return the initial value (or empty if omitted). Closes issue #43.
- Add keyword-named functions (`contains`, `in`) usable after member access (`Patient.name.contains('John')`) — the lexer previously classified these as binary operators only, preventing function-call syntax after `.` (issue #66). Also registers both as standard functions with arity 1.
- Accept raw JSON strings in `FHIRPath.evaluate()` and `CompiledExpression#evaluate`: strings starting with `{` or `[` after optional whitespace are parsed via `JSON.parse` once per call; malformed JSON raises `JSONInputError` (code `:invalid_json`); `Hash`/`Array` inputs pass through unchanged; other strings remain singleton string values (issue #56).
- Add bounded Quantity/UCUM support: immutable `BigDecimal`-backed `FHIRPath::Quantity` type with case-sensitive conversion for the explicit subset (`m`, `cm`, `mm`, `km`, `g`, `kg`, `mg`, `Mg`, `ug`, `ng`, `L`, `mL`, `ML`, `uL`, `mol`, `mmol`, `umol`, `s`, `min`, `h` and products/quotients such as `mmol/L`). Same-dimension comparison/addition/subtraction/multiplication by scalar/division; incompatible or unsupported-unit operations return empty. The UCUM parser is dependency-free and exponents are bounded to 12 to prevent CPU/memory amplification (issue #44).
- Expand R4 model adapter choice elements: `Medication`, `Condition`, `Procedure`, and `DiagnosticReport` choice elements now resolve through the FHIRPath navigation layer (issue #46).
- Import and check in the full official HL7 FHIRPath shared test suite (935 cases from `fhir-test-cases` release `1.7.69`) with a new `load_full_suite` importer mode that bypasses the pinned `case_ids` subset (issue #47).
- Document JSON input behavior in `docs/api.md` and add FHIR-native JSON examples to the README Quick Start.

- Add a dependency-free, explicitly bounded FHIRPath `Quantity` type. Quantity
  values always store a finite `BigDecimal` and expose `value`, `unit`,
  `system`, and `code`; integer quantity literals are promoted to Decimal.
  Single- and double-quoted unit literals are supported, with case-sensitive
  conversion for the tested subset of length, mass, volume, amount, and time
  units plus simple products/quotients such as `mmol/L`. Same-dimension
  quantities support comparison, addition, subtraction, scalar multiplication
  and division, and Quantity/Quantity ratios. Unsupported units are rejected;
  incompatible calculations return an empty collection. Quantity×Quantity and
  derived-unit composition such as `km/h` remain deferred. This is not complete
  UCUM conformance, and calendar-duration arithmetic remains deferred. The
  parser also accepts double-quoted strings as a documented extension, while
  normative FHIRPath string literals remain single-quoted. Wrong-case symbols
  such as `MG` and `G` are rejected; exponent notation uses `^` (for example,
  `m^2`). Mixed Quantity/scalar addition is empty in either operand order,
  and derived-unit division such as `km/h` is deferred. Quantity `system` and
  `code` metadata is preserved but does not change unit equality.


## [0.2.0.pre3] - 2026-09-06
- Same library content as `0.2.0.pre2`. Version bumped because the earlier
  `0.2.0.pre2` tag was pushed to RubyGems by a partial release run before the
  workflow fix landed in PR #50, and RubyGems rejects repushing the same
  version. Library code, capability set, and feature matrix are unchanged
  from `0.2.0.pre2`; only the gem version and this changelog entry differ.

## [0.2.0.pre2] - 2026-09-06
- Add the `ofType()` function to the standard registry. Filters the receiver
  collection to items whose runtime type matches the specified type identifier
  (e.g., `Integer`, `String`, `Decimal`, `Boolean`, `Date`, `DateTime`, `Time`),
  or whose recorded model type matches an FHIR resource type (e.g.,
  `Observation`, `Patient`). The new function is implemented against the
  receiver's parallel `types` array (set during navigation via the
  `ModelProvider#type_of` hook), so it works on both bare values and resources
  produced by the FHIR R4 adapter. Closes part of issue #13.
- Record the model-resolved resource type on every navigation result so the
  R4 adapter can be filtered by `ofType(ResourceName)` (e.g., filtering a
  Bundle's `entry.resource` collection to `Observation` only). Previously the
  evaluator recorded the choice-variant logical type only; the new fallback
  covers non-choice properties and the resource's own `resourceType`.
- Add FHIRPath Date/Time/DateTime value types and temporal operations:
  - Lexer supports the `@YYYY-MM-DD`, `@THH:MM:SS`, `@YYYY-MM-DDTHH:MM:SSZ`,
    and `@YYYY-MM-DDTHH:MM:SS±HH:MM` temporal-literal syntax.
  - Nullary functions: `today()` → Date, `now()` → DateTime, `time()` → Time.
  - Component extractors on singletons: `year()`, `month()`, `day()`,
    `hour()`, `minute()`, `second()`, `millisecond()`. `millisecond()` on
    `DateTime` reads `sec_fraction * 1000` (the only fractional-precision
    path Ruby exposes for DateTime).
  - Timezone functions: `timezone()` returns the formatted offset string
    (e.g., `+05:30`); `timezoneOffset()` returns the offset in minutes.
  - Same-type temporal comparisons via `<`, `<=`, `=`, `>=`, `>` (date/date,
    datetime/datetime, time/time only — cross-type compares raise
    `incompatible_comparison`).
  - `ofType(Date|DateTime|Time)` filtering.
  - 26 new tests across literals, now/today/time, components, comparison,
    ofType, and edge cases (empty input, singleton requirement). All pass.
- Add FHIR primitive-extension accessors (`._<name>`) per FHIRPath 2.0.0
  spec. `<primitive>._<name>` returns the underlying `{value, extension}`
  JSON container when the source primitive has a `value`, and empty when
  only an extension is present. 4 new tests added. Closes part of issue #45.

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

[Unreleased]: https://github.com/niccoreyes/fhirpath-ruby/compare/v0.2.0.pre1...HEAD
[0.2.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.2.0.pre1
[0.1.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.1.0.pre1
