# fhirpath-py conformance review

> Historical compatibility audit snapshot (2026-09-04). Current supported behavior is tracked in [`docs/feature-matrix.md`](feature-matrix.md) and [`docs/conformance.md`](conformance.md).

Status: focused compatibility audit
Date: 2026-09-04
Ruby snapshot: `b172b32` (`main`)
fhirpath-py snapshot: `19f6316` (`2.2.4`)

This is a compatibility audit, not a conformance claim. The HL7 FHIRPath specification and shared test cases remain normative; `fhirpath-py` is a useful independent behavior reference.

## Executive finding

Do not translate the Python implementation wholesale. The safest path is:

1. manually implement the high-value semantic corrections in the Ruby-native evaluator;
2. add a small public-API differential-vector workflow that uses `fhirpath-py` only as a reference oracle; and
3. import the official shared suite separately, with every case classified as `pass`, `defect`, `unsupported`, or `host-dependent`.

A source generator would copy the least stable parts of `fhirpath-py` (generated ANTLR parser, dictionary AST, mutable context, and implementation-specific `ResourceNode` behavior) while obscuring the Ruby API and licensing provenance. A test-vector generator gives most of the parity benefit without making those internals a contract.

## Evidence collected

### Ruby project

- Public API is in `lib/fhirpath.rb`; parse/compile/evaluate boundaries are present.
- The parser/evaluator currently cover primitive literals, empty and comma-separated collection literals, member navigation, indexers, `where`, `select`, `first`, `exists`, `count`, arithmetic, selected comparisons/equality, and empty-aware Boolean operators.
- `FunctionRegistry.standard` contains only `where`, `select`, `first`, `exists`, and `count` (`lib/fhirpath/functions.rb:14-40`). The evaluator special-cases these in `lib/fhirpath/evaluator.rb:147-168`.
- `Value::*` classes exist, but the evaluator still returns raw Ruby values (`lib/fhirpath/evaluator.rb:23-45`); type metadata is not connected to navigation or type operators.
- `PlainModel` supports String/Symbol Hash keys and Struct members only (`lib/fhirpath/model.rb:15-37`). It intentionally does not perform expression-selected Ruby method dispatch.
- Local verification passed: `bundle exec rake test` (29 runs, 102 assertions), `bundle exec rubocop`, and `git diff --check`. The commands emit a pre-existing RubyGems 3.0.3.1 warning about `required_ruby_version`; it did not fail the checks.

### fhirpath-py reference

The pinned reference exposes `evaluate`, `compile`, `compile_as_array`, and `compile_as_first` in `fhirpathpy/__init__.py`. Its invocation registry contains the semantic families missing from Ruby: existence, filtering, combining, conversion, string, math, temporal, tree navigation, type, collection, Boolean, and aggregate functions (`engine/invocations/__init__.py`).

Its test corpus is organized by the same families and includes YAML cases, AST fixtures, model fixtures, resources, variables, quantities, extensions, and FHIR R4 cases. `tests/conftest.py` shows that cases carry expression, resource/input fixture, variables, model, result, and error metadata.

The complete upstream pytest suite was not run in this environment: the project's pinned `pyyaml==5.4` failed to build under the available CPython 3.14 toolchain (`cython_sources` build error). The public API was nevertheless exercised through an isolated `uv run --with fhirpathpy` probe, and the source/test corpus was inspected directly. The probe results below are therefore labeled as observed reference behavior, not as an assertion that the full upstream suite passed locally.

## Observed comparison probes

The same expressions were sent to both public APIs where syntax allowed it:

| Case | Ruby result | fhirpath-py result | Classification |
|---|---|---|---|
| `'abc' = 'abc'` | `[true]` | `[True]` | parity |
| `'ab c' ~ 'Ab  C'` | `[false]` | `[True]` | Ruby defect: equivalence must normalize internal whitespace and case |
| `1.1 ~ 1.101` | `[false]` | `[True]` | Ruby defect: equivalence uses least-precise decimal semantics |
| `1 | 2` | `UnsupportedFeatureError(:unsupported_operator)` | `[1, 2]` | Ruby missing union |
| `1 in (1 | 2)` | parse trailing-input error | `[True]` | Ruby missing membership operators/parser production |
| `1 is integer` | parse trailing-input error | `[False]` in the no-model probe | Ruby missing type-operator syntax; reference's no-model result should be checked against the normative suite before using as expected behavior |
| `@2018 = @2018` | lexer `invalid_token` | `[True]` | Ruby missing DateTime literals/values |
| `'a' + 'b'` | `TypeError(:expected_number)` | `['ab']` | Ruby defect: string addition is a standard operation |
| `{}.empty()` | `UnknownFunctionError(:unknown_function)` | `[True]` | Ruby missing standard `empty()` |
| `{1, 2} = {1, 2}` | `SingletonError(:singleton_required)` | `[]` | not a useful parity vector: Ruby's non-empty brace literal is not in the pinned Python grammar; use union expressions for standard collections |

The probe also confirms that Ruby's strict complete-input parser is a good foundation: unsupported syntax is not silently evaluated as a valid prefix. The compatibility fix should add recognized productions and explicit unsupported errors, not loosen end-of-input validation.

## Gap inventory by semantic area

### P0 — correctness defects in behavior already represented by the Ruby API

#### 1. Equality/equivalence only accept singleton operands

`Evaluator#equality` (`lib/fhirpath/evaluator.rb:242-260`) calls `require_singleton` for every non-empty operand. FHIRPath equality/equivalence also define collection behavior. The fhirpath-py corpus explicitly tests equal collections, length mismatch, order-dependent equality, and order-independent equivalence (`tests/cases/6.1_equality.yaml`, especially the collection section).

Required changes:

- Add collection equality with equal lengths and pairwise equality in order.
- Add collection equivalence with equal lengths and order-independent equivalence, without accidentally treating duplicate values as a set unless the specification says so for that operation.
- Preserve empty behavior: `empty = value` and `empty != value` are empty; `empty ~ empty` is true; `empty !~ value` is true.
- Keep singleton errors for operators/functions that genuinely require singleton values.

Acceptance cases (resource `{ "left" => [1, 2], "same" => [1, 2], "permuted" => [2, 1], "short" => [1] }`):

- `left = same` => `[true]`
- `left = permuted` => `[false]`
- `left ~ permuted` => `[true]`
- `left = short` => `[false]`
- `{} ~ {}` => `[true]`

Exact implementation focus: `lib/fhirpath/evaluator.rb` equality helpers, `test/parity_slice_test.rb` or a new `test/equality_test.rb`, and `Collection` helpers only if they make ordering/duplicate behavior explicit.

#### 2. Equivalence semantics are too weak

`Evaluator#equivalent?` (`lib/fhirpath/evaluator.rb:353-359`) uses `strip.casecmp?`, which does not collapse repeated internal whitespace. It also delegates numeric equivalence to exact numeric equality, while the reference tests use precision of the least-precise decimal operand.

Acceptance cases:

- `'ab c' ~ 'Ab  C'` => `[true]`
- `'1.100' ~ '1.101'` => `[true]`
- `'1.1' ~ '1.2'` => `[false]`
- `'0' ~ '0.00000010'` => `[true]`
- `'11' ~ '10'` => `[false]`

Exact implementation focus: `lib/fhirpath/evaluator.rb` equivalence helpers, with exact-Decimal precision tests. Do not replace `BigDecimal` with binary Float.

#### 3. Missing standard empty function and string addition

The registry/evaluator do not implement `empty()`, `not()`, `all()`, truth aggregators, or string `+`. `fhirpath-py` covers these in `engine/invocations/existence.py` and `engine/invocations/math.py` and in the corresponding YAML cases.

Minimum acceptance cases:

- `{}.empty()` => `[true]`
- `1.empty()` => `[false]`
- `true.not()` => `[false]`
- `{}` `not()` => empty collection
- `'a' + 'b'` => `['ab']`
- `1 + 2` remains `[3]`
- `{} + 1` remains empty

Exact implementation focus: `lib/fhirpath/functions.rb`, `lib/fhirpath/evaluator.rb`, and focused tests. Use explicit `FunctionSpec` metadata rather than a growing name-only switch.

### P1 — missing standard syntax and operators

#### 4. Union, membership, and type operators

The lexer knows `|`, but `Evaluator#binary` rejects union and concatenate (`lib/fhirpath/evaluator.rb:223-239`). `contains`, `in`, `is`, and `as` are lexed as ordinary identifiers, so expressions are rejected as trailing input rather than parsed as operators.

Required parser work in `lib/fhirpath/parser.rb` and lexer token classification:

- add `in`, `contains`, `is`, and `as` operator tokens;
- preserve the FHIRPath precedence ordering (multiplicative, additive/concatenate, union, inequality, type, equality, membership, Boolean, implies); and
- retain complete-input validation and source spans.

Required evaluator work:

- union: ordered duplicate elimination using equality semantics;
- membership: singleton-left/right rules and empty propagation;
- `is`/`as`: singleton rules, logical type information, and empty behavior.

Do not use the Ruby prototype's `{1, 2}` as the standard vector. The pinned Python grammar only has `{}` as the empty literal; use `(1 | 2)` or resource collections for standard collection cases.

Acceptance cases:

- `(1 | 2) | (2 | 3)` => `[1, 2, 3]`
- `1 in (1 | 2)` => `[true]`
- `(1 | 2) in (1 | 2)` => singleton/type error
- `(1 | 2) contains 1` => `[true]`
- `1 is integer` => `[true]`
- `1 as integer` => `[1]`
- `1 as string` => empty collection

Exact implementation focus: `lib/fhirpath/parser.rb`, `lib/fhirpath/evaluator.rb`, `lib/fhirpath/functions.rb`, `lib/fhirpath/types.rb`, and new operator/type tests.

#### 5. DateTime, Time, Quantity, and literal grammar

The Python grammar accepts `@YYYY[-MM[-DD[...]]]`, `@T...`, quantity units, qualified type names, delimited identifiers, comments, and escaped strings. Ruby currently rejects `@` in the lexer and has no temporal/quantity value classes. `fhirpath-py` keeps `FP_DateTime`, `FP_Time`, `FP_Quantity`, and precision/timezone rules in `engine/nodes.py`.

Implement as dedicated Ruby value objects, not `Date`/`Time` coercions that discard precision:

- `Value::Date`, `Value::DateTime`, and `Value::Time` with partial precision and timezone state;
- `Value::Quantity` with numeric value and canonical unit representation behind a narrow UCUM service boundary; and
- parser tokens for date/time/quantity literals with invalid-value errors.

Acceptance cases should port the date/time sections of `tests/cases/4.1_literals.yaml`, `6.1_equality.yaml`, `6.2_comparision.yaml`, and `5.5_conversion.yaml`, including partial precision (`@2018 = @2018-02` => empty), timezone equivalence, and `1 year`/`12 months` quantity behavior.

Exact implementation focus: `lib/fhirpath/parser.rb`, `lib/fhirpath/types.rb`, `lib/fhirpath/evaluator.rb`, plus new temporal/quantity test files. Record dependency/license decisions before adding a UCUM library.

#### 6. Delimited identifiers, comments, and environment variables

The Ruby lexer only accepts `[A-Za-z_][A-Za-z0-9_]*` names. The reference accepts backtick-delimited identifiers and variables, and hidden line/block comments. Ruby's external constants also only accept bare `%name`; fhirpath-py supports `%` with identifier/string forms and has standard `%context`, `%resource`, and `%ucum` variables.

Acceptance cases:

- `// comment\n1 + 2` and `/* comment */ 1 + 2` => `[3]`
- ``%`a.b() - 1` `` with variable key `a.b() - 1` => the supplied value
- standard `%context`/`%resource` behavior is either implemented or explicitly documented as unsupported
- malformed unterminated comments/backticks produce structured `ParseError`

Exact implementation focus: `lib/fhirpath/parser.rb`, `EvaluationContext`, `HostServices`, and lexer tests.

### P1 — standard function families

Port behavior manually by family, using reference cases as vectors. Suggested Ruby modules and priority:

| Python family | Representative functions | Ruby target |
|---|---|---|
| `existence.py` | `empty`, `not`, `all`, `allTrue`, `anyTrue`, `allFalse`, `anyFalse`, `distinct`, `isDistinct`, `subsetOf`, `supersetOf` | `FHIRPath::Functions::Existence` |
| `filtering.py` | `repeat`, `last`, `tail`, `take`, `skip`, `single`, `ofType`, `extension` | `FHIRPath::Functions::Filtering` |
| `combining.py` / `subsetting.py` | `union`, `combine`, `exclude`, `coalesce`, `intersect` | `FHIRPath::Functions::Combining` / `Subsetting` |
| `misc.py` | `iif`, `trace`, conversions, `toQuantity`, `convertsTo*` | `FHIRPath::Functions::Conversion` / `Utility` |
| `strings.py` | `indexOf`, `substring`, `startsWith`, `endsWith`, `contains`, `upper`, `lower`, `split`, `trim`, `join`, regex, encode/decode | `FHIRPath::Functions::String` |
| `math.py` / `aggregate.py` | `abs`, `ceiling`, `exp`, `floor`, `ln`, `log`, `power`, `round`, `sqrt`, `truncate`, `sum`, `min`, `max`, `avg`, `aggregate` | `FHIRPath::Functions::Math` / `Aggregate` |
| `navigation.py` / `datetime.py` | `children`, `descendants`, `now`, `today`, `timeOfDay` | `FHIRPath::Functions::Navigation` / `DateTime` |

Before adding each family, extend `FunctionSpec` with the metadata needed by that family (value vs expression vs type vs root expression, nullable input, variadic arguments, and capability gate). The current `parameters`/`delayed` fields are a good starting point but cannot express all registry entries safely.

### P2 — model and host compatibility

- `PlainModel` is intentionally narrow and safe. Do not add arbitrary `send`/method dispatch. Add a documented `ModelProvider` implementation for Mapping-like/custom models if desired.
- Add versioned FHIR model adapters and metadata for choice fields (`Observation.value`), primitive extensions, logical FHIR types, and `ofType`/`as`; this is not solvable with raw Hash lookup.
- Add explicit standard variables and host trace support only through `EvaluationContext`/`HostServices`; keep `resolve()` and terminology host-dependent.
- Add typed result helpers only after core collection semantics are stable; `fhirpath-py`'s `compile_as_array`/`compile_as_first` should be a compatibility reference, not a reason to change Ruby's collection-first default.

Exact implementation focus: `lib/fhirpath/model.rb`, `lib/fhirpath/types.rb`, `lib/fhirpath/evaluation_context.rb`, `lib/fhirpath/host_services.rb`, and separate model/host tests.

## Reproducible differential-vector workflow

Add a small, optional reference harness rather than a source generator. Keep it outside the runtime dependency path so the gem remains usable without Python.

Suggested JSONL vector schema:

```json
{"id":"eq-string-001","target":"2.0.0","expression":"'ab c' ~ 'Ab  C'","resource":{},"variables":{},"model":null,"expected":[true],"origin":{"suite":"fhirpath-py","commit":"19f6316","case":"manual"}}
```

For values that JSON cannot preserve, use tagged values, for example `{"$type":"decimal","value":"1.10"}`, `{"$type":"dateTime","value":"2018-02"}`, and `{"$type":"quantity","value":"1","unit":"'year'"}`. Store expected errors as `{ "error": { "class": "...", "code": "..." } }` rather than treating an exception as a pass.

The reference-side generator should:

1. import only `fhirpathpy.evaluate`/`compile`;
2. read a pinned vector input containing resource, expression, variables, and model names;
3. serialize results with explicit type tags; and
4. record the reference commit and source case.

The Ruby-side runner should:

1. load the same vectors;
2. run `FHIRPath.evaluate` with a matching model/host fixture;
3. compare typed collection results and structured errors; and
4. emit a report with `pass`, `defect`, `unsupported`, `host-dependent`, and `not-run` counts.

Use the vector workflow for translation/regression feedback. Use the official HL7 shared XML suite as the release gate. Never generate Ruby evaluator code from Python internals.

## Acceptance plan for the next implementation task

The next implementation slice should be considered complete only when:

- P0 collection equality/equivalence, whitespace/decimal equivalence, `empty()`, and string `+` cases pass;
- operator/parser tests cover union, membership, type operators, and complete-input errors, or each remains explicitly classified as unsupported;
- at least one differential vector file and runner path are documented and reproducible;
- all new behaviors have focused RED-to-GREEN Ruby tests;
- `bundle exec rake test`, `bundle exec rubocop`, and `bundle exec rake build` pass; and
- the capability/README documentation does not claim functions or literal types that are not exercised.

After that slice, prioritize temporal/quantity values, function families, and model adapters in separate vertical slices. Do not mix licensing, gem publication, or live FHIR model migration into the implementation change.

## Sources

- Ruby project: https://github.com/niccoreyes/fhirpath-ruby/tree/b172b32
- HL7 FHIRPath specification: https://hl7.org/fhirpath/
- HL7 FHIRPath grammar: https://raw.githubusercontent.com/HL7/FHIRPath/master/input/images/fhirpath.g4
- fhirpath-py pinned snapshot: https://github.com/beda-software/fhirpath-py/tree/19f6316
- fhirpath-py public API: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/fhirpathpy/__init__.py
- fhirpath-py evaluator/argument binding: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/fhirpathpy/engine/__init__.py
- fhirpath-py invocation registry: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/fhirpathpy/engine/invocations/__init__.py
- fhirpath-py value/model nodes: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/fhirpathpy/engine/nodes.py
- fhirpath-py test harness: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/tests/conftest.py
- fhirpath-py equality cases: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/tests/cases/6.1_equality.yaml
- fhirpath-py string cases: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/tests/cases/5.6_string_manipulation.yaml
- fhirpath-py type cases: https://raw.githubusercontent.com/beda-software/fhirpath-py/19f6316/tests/cases/6.3_types.yaml
- shared FHIR test cases: https://github.com/FHIR/fhir-test-cases
