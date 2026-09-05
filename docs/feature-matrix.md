# Feature and capability matrix

Status: `0.1.0.pre1`; target release: FHIRPath `2.0.0`; publication contract: [`support-matrix.md`](support-matrix.md)

This matrix is deliberately conservative. `Supported` means the behavior is exercised by the Ruby test suite or the checked-in vector corpus. `Deferred` means callers should expect a structured unsupported/unknown error. `Host-dependent` requires an adapter or injected service that is not shipped here.

| Area | Status | Evidence / boundary |
|---|---|---|
| `require "fhirpath"`, version | Supported | `test/fhirpath_test.rb` |
| Parse, immutable AST, source spans | Supported | foundation/parser tests |
| Complete-input validation | Supported | parser regression tests |
| String, Boolean, integer, decimal literals | Supported | foundation/core compatibility tests |
| Scientific notation | Supported | core compatibility tests |
| Empty and comma-separated collections | Supported | parser/evaluator tests |
| Hash/Array/plain object navigation | Supported | foundation tests; `PlainModel` |
| Unary/numeric arithmetic and string `+` | Supported | parity/core compatibility tests; `+` propagates empty operands; a zero divisor for `/`, `div`, `mod` yields an empty collection, while `+`, `-`, `*` operate on zero normally |
| Relational comparison | Supported | parity/core compatibility tests |
| Collection equality/equivalence | Supported | core compatibility tests and vectors |
| Finite JSON `Float` treated as `Decimal` | Supported | evaluator correctness tests; a finite `Float` (e.g. from `JSON.parse`) compares, equals, arithmetically combines, and satisfies `is Decimal`; `NaN`/`Infinity` are rejected as non-numeric |
| String `&` concatenation | Supported | core compatibility tests; empty operands are treated as `''` |
| Empty-aware Boolean operators | Supported | foundation/core compatibility tests |
| Union, `in`, `contains`, `is`, `as` | Supported | core compatibility tests and vectors; union eliminates duplicates from both operands using `=` equality in first-seen order; `in`/`contains` require a singleton operand and follow the empty-collection rules |
| Indexers | Supported | foundation/parity tests |
| `where`, `select`, `first`, `last`, `tail`, `take`, `skip`, `exists`, `count` | Supported | `test/subsetting_functions_test.rb` |
| `empty`, `not`, `all`, Boolean aggregates | Supported | core compatibility tests |
| `$this`, `$index`, `$total` | Supported | parity tests |
| Explicit external constants | Supported | foundation/core compatibility tests; values may come from `variables:` or an explicitly injected `HostServices` constant provider |
| Missing external constant provider | Supported | `test/host_services_test.rb`; raises `UnknownConstantError` with code `:unknown_constant` and performs no fallback I/O |
| Constant-provider failures and redaction | Supported | `test/host_services_test.rb`; raises generic `HostError` while retaining `original_cause` outside public serialization |
| Host callback configuration/reentrancy | Supported | `test/host_services_test.rb`; `HostServices` is immutable and each evaluation receives a fresh context |
| Custom registered functions | Supported | API/foundation tests |
| Compiled-expression reuse | Supported | API/foundation tests |
| Stable structured engine errors | Supported | API/foundation/parser tests |
| Date/time literals and values | Deferred | no temporal value implementation |
| Quantity/UCUM | Deferred | no unit service or quantity implementation |
| Advanced conversion/math/string/regex | Deferred | not in standard registry |
| FHIR R4 model adapter (`model: :r4`) | Supported | `test/r4_model_test.rb`; dependency-free `FHIRPath::FHIR::R4::ModelProvider` |
| FHIR R4 `Observation.value[x]` logical navigation | Supported | R4 choice vectors; `valueQuantity` and `valueString` resolve through `value`, absent choice is empty |
| FHIR R5 model adapter | Deferred | no R5 provider |
| Broader FHIR choice elements and primitive extensions | Host-dependent | first R4 slice only covers `Observation.value[x]` |
| `resolve()` and terminology | Host-dependent | requires injected host services |
| Official HL7 shared test suite | Deferred | importer is not yet bundled |
| FHIRPath 3.0 STU3 features | Deferred | not enabled by default |
| Network I/O/global evaluator state | Not supported by design | pure evaluation boundary |

The matrix is a release-review aid, not a conformance percentage. A future release must update it together with tests, capability output, and the changelog.
