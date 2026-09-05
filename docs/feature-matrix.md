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
| `where`, `select`, `first`, `exists`, `count` | Supported | foundation/parity tests |
| `empty`, `not`, `all`, Boolean aggregates | Supported | core compatibility tests |
| `$this`, `$index`, `$total` | Supported | parity tests |
| Explicit external constants | Supported | foundation/core compatibility tests |
| Custom registered functions | Supported | API/foundation tests |
| Compiled-expression reuse | Supported | API/foundation tests |
| Stable structured engine errors | Supported | API/foundation/parser tests |
| Date/time literals and values | Deferred | no temporal value implementation |
| Quantity/UCUM | Deferred | no unit service or quantity implementation |
| Advanced conversion/math/string/regex | Deferred | not in standard registry |
| FHIR R4/R5 model adapters | Host-dependent | plain model only |
| Choice elements and primitive extensions | Host-dependent | requires versioned model provider |
| `resolve()` and terminology | Host-dependent | requires injected host services |
| Official HL7 shared test suite | Deferred | importer is not yet bundled |
| FHIRPath 3.0 STU3 features | Deferred | not enabled by default |
| Network I/O/global evaluator state | Not supported by design | pure evaluation boundary |

The matrix is a release-review aid, not a conformance percentage. A future release must update it together with tests, capability output, and the changelog.
