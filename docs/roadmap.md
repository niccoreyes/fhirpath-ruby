# FHIRPath Ruby parity roadmap

Status: implementation roadmap proposal
Date: 2026-09-04
Repository: `fhirpath-ruby`
Related design: [`docs/architecture.md`](architecture.md)

Implementation note: the first pure-core parity slice is now implemented and
documented in [`docs/first-slice.md`](first-slice.md). Its focused tests cover
the end-to-end lexer/parser/AST/evaluator path for literals, collections,
arithmetic, comparison, Boolean logic, navigation, predicates, indexers, and
structured errors. The official shared-suite importer, differential runner,
and the remaining Stage 1 acceptance cases remain future work; this note is
not a claim of complete FHIRPath conformance.

## 1. Roadmap objective

Turn the current loadable Ruby namespace into a dependable FHIRPath runtime without making an unbounded “implement everything” promise. The roadmap uses the HL7 FHIRPath specification and shared test cases as the conformance authority.[1][2][3]

It uses `fhirpath-py` as the first behavioral compatibility reference, with `fhirpath.js`, Firely, and HAPI as independent architecture and differential-test references.[4]

The baseline target is:

- normative FHIRPath 2.0.0 first;
- a separately reported and feature-gated subset of FHIRPath 3.0.0 STU3 later;
- model-independent core first;
- a versioned FHIR model adapter after the pure core; and
- host services (`resolve`, terminology, external constants, tracing, and optional async/cancellation) only behind explicit interfaces.

A stage is not complete because its classes exist. It is complete when its focused tests, relevant shared cases, differential checks, documentation, and release evidence pass the exit gate listed below.

## 2. Delivery rules

### 2.1 Vertical-slice discipline

Each slice follows this order:

1. define the semantic behavior and target release;
2. add a focused test that fails for the missing behavior (RED);
3. implement the smallest Ruby-native change (GREEN);
4. run the focused tests, full unit suite, formatter/linter, and type/conformance checks applicable to the slice;
5. compare selected cases with an independent engine; and
6. record unsupported, host-dependent, and defect classifications before starting the next slice.

No commit or publication is implied by this document. Versioning, dependency additions, commits, pushes, and releases remain separate approval gates.

### 2.2 Conformance labels

Every test and report entry uses one of these labels:

- `normative`: required by the selected FHIRPath 2.0 target;
- `stu3`: FHIRPath 3.0 STU3 behavior, enabled only when its capability is on;
- `host-dependent`: requires a model provider, terminology service, resolver, or other host service;
- `unsupported`: recognized scope but intentionally not implemented in the current stage; or
- `defect`: behavior that should be supported but currently fails.

Do not report a single aggregate “FHIRPath compatible” percentage without showing these categories and the target release.

## 3. Staged roadmap

### Stage 0 — freeze the conformance contract

Purpose: remove ambiguity before implementation effort accumulates.

Deliverables:

- `Capability` representation for FHIRPath release, STU feature flags, model release, and host services;
- public API contract for `parse`, `compile`, `evaluate`, and `evaluate_first`;
- result policy: collection by default, explicit first-item convenience;
- error taxonomy with source-span fields;
- grammar revision and official/shared test-suite revisions recorded in the repository;
- a feature matrix mapping grammar alternatives and standard function groups to test IDs;
- dependency/license policy for parser, decimal, temporal, and UCUM libraries; and
- architecture decisions recorded in `docs/architecture.md`.

Exit gate:

- A reviewer can determine from the capability and docs whether a result is normative, STU3-gated, model-dependent, or unsupported.
- An invalid expression cannot be accepted as a valid prefix in the planned parser contract.
- At least one example demonstrates collection output, first-item output, external variables, and a structured error.

### Stage 1 — pure-core vertical slice

Purpose: prove the full parse → AST → evaluate path with semantics that expose the important architectural boundaries.

Scope:

- lexer/parser for the slice’s grammar subset and complete-input validation;
- immutable AST nodes with source spans;
- `Collection`, `EvaluationContext`, and nested focus/closure handling;
- `PlainModel` for Hash, Array, and simple Ruby object navigation;
- Boolean, integer, decimal, and string literals;
- member navigation, indexing, and empty navigation;
- `where` and `select` with delayed predicates;
- `first()` and `exists()` with and without criteria;
- equality and the selected empty-aware Boolean operators (`and`, `or`, `implies`); and
- public `parse`, `compile`, `evaluate`, and `evaluate_first` APIs.

Representative acceptance expressions:

```ruby
resource = {
  "resourceType" => "Patient",
  "active" => true,
  "name" => [
    { "use" => "official", "given" => ["Ada", "Augusta"] },
    { "use" => "nickname", "given" => ["Addie"] }
  ]
}

FHIRPath.evaluate(resource, "Patient.name.where(use = 'official').given").to_a
# => ["Ada", "Augusta"]

FHIRPath.evaluate(resource, "Patient.name[0].given.first()").to_a
# => ["Ada"]

FHIRPath.evaluate(resource, "Patient.name.exists(use = 'nickname')").to_a
# => [true]
```

Tests must cover:

- missing member → empty collection;
- arrays flatten at navigation boundaries according to the standard;
- singleton and multi-item behavior;
- nested `$this` and predicate focus;
- empty-aware `and`, `or`, and `implies` truth tables;
- string escapes and malformed/trailing input;
- source spans on parse and evaluation errors; and
- reuse of one compiled expression across independent resources.

Exit gate:

- Focused tests pass and the complete existing test suite remains green.
- The compiled expression is immutable and does not retain the prior resource, variables, focus, index, or trace state.
- Differential runs against `fhirpath-py` cover the slice’s supported cases; every difference has a classification.
- No FHIR-specific model dependency or network service is required.

### Stage 2 — normative value semantics and function families

Purpose: implement the rest of the model-independent FHIRPath 2.0 behavior in coherent semantic groups.

Recommended order:

1. collection combining/subsetting and ordering/duplicate rules;
2. type operators and conversions;
3. exact Decimal operations and numeric comparisons;
4. Date, DateTime, and Time values, including partial precision and timezone rules;
5. Quantity values and a narrow UCUM service boundary;
6. string functions and regex behavior;
7. math functions;
8. date/time functions and arithmetic;
9. tree navigation (`children`, `descendants`);
10. remaining existence/filtering/combining functions; and
11. standard aggregate behavior after empty and singleton policies are locked.

Deliverables:

- dedicated `Value::*` classes and semantic comparison helpers;
- `FunctionSpec` metadata for each implemented standard function;
- expected-error fixtures for type errors, singleton violations, invalid units, and invalid conversions;
- official shared-suite importer/reporter; and
- ported `fhirpath-py` YAML cases with original fixture paths and an explicit implementation classification.

The `fhirpath-py` registry shows why this must be metadata-driven: it distinguishes arity, nullable inputs, variadic parameters, expression parameters, root expressions, type specifiers, and operators rather than treating all arguments as eager values.[5][6] Its special nodes also show that decimal, temporal, quantity, and model-path behavior needs more than raw Ruby primitives.[7]

Exit gate:

- All selected normative function groups have either passing tests or an explicit `unsupported` entry in the capability/report.
- Decimal, temporal, quantity, equality, equivalence, empty, and singleton edge cases have direct tests.
- The official/shared test report separates normative failures from host-dependent cases.
- No convenience conversion changes the evaluator’s internal collection semantics.

### Stage 3 — FHIR model adapter

Purpose: expose FHIR logical model navigation without coupling the language core to one Ruby FHIR package.

Scope:

- `ModelProvider` protocol;
- versioned metadata loading;
- resource/type roots;
- choice elements such as `Observation.value`;
- primitive extensions;
- logical type checks and `ofType`/`as` behavior;
- contained resources and reference shape as far as pure model navigation permits; and
- separate FHIR fixtures for the selected release, initially R4 or the release approved in Stage 0.

Deliverables:

- `FHIRPath::Model::Plain` remains usable without a FHIR dependency;
- `FHIRPath::FHIR::R4::ModelProvider` (or the approved first release adapter);
- model metadata version and source recorded in the repository;
- tests for all choice variants used by the first adapter;
- tests for missing fields, primitive extensions, resource type roots, and logical paths; and
- Capability output that names the installed model release.

Separate FHIR model packages are a deliberate pattern rather than an accidental packaging detail: `fhirpath-py` uses release-specific JSON maps and `fhirpath.js` ships FHIR context packages.[7][9] HAPI also isolates model/version behavior in adapters.[10]

Exit gate:

- Core tests pass with no FHIR dependency.
- FHIR fixture tests demonstrate logical properties rather than raw JSON-key-only traversal.
- Choice fields, primitive extensions, and type operators have expected results and expected errors.
- Differential results are classified as standard, model, or host differences.

### Stage 4 — host services and operational hardening

Purpose: add controlled integration points without contaminating pure evaluation.

Scope:

- external constant provider;
- `resolve()` reference provider;
- terminology provider boundary;
- trace sink and redaction policy;
- cancellation/async policy only if a real host use case requires it;
- host function registration with namespaces and no silent standard-function shadowing;
- compiled-expression cache ownership and invalidation; and
- concurrency/reentrancy tests.

Firely and HAPI both make host services injectable: Firely’s FHIR evaluation context includes terminology and element resolution, and HAPI’s context supports reference and constant resolution.[12][14] `fhirpath.js` documents optional terminology URLs, server access, asynchronous functions, and trace hooks.[9] Ruby should provide analogous capability without assuming that all evaluation is networked.

Exit gate:

- Pure evaluation remains deterministic when no host services are supplied.
- Host failures are `HostError` with the original cause available without exposing secrets.
- Resolver/terminology calls are bounded and auditable by the embedding application.
- Compiled expressions are safe for concurrent evaluations when the documented registry/model configuration is shared.
- Differential tests mark host-dependent cases separately from core conformance.

### Stage 5 — FHIRPath 3.0 STU3 feature lane

Purpose: add trial-use behavior without weakening the normative default.

Candidate features:

- `Long` values and literals;
- instance selectors/object construction;
- sort direction syntax;
- aggregate and reflection additions;
- `repeatAll`; and
- other named additions confirmed against the selected 3.0 STU3 specification snapshot.

Each feature is a separate capability, test group, and release-note entry. A parser acceptance is not sufficient: the evaluator, type system, error behavior, and result conversion must all be covered.

Exit gate:

- The feature is off by default unless the project explicitly changes its default target.
- Shared and differential tests identify the exact target and engine versions.
- No STU3 syntax or function silently appears in the normative 2.0 capability report.
- A compatibility note describes known differences from `fhirpath-py`, `fhirpath.js`, Firely, or HAPI where applicable.

## 4. Test and oracle plan

### 4.1 Test layers

| Layer | Question answered | When added |
|---|---|---|
| Unit tests | Does one lexer/parser/value/function rule behave as designed? | Every slice |
| AST/source tests | Is structure and source location stable? | Stage 0–1 |
| Official/shared suite | Does behavior conform to published shared cases? | Stage 1 importer, Stage 2 gate |
| `fhirpath-py` compatibility fixtures | Does the Ruby translation agree with the first reference engine? | Stage 1 onward |
| Differential tests | Is a difference standard, release, model, host, or defect? | Stage 1 onward |
| Property/edge tests | Are empty, singleton, precision, ordering, lazy-branch, and nesting rules robust? | Stage 1 onward |
| FHIR model tests | Does logical FHIR navigation work for a named release? | Stage 3 |
| Concurrency/cache tests | Is compiled evaluation isolated and reusable? | Stage 4 |
| Conformance report | Can release claims be audited? | Stage 0 onward |

The `fhirpath-py` test harness loads YAML cases, nested groups, resource fixtures, variables, models, and expected results, but its comparison helper also stringifies some values and synthesizes expected expressions. Port the fixture provenance while replacing that comparison with typed expected values and structured expected errors.[8]

### 4.2 Differential runner contract

For every pinned expression/resource pair, record:

```text
suite, suite_commit, expression, input_fixture, model,
expected_result_or_error, actual_result_or_error,
standard_target, host_features, classification
```

Run the Ruby engine against at least one independent implementation. `fhirpath.js` is a practical JavaScript/Node reference; Firely or HAPI is preferable for a second independent implementation when the relevant runtime is available. Do not declare the majority result correct without checking the HL7 specification.

### 4.3 Failure policy

A test can be skipped only with a reason and capability label. “Not implemented” is not a pass. Release summaries must report:

- passed;
- failed;
- unsupported;
- host-dependent; and
- not run, with reason.

## 5. Compatibility and supply-chain gates

Before adding dependencies or distributing a gem:

- record exact dependency versions and licenses;
- preserve notices for `fhirpath-py`/`fhirpath.js`/Firely/HAPI only if code or assets are actually reused;
- prefer original Ruby source derived from behavior and published grammar;
- audit ANTLR generator/runtime terms if ANTLR is selected;
- document Decimal, temporal, and UCUM dependency behavior; and
- keep the project’s own license decision separate from the licenses of reference implementations.

The reviewed implementations use materially different licensing and parser/runtime arrangements, so source-level copying is not a neutral shortcut.[4][9][11]

HAPI’s repository carries its own Apache 2.0 notice.[13]

## 6. First-slice implementation backlog

This is the recommended work order after Stage 0:

1. Add `FHIRPath::Error`, `SourceSpan`, and deterministic error serialization tests.
2. Add `Collection` with empty/singleton/multiple-item helpers and enumerable behavior.
3. Add immutable AST base classes and literal/member/index/function/binary nodes.
4. Add parser driver and malformed/trailing-input tests.
5. Add `PlainModel` member/index navigation tests.
6. Add evaluator dispatch for literals, member paths, and indexers.
7. Add `EvaluationContext#derive` for nested focus and variable isolation.
8. Add `FunctionSpec`/`FunctionRegistry` and `where`/`select` delayed argument support.
9. Add `first` and `exists` functions.
10. Add equality and empty-aware Boolean operations.
11. Add public `compile`/`evaluate`/`evaluate_first` wrappers.
12. Add compiled-expression reuse/concurrency regression tests.
13. Import a small official/shared subset and run a differential harness against `fhirpath-py`.
14. Update the capability report and README only after the slice’s evidence exists.

## 7. Definition of done for the roadmap

The roadmap is delivering useful parity when:

- the gem declares a precise FHIRPath target and enabled feature set;
- core results preserve collection semantics and callers have an explicit first-item API;
- parse/evaluation/host errors are structured and source-located where applicable;
- every delayed function argument is evaluated in the correct derived context;
- model-independent and FHIR-specific tests are separated;
- official/shared, compatibility, differential, and edge-test evidence is reported rather than implied;
- host I/O is explicit, injectable, and absent from pure evaluation; and
- release notes state both supported behavior and known unsupported/host-dependent behavior.

The current prototype should continue to state its exact implemented slice and
the remaining unsupported behavior until Stage 1 has passed its complete exit
gate. A roadmap is not a conformance claim.

## Sources

[1] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/index.md — HL7 FHIRPath specification
[2] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/images/fhirpath.g4 — HL7 FHIRPath grammar
[3] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/tests.md — HL7 FHIRPath tests page
[4] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/__init__.py — fhirpath-py public API
[5] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/__init__.py — fhirpath-py engine
[6] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/invocations/__init__.py — fhirpath-py invocation registry
[7] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/nodes.py — fhirpath-py nodes and values
[8] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/tests/conftest.py — fhirpath-py test harness
[9] https://raw.githubusercontent.com/HL7/fhirpath.js/master/README.md — HL7 fhirpath.js README
[10] https://raw.githubusercontent.com/HL7/fhirpath.js/master/package.json — HL7 fhirpath.js package metadata
[11] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/src/Hl7.Fhir.Base/FhirPath/FhirPathCompiler.cs — Firely FhirPathCompiler
[12] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/src/Hl7.Fhir.Base/FhirPath/FhirEvaluationContext.cs — Firely FhirEvaluationContext
[13] https://raw.githubusercontent.com/hapifhir/hapi-fhir/master/hapi-fhir-base/src/main/java/ca/uhn/fhir/fhirpath/IFhirPath.java — HAPI IFhirPath API
[14] https://raw.githubusercontent.com/hapifhir/hapi-fhir/master/hapi-fhir-base/src/main/java/ca/uhn/fhir/fhirpath/IFhirPathEvaluationContext.java — HAPI FHIRPath evaluation context
