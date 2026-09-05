# Release support matrix

Status: `pre-release` (`0.1.0.pre1`)

This is the release-facing support matrix. It is deliberately narrower than
"FHIRPath-compatible": every supported claim must have executable evidence, and
every deferred or host-dependent behavior remains a limitation in release notes.
The detailed behavior table is maintained in [`feature-matrix.md`](feature-matrix.md).

## Language and package declaration

| Field | Declared value |
|---|---|
| Gem | `fhirpath` |
| Normative FHIRPath target | `2.0.0` |
| Release channel | `pre-release` |
| License | MIT |
| Supported Ruby CI matrix | Ruby `3.2`, Ruby `3.3` |
| Model support | Model-independent plain Ruby Hash/Array/object navigation |
| FHIR model releases | None bundled |
| Trial-use features | None enabled by default |

The packaged gem repeats the target and capability declaration in gem metadata:
`fhirpath_target`, `capability_set`, `release_status`, and
`support_matrix_uri`. `FHIRPath::Capability.current` is the runtime source for
the same target and capability-set values.

## Published capability set

These stable identifiers describe the behavior included in the current package:

- `parser` — complete-input parsing, immutable AST nodes, and source spans;
- `immutable-ast` — immutable parse/compile boundaries;
- `collection-evaluation` — explicit empty, singleton, and multi-item results;
- `plain-model-navigation` — Hash, Array, and safe simple-object navigation;
- `primitive-values` — strings, Booleans, integers, decimals, and scientific notation;
- `arithmetic` — unary/numeric arithmetic and string `+`;
- `comparison-and-equivalence` — relational comparison, equality, and equivalence;
- `boolean-logic` — empty-aware Boolean operators;
- `union-membership-and-type-operators` — union, `in`, `contains`, `is`, and `as`;
- `collection-functions` — `where`, `select`, `first`, `exists`, `count`, `empty`, `not`, `all`, and Boolean aggregates;
- `focus-variables` — `$this`, `$index`, and `$total`;
- `external-constants` — explicitly supplied `%name` values;
- `custom-functions` — explicitly registered functions;
- `compiled-expression-reuse` — immutable reusable compiled expressions; and
- `structured-errors` — typed errors with machine-readable codes and source spans.

## Explicitly unsupported or deferred

The release must continue to state these limitations:

- complete official HL7 shared-suite conformance and its importer;
- date/time literals and values;
- quantity and UCUM semantics;
- advanced conversion, math, string, regular-expression, navigation, and aggregate functions;
- complex literals and additional standard value types;
- standard environment variables beyond explicitly supplied external constants;
- FHIRPath `3.0` STU3 features; and
- network I/O and global evaluator state in the pure evaluation boundary.

## Host-dependent behavior

The gem does not bundle these adapters or services. Callers must supply and
validate them at the host boundary before claiming support:

- FHIR R4/R5 model adapters;
- choice-element metadata and primitive extensions; and
- `resolve()` and terminology services.

## Evidence and promotion policy

Each tagged release runs the Ruby 3.2/3.3 matrix, tests, RuboCop, checked-in
compatibility vectors, package build, isolated installed-gem smoke test, and
coverage validation. Defect or silently skipped vector cases fail the release;
unsupported and host-dependent cases are retained as classified evidence.

The project remains pre-release until the release channel is deliberately
promoted after the official conformance and remaining model/host gates are
resolved. A successful build alone never changes the support claims.
