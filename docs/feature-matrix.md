# Feature Matrix

FHIRPath `0.2.0.pre7` — Ruby implementation of HL7 FHIRPath.

| Category | Feature | Status | Evidence |
|---|---|---|---|
| Core | Parse, immutable AST, source spans | Supported | foundation/parser tests |
| Core | Complete-input validation | Supported | parser regression tests |
| Core | String, Boolean, integer, decimal literals | Supported | foundation/core compatibility tests |
| Core | Double-quoted string literals | Extension | the lexer accepts double-quoted strings in addition to normative single-quoted FHIRPath strings; this extension supports double-quoted Quantity units and is covered by Quantity tests |
| Core | Scientific notation | Supported | core compatibility tests |
| Core | Empty and comma-separated collections | Supported | parser/evaluator tests |
| Core || Hash/Array/plain object navigation | Supported | foundation tests; `PlainModel` |
| Core || Unary/numeric arithmetic and string `+` | Supported | parity/core compatibility tests; `+` propagates empty operands; a zero divisor for `/`, `div`, `mod` yields an empty collection, while `+`, `-`, `*` operate on zero normally ||
| Core | Relational comparison | Supported | parity/core compatibility tests |
| Core | Collection equality/equivalence | Supported | core compatibility tests and vectors |
| Core | Finite JSON `Float` treated as `Decimal` | Supported | evaluator correctness tests; a finite `Float` (e.g. from `JSON.parse`) compares, equals, arithmetically combines, and satisfies `is Decimal`; `NaN`/`Infinity` are rejected as non-numeric |
| Core | String `&` concatenation | Supported | core compatibility tests; empty operands are treated as `''` |
| Core | Empty-aware Boolean operators | Supported | foundation/core compatibility tests |
| Core | Union, `in`, `contains`, `is`, `as` | Supported | core compatibility tests and vectors; union eliminates duplicates from both operands using `=` equality in first-seen order; `in`/`contains` require a singleton operand and follow the empty-collection rules; `is`/`as` test built-in primitive types by runtime value and, when a model provider resolves the value, also test the FHIR logical type recorded by navigation (e.g. `Observation.value is Quantity`), with `as` passing the value through unchanged on a match and yielding the empty collection on a mismatch |
| Core || Indexers | Supported | foundation/parity tests |
| Core || `where`, `select`, `first`, `last`, `tail`, `take`, `skip`, `exists` | Supported | `test/subsetting_functions_test.rb` |
| Core || `distinct()`, `intersect()`, `exclude()`, `single()`, `sort()` | Supported | `test/distinct_test.rb`, `test/intersect_test.rb`, `test/exclude_test.rb`, `test/single_test.rb`, `test/sort_test.rb` |
| Core || `subsetOf()`, `supersetOf()` | Supported | `test/subset_of_test.rb`, `test/superset_of_test.rb` |
| Core || `repeat(count)` | Supported | `test/repeat_test.rb`; `TypeError(:expected_integer)` on non-integer count |
| Core || Aggregate functions `count()`, `sum()`, `avg()`, `max()`, `min()` | Supported | `test/aggregate_functions_test.rb` and aggregate vectors. `count()` follows FHIRPath 2.0.0 (integer count; empty -> `[0]`). `sum`/`avg`/`max`/`min` are FHIRPath 3.0.0 STU3 aggregate additions (published 2026-07-28; absent from 2.0.0 and the 3.0.0 ballot) shipped in the standard registry: empty input -> empty; `sum()`/`avg()` accept numeric items only (`TypeError` code `expected_number` otherwise), sum mixed Integer/Decimal input through Decimal, and `avg()` converts Integer items to Decimal before dividing; `max()`/`min()` use comparison-operator semantics for numeric and string items (incompatible item types raise `TypeError` code `incompatible_comparison`); no input mutation. The STU3 subset is surfaced on the capability object: `Capability.current` keeps `fhirpath` `2.0.0` and declares marker `stu3-aggregate-functions` in `trial_use` (capability surface tests in the same file) |
| Core || `empty`, `not`, `all`, Boolean aggregates | Supported | core compatibility tests |
| Core || `$this`, `$index`, `$total` | Supported | parity tests |
| Core | General-purpose `aggregate()` function | Supported | `test/aggregate_functions_test.rb`; enables custom aggregations via `$this`, `$index`, `$total` |
| Core || Explicit external constants | Supported | foundation/core compatibility tests; values may come from `variables:` or an explicitly injected `HostServices` constant provider |
| Core | Missing external constant provider | Supported | `test/host_services_test.rb`; raises `UnknownConstantError` with code `:unknown_constant` and performs no fallback I/O |
| Core | Constant-provider failures and redaction | Supported | `test/host_services_test.rb`; raises generic `HostError` without retaining constant-provider exceptions as public causes or exposing their detail in diagnostics |
| Core | Host callback configuration/reentrancy | Supported | `test/host_services_test.rb`; `HostServices` is immutable and each evaluation receives a fresh context |
| Core | Custom registered functions | Supported | API/foundation tests |
| Core | Compiled-expression reuse | Supported | API/foundation tests |
| Core | Stable structured engine errors | Supported | API/foundation/parser tests |
| Core | `ofType()` type filter | Supported | `test/oftype_test.rb`; filters collections by built-in (`Integer`, `String`, `Decimal`, `Boolean`, `Date`, `DateTime`, `Time`) and FHIR resource types recorded during navigation; logical-type `is`/`as` previously deferred this slice |
| Core | Date/Time/DateTime literals (`@...`) | Supported | `test/temporal_literals_test.rb`; ISO 8601 with optional timezone (`Z`/`±HH:MM`) |
| Core | `today()`, `now()`, `time()` | Supported | `test/temporal_now_test.rb` |
| Core | Temporal component extractors (`year`, `month`, `day`, `hour`, `minute`, `second`, `millisecond`) | Supported | `test/temporal_components_test.rb`; `millisecond()` on `DateTime` reads `sec_fraction * 1000` |
| Core | Temporal timezone (`timezone()`, `timezoneOffset()`) | Supported | `test/temporal_components_test.rb` |
| Core | Temporal same-type comparison | Supported | `test/temporal_comparison_test.rb`; cross-type raises `incompatible_comparison` |
| Core | Temporal arithmetic with Quantity/Duration | Deferred | calendar-duration and date/time arithmetic is not implemented; bounded numeric Quantity arithmetic is supported separately below |
| Core | FHIR primitive extension accessor (`._<name>`) | Supported | `test/primitive_extensions_test.rb`; returns the underlying `{value, extension}` container or empty per FHIRPath 2.0.0 |
| Core | Quantity/UCUM | Supported | `test/quantity_test.rb` and `test/quantity_edge_cases_test.rb`; immutable Decimal-backed quantities, case-sensitive dimensional conversion for the explicitly bounded dependency-free subset (`m`/`cm`/`mm`/`km`, `g`/`kg`/`mg`/`Mg`/`ug`/`ng`, `L`/`mL`/`ML`/`uL`, `mol`/`mmol`/`umol`, `s`/`min`/`h`, and products/quotients such as `mmol/L`); unsupported units are rejected rather than treated as dimensionless, incompatible calculations and mixed Quantity/scalar addition return empty, same-dimension Quantity division returns a Decimal ratio, derived-unit composition such as Quantity×Quantity or `km/h` remains deferred, and system/code metadata is preserved without changing unit equality |
| Core | Advanced conversion/math/string/regex | Deferred | not in standard registry |
| Core | FHIR R4 model adapter (default) | Supported | `test/r4_model_test.rb`; dependency-free `FHIRPath::FHIR::R4::ModelProvider`; omitted `model:` defaults to R4, `model: nil` selects PlainModel |
| Core | FHIR R4 `Observation.value[x]` logical navigation | Supported | R4 choice vectors; `valueQuantity` and `valueString` resolve through `value`, absent choice is empty; this is now the default behavior when no `model:` is passed |
| Core | FHIR R4 logical-type `is`/`as` over resolved choice values | Supported | `test/r4_type_operator_test.rb` and R4 choice vectors; navigation records the resolved choice variant's FHIR logical type (`Quantity`, `string`, ...) and `is`/`as` test against it; empty-in/empty-out and PlainModel (no model metadata) behavior are covered; the type is recorded for collections produced directly by navigation (operators that rebuild collections, such as `union`, do not yet propagate it); resource hierarchy and recursive resource-type `is`/`as` remain deferred; this is now the default behavior when no `model:` is passed |
| Core | FHIR R5 model adapter | Deferred | no R5 provider |
| Core | Broader FHIR choice elements and primitive extensions | Host-dependent | first R4 slice only covers `Observation.value[x]` |
| Core | `resolve()` and terminology | Host-dependent | requires injected host services |
| Core | Official HL7 shared test suite | Supported | Full R4 suite (935 cases) imported via `FHIRPath::Conformance::Importer.from_manifest` with `load_full_suite: true`; XML fixtures resolved to verified JSON counterparts or converted via `FHIRXmlConverter` (fail-closed on unsupported structures); runner classification: 385 pass, 550 defect (12 from 14 XML-converted fixtures + 462 from 840 JSON-fixture cases + 76 from 81 no-fixture cases), 0 not-run; see `docs/support-matrix.md` for the current disposition of each group. Deferred: `subsetOf`, `startsWith`, `endsWith`, `matches`, `matchesFull`, `convertsToInteger`, `lowBoundary`, `highBoundary`, `comparable`, `precision`, `hasValue`, and unsupported UCUM units. Host-dependent: `resolve()`, terminology, broader R4 choice elements, R5 model adapter. |
| Core | FHIRPath 3.0 STU3 aggregate functions (`sum`, `avg`, `max`, `min`) | Supported | shipped by default as the first STU3-subset additions to the standard registry — a deliberate, documented exception (declared `stu3-aggregate-functions` in `Capability.current.trial_use` with `fhirpath` staying `2.0.0`; see `docs/api.md` and `docs/support-matrix.md`); semantics follow the aggregate row above |
| Core | Other FHIRPath 3.0 STU3 features | Deferred | not enabled by default |
| Core | Network I/O/global evaluator state | Not supported by design | pure evaluation boundary |

The matrix is a release-review aid, not a conformance percentage. A future release must update it together with tests, capability output, and the changelog.
