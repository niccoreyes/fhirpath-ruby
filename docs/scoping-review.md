# FHIRPath specification and implementation landscape

Status: scoping review complete
Date: 2026-09-04
Repository: `fhirpath-ruby`
Decision target: a Ruby FHIRPath engine that can become a dependable FHIRPath runtime, not a source-code port of one existing implementation.

## Executive recommendation

Build a Ruby-native engine against an explicit conformance target: **FHIRPath 2.0.0 (the normative R2 release) plus a feature-gated subset of FHIRPath 3.0.0 STU3**. The publication history identifies 3.0.0 as an R3 trial-use release based on FHIR R4 and dated 2026-07-28; its continuous build may change independently.[1] This avoids silently claiming support for newer trial-use behavior while still leaving room for Long, instance selectors, aggregates, and other additions.

Use the HL7 grammar and shared tests as the specification inputs, use `fhirpath-py` as the first compatibility reference, and use Firely, HAPI, and `fhirpath.js` to challenge design assumptions. Do not mechanically copy the Python AST or generated parser. The recommended shape is:

1. a source-position-preserving lexer/parser;
2. a stable, typed Ruby AST;
3. a collection-first evaluator with explicit empty/singleton semantics;
4. FHIRPath value objects for decimal, date/time, time, quantity, and type information;
5. a host/model adapter for FHIR navigation, choice types, `resolve()`, constants, terminology, and extensions; and
6. a registry of standard and host-defined functions with metadata for arity, argument kind, delayed evaluation, nullability, and result typing.

The first vertical slice should be: parse and evaluate path navigation, literals, indexing, `where`, `select`, `first`, `exists`, equality, and Boolean logic over plain Ruby hashes, with source locations and deterministic errors. Add FHIR R4 model metadata and quantities only after those semantics are covered by shared and differential tests.

## Scope and method

This is an implementation scoping review, not a systematic review of clinical outcomes. I inspected the published/current HL7 specification material, its grammar and test documentation, the HL7 implementation-list URL, current source repositories, public APIs, test layouts, and licenses. The HL7 implementation-list page was retrieved but served an AWS WAF human-verification page rather than its table; therefore, the list is treated as the authoritative index to revisit, not as evidence for unverified current feature claims.[5]

Primary material and snapshots reviewed:

- HL7 FHIRPath publication history, current source specification, grammar, and tests page.[1][2][3]
- `beda-software/fhirpath-py` repository, README, project metadata, parser grammar, public API, engine, invocation registry, and test harness.[6][7][8]
- HL7 `fhirpath.js` repository, README, package metadata, and license.[14][15][17]
- Firely .NET SDK repository, FHIRPath compiler/evaluation context, README, and license.[18][19][22]
- HAPI FHIR repository and its `IFhirPath`, evaluation-context, and R4 adapter APIs.[23][24][26]
- HL7/FHIR shared FHIRPath test-case repository and R5 XML suite.[27][28]

The page and repository observations are time-sensitive. Pin URLs, versions, commit SHAs, and test-suite snapshots in the Ruby project before using this report as a release claim.

## What the specification requires

### Language model

FHIRPath is a graph-traversal and extraction language designed to be model- and platform-independent. Its defining behavior is collection-centric: operations return collections, and each path step selects from the collection produced by the preceding step.[2] Evaluation happens relative to a context/root instance; an initial type name can be used to retain the context when it matches the context type or a supertype.[2]

The implementation must therefore distinguish at least:

- an empty collection (`{ }`) from a collection containing a null-like application value;
- a singleton collection from a multi-item collection;
- the focus (`$this`), iteration index (`$index`), and aggregate total (`$total`);
- the resource/context root and external constants (`%name`); and
- a FHIRPath value from its host representation (for example, a FHIR primitive extension or a choice-type field).

Flattening and singleton coercion are semantic rules, not conveniences to be delegated to Ruby arrays.[2] A Ruby API may return friendly scalars, but the evaluator core should retain collection semantics until its boundary.

### Syntax and grammar

The HL7 grammar covers an entire expression, member/function invocations, indexers, unary polarity, arithmetic, union, comparison, type and membership operators, Boolean logic, implication, literals, external constants, quantities, qualified type names, delimited identifiers, comments, and escaped strings.[3] The current grammar adds syntax that is not part of the old normative grammar, including `Long` literals with an `L` suffix, date literals, `sort` direction arguments, and instance selectors/object construction.[3]

The parser must preserve enough source information to produce useful diagnostics. The Python and JavaScript implementations both collect lexer/parser errors rather than allowing a permissive partial parse to look valid.[9][14] The parser must reject trailing or malformed input, not merely build an AST for a prefix.

### Value and type system

The standards-defined surface includes Boolean, Integer, Decimal, String, Date, DateTime, Time, Quantity, collection behavior, model types, and type/reflection operations. Current STU3 adds Long and several STU functions; the specification explicitly marks aggregates, Long literals/conversion, `repeatAll`, some string/date/math functions, `comparable`, instance selectors, and reflection as trial use.[2]

Important semantic areas that need dedicated value objects and tests are:

- **Empty and three-valued logic:** empty operands can yield empty rather than `false`; `and`, `or`, `xor`, and `implies` have truth tables that differ from Ruby truthiness.[2]
- **Equality versus equivalence:** `=` and `~` are deliberately different for strings, decimals, dates/times, quantities, and collections.[2]
- **Singleton evaluation:** many operations require one item and must signal an evaluation error for multiple items; other functions intentionally accept collections.[2]
- **Decimal precision:** binary floating point is not a safe default for FHIRPath decimal semantics. Use a decimal implementation and define conversion/rounding behavior explicitly.[2]
- **Date/time precision and timezone:** partial dates and times carry precision; comparisons and arithmetic must not be reduced to Ruby `Date`/`Time` behavior without preserving the FHIRPath rules.[2]
- **Quantity and UCUM:** quantity arithmetic and comparability require units, conversions, and precision policy. Treat UCUM as a host dependency with its own license and conformance tests.[2]
- **Model typing:** FHIR choice elements such as `value[x]` need model metadata rather than ordinary hash lookup. FHIRPath views logical model properties, not JSON/XML serialization details.[2]

### Functions and host services

The function surface is grouped into existence, filtering/projection, subsetting, combining, conversion, string manipulation, math, tree navigation, utilities, and aggregates; operators cover equality, comparison, type, collection, Boolean, math, and date/time behavior.[2] A complete engine must also decide which functions are standard, which are FHIR-specific supplements, and which are host/application extensions.

Functions such as `where`, `select`, `exists(criteria)`, `all(criteria)`, `repeat`, `iif`, and `aggregate` take expressions rather than already-evaluated values.[2][11] They require delayed evaluation and a nested focus/context. A function registry that eagerly evaluates all arguments will produce plausible but incorrect behavior for these functions.

FHIRPath also defines an environment/host boundary.[2] A production engine may need external constants, resource resolution, terminology services, model/type information, tracing, and application-defined functions. These are capabilities supplied by the host, not reasons to hard-code a particular FHIR server into the evaluator.[15][21][25]

## `fhirpath-py` as the first compatibility reference

### Public API and observable contract

The package exposes `evaluate(resource, path, context=None, model=None, options=None)` and `compile(path, model=None, options=None)`. `evaluate` accepts a resource, a string or `{base, expression}` path object, context variables, model metadata, and options; `compile` parses once and returns a callable for repeated evaluation.[7][10] The current module also exposes typed helpers that format a result as an array or first value for a requested Python type.[10]

The README documents FHIR versions DSTU2, STU3, R4, and R5 and a user invocation table.[7] Project metadata identifies Python 3.10+, ANTLR Python runtime 4.10, `python-dateutil`, typed packaging, and MIT licensing.[8] These facts make it a useful behavioral reference, but its public API and output conventions should not be copied as the Ruby API without deciding whether Ruby callers want collections always or scalar convenience methods.

### Internal pipeline

The current source has a clear, useful decomposition:

| Python component | Observed responsibility | Ruby implication |
|---|---|---|
| `parser/FHIRPath.g4` and generated ANTLR files | Grammar and generated lexer/parser | Keep grammar-derived parsing separate from evaluation; pin the grammar version and generator/runtime if ANTLR is selected.[9] |
| `parser/__init__.py` | Creates lexer/token stream/parser, installs error listener, walks parse tree | Expose `parse` and structured `ParseError`; require end-of-input. |
| `parser/ASTPathListener.py` | Converts parse-tree callbacks into generic dictionaries with `type`, `text`, terminal text, and children | Prefer immutable Ruby AST node classes with source spans; avoid making evaluator logic depend on dictionary shape. |
| `engine/evaluators` | Dispatches AST node type to evaluator functions | Use an evaluator visitor or node dispatch table, with exhaustive handling and a clear unsupported-node error. |
| `engine/__init__.py` | `do_eval`, `doInvoke`, argument checking, delayed `Expr` parameters, type specifiers, infix invocation | Make invocation metadata explicit and typed; model delayed arguments as closures carrying focus/context. |
| `engine/invocations/*` | Built-in function/operator implementations by semantic family | A registry plus family modules is a good organization; do not use Ruby method-name reflection as the contract.[12] |
| `engine/nodes.py` | `FP_Type`, `FP_Quantity`, `FP_DateTime`, `FP_Time`, `ResourceNode`, `TypeInfo` | Introduce value objects and a host-facing node/element abstraction; preserve original path, property, index, and logical type metadata. |
| `engine/util.py` | Collection normalization, data unwrapping, type checks, user table adaptation | Centralize collection and empty semantics; do not scatter `Array()` coercions through functions. |
| `models/*` | JSON maps for path-to-type, choice types, and parent relationships by FHIR release | Define a versioned `ModelProvider` interface and load generated metadata as data. |
| `__init__.py` | Public evaluation/compilation boundary and output conversion | Keep `evaluate`, `compile`, `evaluate_first`, and raw/internal-value modes separate. |

The evaluator uses a context hash containing `dataRoot`, `vars`, `model`, and a processed user invocation table; it supplies standard `context` and `ucum` variables and can install a trace callback.[10] `doInvoke` merges built-ins with user functions, checks arity and declared argument kinds, preserves raw expression nodes for macros, and supports nullable/variadic metadata.[11][12] This is the most important behavior to retain in a Ruby design.

Navigation wraps values in `ResourceNode` objects so path, property name, index, logical type, FHIR choice fields, and primitive extension handling survive evaluation.[11] Model JSON maps then resolve choice paths and logical types during member invocation. This is more than a convenience wrapper: it is how a JSON-backed implementation approximates the abstract model required by the specification.

### Test strategy and limitations

`fhirpath-py` uses pytest with custom YAML collection. Cases cover paths, literals, existence, repeat, filtering/projection, subsetting, combining, conversion, strings, math, navigation, utilities, equality, comparison, types, collections, Boolean logic, aggregates, variables, extensions, quantities, and FHIR R4.[13] It also keeps AST JSON fixtures and resource fixtures, and tests invalid lexical input and parser output.[13]

That layout is an excellent starting inventory, but it is not itself the specification.[4][13] Some test comparisons stringify values, some cases are implementation fixtures, and current repository README text can lag the implementation. The Ruby project should preserve the YAML cases as provenance, add an explicit expected-error schema, and use the official XML suite as the conformance gate.

## Implementation landscape

The HL7 implementation index should be revisited for additional products and versions once its WAF challenge can be passed interactively.[5] The following mature/open implementations were inspected directly.

| Implementation | Parser/AST pattern | Runtime/context pattern | Notable strengths and differences | License signal |
|---|---|---|---|---|
| **`fhirpath-py`** | ANTLR-generated Python parser; listener creates a generic JSON-like AST | Dynamic evaluator dispatch; invocation registry; `ResourceNode`; JSON model maps; user functions and trace options | Compact, readable reference for a Python/JSON application; explicit macro handling and FHIR choice-path metadata; current public API is easy to exercise | MIT in repository/package metadata.[6][8] |
| **HL7 `fhirpath.js`** | ANTLR-generated JavaScript parser; custom listeners; AST returned from parser | JavaScript evaluator with internal FP types, model files, compiled paths, user functions, optional async evaluation, terminology and FHIR server hooks | Broad web/Node packaging; supports CommonJS/ESM, R4/R5/etc. model data, async host calls, precise-math options, and FHIRPath supplements. README implementation-status prose is version-stale, so package/code must win over prose.[14][15][16] |
| **Firely .NET SDK** | Hand-written/parser-combinator grammar (`Sprache`), not ANTLR; parser builds typed expression objects | Typed expression tree compiled to delegates; `SymbolTable`, `Invokee`, closures, evaluation context, terminology service, element resolver | Strongest example of a typed, compiled, host-extensible design; parser/evaluator separation and symbol table are directly applicable to Ruby; FHIR POCO/element model is first-class | BSD 3-Clause.[18][20][22] |
| **HAPI FHIR** | HAPI API adapts the HL7 Java FHIRPath engine and version-specific FHIR model modules | `IFhirPath` provides parse/evaluate/evaluate-first; parsed expressions are opaque; evaluation context supplies `resolveReference` and constants; R4 adapter wraps engine exceptions and validates return type | Good server/library boundary: parsed expressions are reusable black boxes, host services are injectable, and model/version adapters are isolated. The R4 adapter deliberately configures non-strict behavior, demonstrating a compatibility option that must not be confused with standard semantics.[23][24][26] |

### Architectural patterns worth combining

1. **Specification grammar plus native AST.** ANTLR generation is productive and keeps syntax synchronized, as seen in Python and JavaScript, but Firely demonstrates that a hand-written parser can produce a cleaner typed AST.[9][20] The choice should be driven by Ruby tooling, error quality, and grammar-upgrade cost, not by copying fhirpath-py's generated files.
2. **Compilation as an optimization boundary.** `fhirpath-py` and `fhirpath.js` cache/compile parsed expressions; Firely turns expressions into reusable delegates; HAPI exposes an opaque parsed-expression handle.[10][20][24] Ruby should provide `parse` for inspection, `compile` for reuse, and a thread-safe immutable compiled form.
3. **Explicit host context.** Firely and HAPI make resource resolution, constants, terminology, and element navigation injectable; `fhirpath.js` exposes server URLs, headers, terminology URLs, abort/async options; `fhirpath-py` uses a context/model/options structure.[11][15][21] Ruby should define a small `EvaluationContext`/`HostServices` protocol rather than a global singleton.
4. **Registry-driven function dispatch.** The Python invocation table and Firely symbol table both make function signatures and extension points visible.[12][20] A Ruby registry should carry function name, arity, parameter kinds (`value`, `expression`, `type`, `collection`), nullability, and whether evaluation is eager or delayed.
5. **Model adapter, not FHIR-only core.** FHIRPath is model-independent, while FHIR choice types and `resolve()` need FHIR-aware services.[2][21] Keep `Core` independent from `FHIR::R4`/`FHIR::R5` adapters and test plain object graphs separately from FHIR fixtures.

## Test-suite and oracle strategy

Use several layers, each answering a different question:

1. **Official shared suite.** The HL7 tests page points to `FHIR/fhir-test-cases`; the R5 FHIRPath XML suite is a shared corpus with example resources.[4][27][28] Import it without editing source cases. Record suite commit and report pass/skip/fail by group.
2. **HL7 specification data.** Treat the grammar, function definitions, operation definitions, and changes in the HL7 FHIRPath repository as inputs to a review/generation step.[2][3] The current source clearly marks many STU additions; do not mix those into a normative-only pass.
3. **Compatibility fixtures.** Port `fhirpath-py` YAML tests and AST fixtures, retaining original file paths and expected behavior.[13] Use them to find translation regressions, not as the only conformance oracle.
4. **Differential tests.** For a pinned expression/resource corpus, run Ruby against at least one independent engine (`fhirpath.js` or Firely/HAPI). Classify differences as standard ambiguity, release/version difference, host/model difference, or defect. Never declare the majority result correct without checking the specification.
5. **Property and edge tests.** Add focused tests for empty collections, singleton violations, duplicate/order rules, precision, partial temporal values, invalid units, choice fields, escaped identifiers/strings, delayed `iif` branches, nested `$this`, source locations, and deterministic errors.
6. **FHIR model tests.** Keep FHIR R4 model tests separate from core tests. Verify logical `value` navigation across all choice variants, primitive extensions, resource type roots, contained/reference resolution, and a missing-field empty result.

Recommended conformance report fields: suite/version/commit, expression, input fixture, declared model, expected result or expected error, actual result/error, standard target (`2.0.0` or `3.0.0-STU`), host features used, and a classification (`pass`, `unsupported`, `host-dependent`, `defect`).

## Licensing and supply-chain constraints

- **FHIRPath specification:** the normative N1 publication labels itself public domain/Creative Commons Zero.[1] The current HL7 source repository has no machine-readable license field in its GitHub metadata, so treat the grammar/specification as reference material and confirm current HL7 terms before redistributing copied prose or generated artifacts.[2]
- **`fhirpath-py`:** MIT; a source or substantial-port reuse requires retaining the MIT notice.[6][8]
- **`fhirpath.js`:** custom BSD-derived license; retain the license and contributor/organization acknowledgment in any reused code or binary distribution, and do not imply endorsement.[17]
- **Firely:** BSD 3-Clause; retain notices and avoid endorsement language.[22]
- **HAPI FHIR:** Apache 2.0; retain notices and account for any separately licensed transitive components.[23][24]
- **Generated parser/runtime:** ANTLR-generated code and the ANTLR Ruby runtime have their own licensing obligations. Pin and audit the exact runtime, generator, decimal, date/time, and UCUM dependencies before publishing a gem.
- **Practical recommendation:** implement from the published grammar and behavior, write original Ruby code, keep a `NOTICE`/dependency inventory, and avoid copying generated Python/JavaScript source until provenance and license compatibility are explicitly recorded. The project license should be selected independently of the reference implementation licenses.

## Risks and decisions to resolve

| Risk | Why it matters | Mitigation/gate |
|---|---|---|
| FHIRPath release skew | Normative 2.0.0, STU3 3.0.0, and continuous build differ in grammar/functions | Declare target in gem metadata and `Capability` object; feature-gate STU behavior; pin fixtures. |
| Grammar and generated-code drift | A grammar can parse more/less than evaluator support; source repos may contain stale generated artifacts | Pin grammar commit, regenerate in CI, require parser/evaluator coverage for every grammar alternative. |
| Ruby truthiness and arrays | Ruby `nil`, `false`, and arrays do not model empty collections and three-valued logic | Use an internal `Collection`/empty representation and semantic Boolean helpers. |
| Numeric/date behavior | Float, `Date`, and `Time` defaults lose precision or partial-value semantics | Use Decimal/temporal value objects and explicit conversion/precision tests. |
| FHIR choice and primitive extensions | Raw JSON traversal returns the wrong logical model | Require a model provider/element adapter; test R4 choice maps and extensions. |
| Macro/delayed arguments | Eagerly evaluating `where`, `iif`, or `aggregate` changes results or causes invalid-branch errors | Carry AST closures with focus/context; test branch laziness and nested scopes. |
| Host calls and security | `resolve`, terminology, and custom functions can perform I/O or leak data | Make host services explicit, injectable, cancellable where relevant, and disabled by default in pure evaluation. |
| Error compatibility | Mature engines differ in exception classes and strictness flags | Standardize Ruby error classes/source spans; preserve machine-readable cause and distinguish parse/evaluation/host errors. |
| Thread safety/caching | Compiled expressions and mutable model/context caches can cross-request state | Immutable compiled AST/registry snapshots; per-evaluation context; documented cache ownership. |
| License contamination | Copying implementation code or generated artifacts can impose incompatible notices | Keep original implementation, audit dependencies, and add license checks before release. |

Open decisions before implementation:

1. Is the first release normative FHIRPath 2.0.0 only, or 2.0.0 plus a named 3.0.0 STU3 feature set?
2. Will the parser be ANTLR-generated for grammar fidelity or Ruby-native for AST/error quality?
3. Is the public result always a collection, with `evaluate_first` as a convenience, or should the default mirror `fhirpath-py`'s list output exactly?
4. Which FHIR release is the first model adapter: R4, R5, or model-independent core only?
5. Are `resolve`, terminology, async I/O, and user functions in the first release, or explicit later host-service milestones?
6. What project license and dependency policy will govern the new Ruby gem?

## Suggested staged scope

### Stage 0: conformance contract

Freeze the target version, result representation, error taxonomy, supported host features, and test-suite commits. Build a matrix from grammar alternatives and standard function/operation definitions to test IDs.

### Stage 1: pure core vertical slice

Implement lexer/parser, AST/source spans, collection navigation, literals, indexers, `where`, `select`, `first`, `exists`, equality, and Boolean logic over plain Ruby hashes/objects. Add `parse`, `compile`, and `evaluate` APIs plus invalid-input and empty/singleton tests.

### Stage 2: standard value semantics

Add Decimal, Date, DateTime, Time, Quantity/UCUM boundary, string/conversion functions, arithmetic/comparison, type operators, combining/subsetting, and the remainder of the normative function groups. Import and classify official cases before adding convenience behavior.

### Stage 3: FHIR model adapter

Add versioned model metadata, resource/type-root navigation, choice elements, primitive extensions, logical type checks, and FHIR fixtures. Keep the core runnable without a FHIR package.

### Stage 4: host extensions and operational hardening

Add explicit host services for constants, `resolve`, terminology, trace, cancellation/async where needed, and user-defined functions. Add compiled-expression caching, thread-safety tests, differential runs, and a conformance report suitable for release notes.

### Stage 5: feature-gated STU3

Add Long, instance selectors, sort direction, newly specified functions, aggregates, reflection, and other STU3 behavior only behind capability/version flags and dedicated test groups. Promote a feature only after independent implementation agreement and stable test evidence.

## Bottom line

`fhirpath-py` is the best first compatibility map because it exposes a small public API, a grammar-derived AST, an invocation registry, explicit delayed-argument handling, and FHIR model metadata. Firely supplies the strongest counterexample against a purely dynamic dictionary AST; HAPI supplies a clean opaque compiled-expression and host-service boundary; `fhirpath.js` demonstrates packaging, async/terminology hooks, and the risk of stale implementation-status prose.[10][20][24] A Ruby implementation should combine those lessons while treating the HL7 specification and shared XML tests—not any one runtime—as the conformance authority.
## Sources

[1] https://hl7.org/fhirpath/history.html — HL7 FHIRPath publication history
[2] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/index.md — HL7 FHIRPath specification source
[3] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/images/fhirpath.g4 — HL7 FHIRPath grammar
[4] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/tests.md — HL7 FHIRPath tests page
[5] https://confluence.hl7.org/spaces/FHIRI/pages/161060129/FHIRPath+Implementations — HL7 FHIRPath implementations list
[6] https://github.com/beda-software/fhirpath-py — fhirpath-py repository
[7] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/README.md — fhirpath-py README
[8] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/pyproject.toml — fhirpath-py project metadata
[9] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/parser/FHIRPath.g4 — fhirpath-py grammar
[10] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/__init__.py — fhirpath-py public API
[11] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/__init__.py — fhirpath-py engine
[12] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/invocations/__init__.py — fhirpath-py invocation registry
[13] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/tests/conftest.py — fhirpath-py test harness
[14] https://github.com/HL7/fhirpath.js — fhirpath.js repository
[15] https://raw.githubusercontent.com/HL7/fhirpath.js/master/README.md — fhirpath.js README
[16] https://raw.githubusercontent.com/HL7/fhirpath.js/master/package.json — fhirpath.js package metadata
[17] https://raw.githubusercontent.com/HL7/fhirpath.js/master/LICENSE.md — fhirpath.js license
[18] https://github.com/FirelyTeam/firely-net-sdk — Firely .NET SDK repository
[19] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/README.md — Firely .NET SDK README
[20] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/src/Hl7.Fhir.Base/FhirPath/FhirPathCompiler.cs — Firely FHIRPath compiler
[21] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/src/Hl7.Fhir.Base/FhirPath/FhirEvaluationContext.cs — Firely FHIRPath evaluation context
[22] https://raw.githubusercontent.com/FirelyTeam/firely-net-sdk/develop/LICENSE — Firely license
[23] https://github.com/hapifhir/hapi-fhir — HAPI FHIR repository
[24] https://raw.githubusercontent.com/hapifhir/hapi-fhir/master/hapi-fhir-base/src/main/java/ca/uhn/fhir/fhirpath/IFhirPath.java — HAPI IFhirPath API
[25] https://raw.githubusercontent.com/hapifhir/hapi-fhir/master/hapi-fhir-base/src/main/java/ca/uhn/fhir/fhirpath/IFhirPathEvaluationContext.java — HAPI FHIRPath evaluation context
[26] https://raw.githubusercontent.com/hapifhir/hapi-fhir/master/hapi-fhir-structures-r4/src/main/java/org/hl7/fhir/r4/hapi/fluentpath/FhirPathR4.java — HAPI R4 FHIRPath adapter
[27] https://github.com/FHIR/fhir-test-cases — FHIR shared test cases repository
[28] https://raw.githubusercontent.com/FHIR/fhir-test-cases/master/r5/fhirpath/tests-fhir-r5.xml — FHIR R5 FHIRPath test suite
