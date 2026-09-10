# Feature and capability matrix

Status: `0.2.0.pre7`; target release: FHIRPath `2.0.0`; publication contract: [`support-matrix.md`](support-matrix.md)

This matrix is deliberately conservative. `Supported` means the behavior is exercised by the Ruby test suite or the checked-in vector corpus. `Deferred` means callers should expect a structured unsupported/unknown error. `Host-dependent` requires an adapter or injected service that is not shipped here.

| Area | Status | Evidence / boundary |
|---|---|---|
| `require "fhirpath"`, version | Supported | `test/fhirpath_test.rb` |
| Parse, immutable AST, source spans | Supported | foundation/parser tests |
| Complete-input validation | Supported | parser regression tests |
| String, Boolean, integer, decimal literals | Supported | foundation/core compatibility tests |
| Double-quoted string literals | Extension | the lexer accepts double-quoted strings in addition to normative single-quoted FHIRPath strings; this extension supports double-quoted Quantity units and is covered by Quantity tests |
| Scientific notation | Supported | core compatibility tests |
| Empty and comma-separated collections | Supported | parser/evaluator tests |
|| Hash/Array/plain object navigation | Supported | foundation tests; `PlainModel` ||
|| Raw JSON string resource input | Supported | `test/json_string_input_test.rb`; `FHIRPath.evaluate`, `FHIRPath.evaluate_first`, and `CompiledExpression#normalize_resource` normalize strings opening with `{` or `[` after whitespace via `JSON.parse` once per call, malformed documents raise `JSONInputError` code `invalid_json`, Hash/Array inputs are never parsed, and other strings (plain text, JSON scalar text, quoted primitives) pass through unchanged ||
|| Unary/numeric arithmetic and string `+` | Supported | parity/core compatibility tests; `+` propagates empty operands; a zero divisor for `/`, `div`, `mod` yields an empty collection, while `+`, `-`, `*` operate on zero normally ||
| Relational comparison | Supported | parity/core compatibility tests |
| Collection equality/equivalence | Supported | core compatibility tests and vectors |
| Finite JSON `Float` treated as `Decimal` | Supported | evaluator correctness tests; a finite `Float` (e.g. from `JSON.parse`) compares, equals, arithmetically combines, and satisfies `is Decimal`; `NaN`/`Infinity` are rejected as non-numeric |
| String `&` concatenation | Supported | core compatibility tests; empty operands are treated as `''` |
| Empty-aware Boolean operators | Supported | foundation/core compatibility tests |
| Union, `in`, `contains`, `is`, `as` | Supported | core compatibility tests and vectors; union eliminates duplicates from both operands using `=` equality in first-seen order; `in`/`contains` require a singleton operand and follow the empty-collection rules; `is`/`as` test built-in primitive types by runtime value and, when a model provider resolves the value, also test the FHIR logical type recorded by navigation (e.g. `Observation.value is Quantity`), with `as` passing the value through unchanged on a match and yielding the empty collection on a mismatch |
|| Indexers | Supported | foundation/parity tests |
|| `where`, `select`, `first`, `last`, `tail`, `take`, `skip`, `exists` | Supported | `test/subsetting_functions_test.rb` |
|| Aggregate functions `count()`, `sum()`, `avg()`, `max()`, `min()` | Supported | `test/aggregate_functions_test.rb` and aggregate vectors. `count()` follows FHIRPath 2.0.0 (integer count; empty -> `[0]`). `sum`/`avg`/`max`/`min` are FHIRPath 3.0.0 STU3 aggregate additions (published 2026-07-28; absent from 2.0.0 and the 3.0.0 ballot) shipped in the standard registry: empty input -> empty; `sum()`/`avg()` accept numeric items only (`TypeError` code `expected_number` otherwise), sum mixed Integer/Decimal input through Decimal, and `avg()` converts Integer items to Decimal before dividing; `max()`/`min()` use comparison-operator semantics for numeric and string items (incompatible item types raise `TypeError` code `incompatible_comparison`); no input mutation. The STU3 subset is surfaced on the capability object: `Capability.current` keeps `fhirpath` `2.0.0` and declares marker `stu3-aggregate-functions` in `trial_use` (capability surface tests in the same file) |
|| `empty`, `not`, `all`, Boolean aggregates | Supported | core compatibility tests |
|| `$this`, `$index`, `$total` | Supported | parity tests |
| General-purpose `aggregate()` function | Supported | `test/aggregate_functions_test.rb`; enables custom aggregations via `$this`, `$index`, `$total` |
|| Explicit external constants | Supported | foundation/core compatibility tests; values may come from `variables:` or an explicitly injected `HostServices` constant provider |
| Missing external constant provider | Supported | `test/host_services_test.rb`; raises `UnknownConstantError` with code `:unknown_constant` and performs no fallback I/O |
| Constant-provider failures and redaction | Supported | `test/host_services_test.rb`; raises generic `HostError` without retaining constant-provider exceptions as public causes or exposing their detail in diagnostics |
| Host callback configuration/reentrancy | Supported | `test/host_services_test.rb`; `HostServices` is immutable and each evaluation receives a fresh context |
| Custom registered functions | Supported | API/foundation tests |
| Compiled-expression reuse | Supported | API/foundation tests |
| Stable structured engine errors | Supported | API/foundation/parser tests |
| `ofType()` type filter | Supported | `test/oftype_test.rb`; filters collections by built-in (`Integer`, `String`, `Decimal`, `Boolean`, `Date`, `DateTime`, `Time`) and FHIR resource types recorded during navigation; logical-type `is`/`as` previously deferred this slice |
| Date/Time/DateTime literals (`@...`) | Supported | `test/temporal_literals_test.rb`; ISO 8601 with optional timezone (`Z`/`±HH:MM`) |
| `today()`, `now()`, `time()` | Supported | `test/temporal_now_test.rb` |
| Temporal literal precision | Supported | `test/temporal_partial_literal_test.rb`; partial-precision literals (`@2014`, `@2015-02`, `@2015T`, `@2015-02T`, `@2014-01-01T08`, `@T14`, `@T14:34`) are accepted and carry their precision; comparison/equality of differing precisions returns empty (`test/temporal_precision_test.rb`) |
| `precision()`, `lowBoundary()`, `highBoundary()` | Supported for temporal values | `test/temporal_precision_test.rb`, `test/temporal_boundary_test.rb`; default timezone extremes (`+14:00` lowest, `-12:00` highest), reduced-precision results, out-of-range precision returns empty; Decimal and Quantity receivers raise `UnsupportedFeatureError` |
| Temporal component extractors (`year`, `month`, `day`, `hour`, `minute`, `second`, `millisecond`) | Supported | `test/temporal_components_test.rb`; `millisecond()` on `DateTime` reads `sec_fraction * 1000` |
| Temporal timezone (`timezone()`, `timezoneOffset()`) | Supported | `test/temporal_components_test.rb` |
| Temporal same-type comparison | Supported | `test/temporal_comparison_test.rb`; differing precision returns empty, sub-second precision compares numerically, cross-type returns empty |
| Temporal arithmetic with Quantity/Duration | Partially supported | Date/DateTime `+`/`-` with fixed-duration units (`s`, `ms`, `min`, `h`, `d`, `wk`) and with calendar-duration keywords (`1 month`, `1 year`); the UCUM units `mo`/`a` are rejected with `:unsupported_temporal_unit`; `test/temporal_arithmetic_test.rb`, `test/quantity_unit_coverage_test.rb` |
| FHIR primitive extension accessor (`._<name>`) | Supported | `test/primitive_extensions_test.rb`; returns the underlying `{value, extension}` container or empty per FHIRPath 2.0.0 |
| Quantity/UCUM | Supported | `test/quantity_test.rb`, `test/quantity_edge_cases_test.rb`, and `test/quantity_unit_coverage_test.rb`; immutable Decimal-backed quantities, case-sensitive dimensional conversion for the explicitly bounded dependency-free subset (`m`/`cm`/`mm`/`km`, `g`/`kg`/`mg`/`Mg`/`ug`/`ng`, `L`/`mL`/`ML`/`uL`, `mol`/`mmol`/`umol`, `s`/`min`/`h`, the alternative-symbol atoms `[in_i]`/`[lb_av]`/`[s]`, FHIRPath calendar-duration units, and products/quotients such as `mmol/L`); implicit digit exponents (`m2`, `cm3`) and explicit `m^2` are both accepted; unsupported units are rejected rather than treated as dimensionless, incompatible calculations and mixed Quantity/scalar addition return empty, same-dimension Quantity division returns a Decimal ratio, Quantity×Quantity composes base units (`2.0 'cm' * 2.0 'm'` is `0.040 'm2'`), `comparable()` reports shared dimensions, and system/code metadata is preserved without changing unit equality |
| Advanced conversion/math/string/regex | Deferred | not in standard registry |
| FHIR R4 model adapter (default) | Supported | `test/r4_model_test.rb`; dependency-free `FHIRPath::FHIR::R4::ModelProvider`; omitted `model:` defaults to R4, `model: nil` selects PlainModel |
| FHIR R4 `Observation.value[x]` logical navigation | Supported | R4 choice vectors; `valueQuantity` and `valueString` resolve through `value`, absent choice is empty; this is now the default behavior when no `model:` is passed |
| FHIR R4 logical-type `is`/`as` over resolved choice values | Supported | `test/r4_type_operator_test.rb` and R4 choice vectors; navigation records the resolved choice variant's FHIR logical type (`Quantity`, `string`, ...) and `is`/`as` test against it; empty-in/empty-out and PlainModel (no model metadata) behavior are covered; the type is recorded for collections produced directly by navigation (operators that rebuild collections, such as `union`, do not yet propagate it); resource hierarchy and recursive resource-type `is`/`as` remain deferred; this is now the default behavior when no `model:` is passed |
| FHIR R5 model adapter | Deferred | no R5 provider |
| Broader FHIR choice elements and primitive extensions | Host-dependent | first R4 slice only covers `Observation.value[x]` |
| `resolve()` and terminology | Host-dependent | requires injected host services |
| Official HL7 shared test suite | Supported | Full R4 suite (935 cases) imported via `FHIRPath::Conformance::Importer.from_manifest` with `load_full_suite: true`; XML fixtures resolved to verified JSON counterparts or converted via `FHIRXmlConverter` (fail-closed on unsupported structures); runner classification (2026-09-10): 509 pass, 383 defect, 43 unsupported, 0 not-run; see `docs/support-matrix.md` for the current disposition of each group. Deferred: `type`, `convertsTo*`/`toXxx` conversions, string functions (`startsWith`, `endsWith`, `matches`, `replace`), `extension`, `toString`/`convertsToString`, collection functions (`sort`, `distinct`, `intersect`, `subsetOf`). Host-dependent: `resolve()`, terminology, broader R4 choice elements, R5 model adapter. |
| FHIRPath 3.0 STU3 aggregate functions (`sum`, `avg`, `max`, `min`) | Supported | shipped by default as the first STU3-subset additions to the standard registry — a deliberate, documented exception (declared `stu3-aggregate-functions` in `Capability.current.trial_use` with `fhirpath` staying `2.0.0`; see `docs/api.md` and `docs/support-matrix.md`); semantics follow the aggregate row above |
| Other FHIRPath 3.0 STU3 features | Deferred | not enabled by default |
| Network I/O/global evaluator state | Not supported by design | pure evaluation boundary |

The matrix is a release-review aid, not a conformance percentage. A future release must update it together with tests, capability output, and the changelog.
