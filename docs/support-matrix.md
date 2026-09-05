# Release support matrix

Status: `pre-release` (`0.2.0.pre1`)

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
| Model support | Model-independent plain Ruby Hash/Array/object navigation plus dependency-free FHIR R4 JSON adapter |
| FHIR model releases | R4 (`4.0.1`), selectable with `model: :r4` |
| Trial-use features | One declared exception only: the FHIRPath 3.0 STU3 aggregate functions `sum`/`avg`/`max`/`min`, shipped by default in the standard registry (see [Declared STU3-subset exception](#declared-stu3-subset-exception)) |

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

### Declared STU3-subset exception

The normative target stays FHIRPath `2.0.0` and the published capability set
above stays unchanged, but the standard registry ships one STU3 subset by
default as a deliberate, documented exception:

- the FHIRPath 3.0.0 STU3 aggregate functions `sum()`, `avg()`, `max()`, and
  `min()` (published 2026-07-28; absent from normative 2.0.0, which contains
  only `count()`, and absent from the 3.0.0 ballot);
- `FHIRPath::Capability.current` keeps `fhirpath: '2.0.0'` and reports this
  subset in `trial_use` under the marker `stu3-aggregate-functions`, so the
  capability report (`Capability#to_h`) always names the STU3 behavior it
  ships and never folds it silently into the normative claims;
- `trial_use` is a surface declaration, not a registry gate: the marker does
  not disable or enable functions in `FHIRPath::FunctionRegistry.standard`.
  A caller that needs a hard 2.0.0-only function set must supply its own
  registry built without the aggregate functions; that enforcement is not
  implemented in the current capability surface.

The functions are supported; see [`feature-matrix.md`](feature-matrix.md) for
behavioral evidence and [`docs/api.md`](api.md) for the runtime declaration.

## Explicitly unsupported or deferred

The release must continue to state these limitations:

- complete official HL7 shared-suite conformance and its importer;
- date/time literals and values;
- quantity and UCUM semantics;
- advanced conversion, math, string, regular-expression, and navigation functions, and the general-purpose `aggregate()` function;
- complex literals and additional standard value types;
- standard environment variables beyond explicitly supplied external constants;
- FHIRPath `3.0` STU3 features beyond the declared `stu3-aggregate-functions` subset; and
- network I/O and global evaluator state in the pure evaluation boundary.

## Host-dependent behavior

The gem bundles the dependency-free R4 JSON adapter described above. Callers
must supply and validate these remaining adapters or services at the host
boundary before claiming support:

- FHIR R5 and broader release-specific model adapters;
- broader choice-element metadata and primitive extensions; and
- `resolve()` and terminology services.

## Evidence and promotion policy

Each tagged release runs the Ruby 3.2/3.3 matrix, tests, RuboCop, checked-in
compatibility vectors, package build, isolated installed-gem smoke test, and
coverage validation. Defect or silently skipped vector cases fail the release;
unsupported and host-dependent cases are retained as classified evidence.

The project remains pre-release until the release channel is deliberately
promoted after the official conformance and remaining model/host gates are
resolved. A successful build alone never changes the support claims.
