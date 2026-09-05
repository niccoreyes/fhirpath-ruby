# FHIRPath Ruby architecture

Status: implementation contract for the current pre-release slice
Date: 2026-09-04
Repository: `fhirpath-ruby`
Decision scope: architecture and compatibility contract only; this document does not claim that the scaffold implements FHIRPath.

## 1. Executive decision

Build a Ruby-native FHIRPath engine around five stable boundaries:

1. a source-span-preserving lexer and parser;
2. an immutable, typed abstract syntax tree (AST);
3. a collection-first evaluator with explicit empty/singleton semantics;
4. FHIRPath value objects and a model/element adapter boundary; and
5. an explicit evaluation context plus metadata-driven function registry.

The initial conformance target is FHIRPath 2.0.0, the normative R2 release, with a named, feature-gated subset of FHIRPath 3.0.0 STU3 added only after the normative core is tested. The HL7 grammar, specification, and shared test cases are the conformance authorities; `fhirpath-py` is the first compatibility reference, not the specification.[1][2][3]

The implementation must be Ruby-native. It may use a grammar generator or a hand-written parser, but it must not make the Python implementation's dictionary AST, mutable context hash, or generated parser artifacts part of the Ruby public contract.

## 2. Design goals and non-goals

### Goals

- Implement standard FHIRPath behavior independently of a particular FHIR server or Ruby FHIR model library.
- Preserve collection semantics through the evaluator rather than reducing every result to Ruby truthiness, `nil`, or a scalar.
- Make parsing, compilation, evaluation, model navigation, terminology, reference resolution, and custom functions separately testable.
- Produce deterministic, structured parse/evaluation errors with source spans.
- Permit repeated evaluation of an immutable compiled expression without reparsing or sharing per-evaluation state.
- Make the supported FHIRPath version and optional STU features observable through a capability object.
- Support plain Ruby hashes/objects before adding a FHIR-release-specific adapter.
- Keep enough internal type/path metadata to support FHIR choice elements, primitive extensions, and logical model paths when a FHIR adapter is present.

### Non-goals for the first release

- A FHIR server, persistence layer, terminology server, or clinical-reasoning platform.
- A source-compatible port of `fhirpath-py`, `fhirpath.js`, Firely, or HAPI.
- Silent compatibility with every implementation-specific permissive mode.
- Network I/O from pure expression evaluation.
- Claiming complete FHIR R4/R5 model support before a versioned model provider and fixtures exist.
- Enabling trial-use FHIRPath 3.0 features merely because the parser can recognize their syntax.

## 3. Conformance contract

### 3.1 Version policy

`FHIRPath::Capability` is the runtime declaration of the implementation contract. It should expose at least:

```ruby
FHIRPath::Capability.current
# => {
#      fhirpath: "2.0.0",
#      trial_use: ['stu3-aggregate-functions'],
#      model_releases: ['R4'],
#      host_features: []
#    }
```

The normative 2.0 feature set is the default. Each 3.0 STU feature must have:

- a capability name;
- a parser/evaluator test group;
- an explicit enablement option;
- a version or capability marker in conformance reports; and
- a documented reason it is not part of the normative default.

The declared exception to the gating model is the `stu3-aggregate-functions`
subset (`sum()`, `avg()`, `max()`, `min()`), which ships default-on in the
standard registry and is surfaced in `Capability#trial_use`; callers that need
a strict-2.0 declaration can construct `Capability.new(trial_use: [])`.
Registry-level enforcement of that strict declaration is documented as not yet
implemented. Examples of gated features include `Long`, instance
selectors/object construction, the general-purpose `aggregate()` function,
reflection, and other additions identified by the specification as trial use.
The grammar is not itself a promise of evaluator support.[1][2]

### 3.2 Result policy

The evaluator core returns a `FHIRPath::Collection`, including for a singleton result. The collection is ordered, enumerable, and represents the FHIRPath empty collection with `empty? == true`; it is not a Ruby `nil` value. A convenience API returns the first item explicitly.

```ruby
patient = {
  "resourceType" => "Patient",
  "name" => [
    { "family" => "Lovelace", "given" => ["Ada", "Augusta"] }
  ]
}

FHIRPath.evaluate(patient, "Patient.name.given").to_a
# => ["Ada", "Augusta"]

FHIRPath.evaluate_first(patient, "Patient.name.family")
# => "Lovelace"

FHIRPath.evaluate_first(patient, "Patient.telecom")
# => nil
```

The default collection result is deliberately more explicit than a scalar convenience result. It also gives the engine a place to preserve item metadata, such as logical type, source path, and model element information, without changing the public meaning of an empty result.

### 3.3 Public API proposal

The first stable API should be small:

```ruby
module FHIRPath
  def self.parse(expression, capability: Capability.current)
    # => ParsedExpression, or raises ParseError
  end

  def self.compile(expression, model: nil, capability: Capability.current,
                   functions: FunctionRegistry.standard)
    # => CompiledExpression
  end

  def self.evaluate(resource, expression, variables: {}, model: nil,
                    capability: Capability.current,
                    functions: FunctionRegistry.standard,
                    options: {})
    # => Collection
  end

  def self.evaluate_first(resource, expression, variables: {}, model: nil,
                          capability: Capability.current,
                          functions: FunctionRegistry.standard,
                          options: {})
    # => one item or nil
  end
end
```

A compiled expression is immutable and reusable:

```ruby
program = FHIRPath.compile("Patient.name.where(use = 'official').given")

program.evaluate(patient).to_a
# => ["Ada", "Augusta"]

# Optional Ruby-callable compatibility convenience:
program.call(patient).to_a
```

A caller can inspect the parsed AST for tooling without coupling to evaluator state:

```ruby
parsed = FHIRPath.parse("Patient.name.given")
parsed.source       # => the original expression
parsed.ast          # => immutable FHIRPath::AST nodes
parsed.source_map   # => node => source span
```

External constants and host services are passed explicitly:

```ruby
FHIRPath.evaluate(
  patient,
  "%subject.name.family",
  variables: { "subject" => patient }
)
```

The API must not mutate the caller's resource to add engine metadata. `fhirpath-py` currently prepares a context containing `dataRoot`, variables, model metadata, a user invocation table, and an optional trace callback, and its navigation wrappers retain path/type information internally.[4][5][7] Ruby should retain the useful separation while keeping wrappers and evaluation state immutable or per-evaluation.

### 3.4 Error taxonomy

All public errors derive from `FHIRPath::Error` and carry a stable code, message, and optional source span:

- `ParseError`: invalid characters, malformed tokens, unexpected token, trailing input, or expression nesting exceeding the parser depth budget (code `nesting_depth_exceeded`);
- `EvaluationError`: a valid expression cannot be evaluated for the current focus or collection;
- `SingletonError`: an operation requiring one item received multiple items;
- `TypeError`: an argument or value is not compatible with the required FHIRPath type;
- `UnknownFunctionError`: no standard or explicitly registered function exists;
- `UnknownConstantError`: an external constant is not present in the context;
- `ModelError`: model navigation/type resolution failed;
- `HostError`: an injected host service failed; and
- `UnsupportedFeatureError`: a known but disabled or unimplemented capability.

Errors should expose machine-readable fields without promising exception-name compatibility with another implementation:

```ruby
begin
  FHIRPath.evaluate(patient, "Patient.name.given[bad]")
rescue FHIRPath::ParseError => error
  error.code       # => :unexpected_token
  error.span        # => FHIRPath::SourceSpan
  error.expression  # => original source
end
```

The parser must require end-of-input. A parser that returns an AST for a valid prefix is unsafe for a conformance engine; both the Python parser pipeline and Firely compiler explicitly install/perform parse failure handling rather than treating malformed input as a successful expression.[4][11]

## 4. Layered architecture

```text
Public API
  parse / compile / evaluate / evaluate_first
       |
Capability + immutable configuration
       |
Lexer -> Parser -> AST + SourceMap
                         |
                  Compiler / evaluator plan
                         |
              EvaluationContext + Closure
                         |
         Collection operations and function registry
              |                       |
      FHIRPath values              Host/model adapter
       and operators          plain Ruby | FHIR R4/R5 | custom model
                         |
                 Collection result / errors / trace
```

### 4.1 Public boundary and configuration

`FHIRPath` owns the public API and no evaluator singleton. A call constructs or receives an immutable configuration containing:

- `Capability` (FHIRPath release and enabled features);
- `ModelProvider` (optional);
- a snapshot of `FunctionRegistry`;
- host service implementations;
- evaluation options (strictness, tracing, cancellation policy); and
- cache policy, if compilation caching is enabled by the host.

The configuration may be reused, but an `EvaluationContext` must be new for each evaluation. This prevents `$this`, `$index`, `$total`, variables, and trace state from crossing requests.

### 4.2 Lexer and parser

The parser consumes the pinned HL7 grammar or a semantically equivalent Ruby-native grammar. It must recognize the selected release's syntax, preserve token offsets, and produce a complete parse or a structured `ParseError`.

The parser should not expose generator-specific parse-tree classes. If ANTLR is selected, generated files remain an internal build artifact behind a Ruby AST builder. If a hand-written parser is selected, it must still be tested against the same grammar alternatives and malformed-input corpus.

### 4.3 AST

AST nodes are immutable value objects with a common shape:

```ruby
FHIRPath::AST::MemberInvocation.new(
  receiver: ..., name: "given", span: SourceSpan.new(12, 16)
)
```

Recommended node families:

- `Expression` / `BinaryExpression` / `UnaryExpression`;
- `MemberInvocation` / `FunctionInvocation`;
- `Indexer`;
- `Identifier` / `ExternalConstant` / `TypeSpecifier`;
- Boolean, integer, decimal, string, date/time, quantity, and null/empty literals;
- collection and parenthesized terms; and
- feature-gated instance/object nodes.

The AST is a syntax representation, not an evaluation context. It must never store the current focus, index, total, variable values, network clients, or mutable caches.

### 4.4 Compiler and evaluator

`Compiler` validates capability-dependent syntax/function availability and turns the immutable AST into an evaluator plan. The first implementation may interpret AST nodes directly; a later compiler may lower them to closures or instruction nodes. Both approaches must preserve the same semantics.

`Evaluator` receives:

```ruby
EvaluationContext(
  root: Collection,
  focus: Collection,
  variables: Variables,
  model: ModelProvider,
  host: HostServices,
  functions: FunctionRegistry,
  capability: Capability,
  trace: TraceSink
)
```

Every nested expression receives a derived context. A derived context changes focus and possibly `$index`/`$total`; it does not mutate the parent context in a way that can leak after the invocation returns.

### 4.5 Collection and focus semantics

`Collection` is the semantic center of the engine. It must centralize:

- empty versus non-empty;
- singleton extraction and multiple-item rejection;
- flattening rules;
- order and duplicate handling;
- focus (`$this`), index (`$index`), and aggregate total (`$total`); and
- conversion to public Ruby values at the API boundary.

Do not scatter `Array(value)` coercions across functions. `fhirpath-py` centralizes related behavior in `arraify`, `is_empty`, `is_nullable`, `flatten`, and `get_data`, but its mutable Python lists and `None` conventions are implementation details to translate rather than expose.[5][7]

Ruby's `false`, `nil`, empty arrays, and truthy objects cannot stand in for FHIRPath's empty collection and three-valued Boolean semantics. `and`, `or`, `xor`, and `implies` must be implemented from explicit truth tables and tested independently of Ruby conditionals.[1]

### 4.6 Value and type system

Use dedicated value objects where Ruby's built-ins lose FHIRPath information:

- `FHIRPath::Value::Integer` and `Long` (the latter gated until enabled);
- `FHIRPath::Value::Decimal` backed by exact decimal arithmetic;
- `FHIRPath::Value::String` if metadata or escaped-value provenance requires it;
- `FHIRPath::Value::Date`, `DateTime`, and `Time` preserving partial precision and timezone state;
- `FHIRPath::Value::Quantity` with numeric value and canonical unit boundary; and
- `FHIRPath::TypeInfo` for logical FHIRPath type, namespace, model path, and runtime type.

The public boundary may convert ordinary values where safe, but the evaluator must not default to binary floating point or Ruby temporal comparison. Quantity conversion should be delegated to a narrow unit service (UCUM-backed when enabled), with invalid/incomparable units represented as deterministic evaluation errors or empty results according to the standard operation.

`fhirpath-py` uses `FP_Type`, `FP_Quantity`, `FP_DateTime`, `FP_Time`, `ResourceNode`, and `TypeInfo` to preserve special values and navigation metadata.[7] The Ruby design keeps those responsibilities but uses namespaced immutable objects and an explicit unit-service interface.

### 4.7 Function registry and delayed evaluation

Function dispatch is registry-driven, not Ruby method-name reflection. A `FunctionSpec` should declare:

```ruby
FunctionSpec.new(
  name: "where",
  arity: 1,
  parameters: [:expression],
  receiver: :collection,
  delayed: true,
  nullable_input: false,
  implementation: Filtering::Where
)
```

Parameter kinds include `:any`, `:boolean`, `:integer`, `:number`, `:string`, `:type`, `:collection`, `:expression`, and `:root_expression`. Metadata should also state whether the argument is eager, delayed, variadic, nullable, or capability-gated.

`where`, `select`, `exists(criteria)`, `all`, `repeat`, `iif`, `coalesce`, and `aggregate` cannot receive already-evaluated arguments. They need a closure containing the AST and a derived focus/context. `fhirpath-py` represents this with `Expr`, `AnyAtRoot`, type specifiers, nullable/variadic metadata, and `make_param`; the registry is therefore a semantic contract, not merely a list of method names.[5][6]

Organize standard implementations by semantic family:

- `Existence`: `empty`, `exists`, `all`, `count`, truth aggregators;
- `Filtering`: `where`, `select`, `repeat`, `first`, `last`, `single`, `take`, `skip`, `tail`;
- `Combining`: union, combine, coalesce, exclude;
- `Equality` and `Logic`;
- `Conversion` and `Type`;
- `String`, `Math`, and `DateTime`;
- `Navigation`: children, descendants, extension, resolve boundary; and
- `Aggregate`: sum, min, max, avg, aggregate, with feature gates where required.

Standard functions are registered in an immutable default registry. Host functions require explicit registration and a namespace/name policy so an application extension cannot silently replace a standard function.

### 4.8 Evaluation context and host services

`HostServices` is the only boundary through which evaluation may ask the host to do work outside the pure expression graph:

```ruby
HostServices.new(
  constants: ->(name, mode:, context:) { ... },
  resolve_reference: ->(reference, containing:) { ... },
  terminology: nil,
  element_children: nil,
  trace: nil
)
```

Initial pure evaluation may provide constants and model navigation but no network services. Later services include:

- external constant resolution (`%name`);
- `resolve()` reference lookup;
- terminology membership/validation;
- child/descendant traversal for non-Hash models;
- tracing; and
- cancellation/async policy if a host genuinely needs I/O.

Firely exposes a typed evaluation context with terminology and element resolution, while HAPI exposes an evaluation-context interface for `resolveReference` and constant resolution.[12][14] `fhirpath.js` additionally documents async evaluation, terminology URLs, server hooks, and internal-type conversion options.[9] These are strong evidence for an injectable boundary, not reasons to make network access part of the core.

### 4.9 Model provider and FHIR integration

The core model protocol should be small:

```ruby
class ModelProvider
  def root_type(resource); end
  def property(element, logical_name); end
  def children(element); end
  def type_of(element); end
  def choice_types(parent_type, logical_name); end
  def primitive_extension(element, logical_name); end
end
```

`PlainModel` implements predictable Hash/Array/object navigation. The bundled
`FHIRPath::FHIR::R4::ModelProvider` is dependency-free; other release-specific
providers remain separately loaded adapters.

FHIR model metadata is data, not evaluator code. It should describe logical paths, type names, parent relationships, choice variants, and primitive-extension fields. For `Observation.value`, an R4 provider must resolve `valueQuantity`, `valueString`, and other `value[x]` variants to the logical property rather than treating JSON key lookup as the FHIRPath model.

This boundary follows the observed contrast among implementations: `fhirpath-py` uses release-specific JSON maps and `ResourceNode` metadata, while `fhirpath.js` ships separate FHIR context packages.[7][9] HAPI isolates release behavior in version-specific adapters.[10]

## 5. Comparison with other implementations

| Concern | `fhirpath-py` | HL7 `fhirpath.js` | Firely .NET SDK | HAPI FHIR | Ruby decision |
|---|---|---|---|---|---|
| Public API | `evaluate`, `compile`, typed first/array helpers; list-oriented output | `evaluate`, `compile`, internal-type conversion, model/options arguments | Compiler `Parse` and `Compile`, producing reusable delegates | `evaluate`, `evaluateFirst`, `parse`, opaque parsed expression | Keep `parse`, `compile`, `evaluate`, `evaluate_first`; return a collection by default and make scalar conversion explicit.[4][9][11] |
| Parser/AST | ANTLR grammar; listener builds generic dictionaries | ANTLR grammar and custom internal structures | Sprache parser; typed expression objects | Opaque parsed-expression handle | Hide parser technology behind immutable Ruby AST; preserve source spans.[2][4][11] |
| Evaluation | Dynamic node dispatch and invocation registry | Dynamic evaluator with internal FP types and async options | Typed expression tree compiled to `Invokee` delegates | Engine-specific compiled/parsed object | Use a registry plus visitor/plan; permit interpretation first and compilation optimization later.[5][6][11] |
| Delayed args | `Expr`, `AnyAtRoot`, nullable/variadic metadata | User invocation metadata includes expression/root argument kinds | Closures/`Invokee` and symbol table | Engine handles standard function semantics internally | Make delayed argument kind a first-class `FunctionSpec` field.[5][6][11] |
| Context/host | Context dict with root, variables, model, trace | Variables, model, terminology URLs, server/async hooks | `FhirEvaluationContext`, terminology, element resolver | `IFhirPathEvaluationContext` for constants/references | Explicit per-evaluation `EvaluationContext` and injectable `HostServices`; no global singleton.[4][9][12] |
| FHIR model | JSON maps plus `ResourceNode` | Separate FHIR context packages for releases | POCO/element model | Release-specific adapter | Core is model-independent; add versioned providers later.[7][9][13] |
| Errors | General exceptions and parser listener behavior | JavaScript exceptions and options | `FormatException` on parse failure | Java exceptions and opaque parsed expressions | Stable Ruby classes/codes/spans; do not promise foreign exception compatibility.[4][11][13] |
| Tests | YAML collector, resource fixtures, AST fixtures, pytest | Unit/type/E2E and release model tests | SDK/unit tests | Java engine/adapter tests | Official shared suite plus ported compatibility fixtures, differential tests, and property/edge tests.[3][8] |

`fhirpath-py` is the most useful first behavioral map because its source makes its context, evaluator, registry, special values, model maps, and fixture loader visible.[4][5][6]

Its node and fixture details are documented separately.[7][8] Firely is the strongest counterexample to a purely dynamic dictionary AST: its compiler separates parsing from typed expression compilation and symbol-table dispatch.[11]

HAPI demonstrates a small application-facing boundary in which parsing is reusable and implementation details remain opaque.[13][14]

`fhirpath.js` demonstrates packaging, async/terminology hooks, and the risk of stale implementation-status prose.[9][10]

## 6. Mapping from `fhirpath-py` modules to Ruby components

| Python module or area | Observed responsibility | Ruby component | Compatibility treatment |
|---|---|---|---|
| `fhirpathpy/__init__.py` | Public `evaluate`, `compile`, parsed-path application, raw/result conversion | `lib/fhirpath.rb`, `FHIRPath::API`, `CompiledExpression` | Preserve the conceptual boundary; return `Collection` and expose `evaluate_first` rather than copying Python list/scalar conversion.[4] |
| `parser/FHIRPath.g4` | Grammar source | `grammar/fhirpath.g4` or `lib/fhirpath/grammar.rb` | Pin a grammar revision and generator/runtime if used; never expose generated parser classes.[2] |
| `parser/generated/*` | Generated lexer/parser | Internal build output | Do not port into the public gem; regenerate in CI or use an original Ruby parser. |
| `parser/__init__.py` | Lexer/token stream/parser setup and error listener | `FHIRPath::Lexer`, `FHIRPath::Parser`, `FHIRPath::ParseError` | Require complete input and preserve source spans.[4] |
| `parser/ASTPathListener.py` | Parse-tree callbacks into generic `{type, text, children}` dictionaries | `FHIRPath::AST::*`, `ASTBuilder`, `SourceMap` | Replace mutable generic dictionaries with immutable typed nodes.[4] |
| `engine/evaluators/*` | AST-node evaluator dispatch | `FHIRPath::Evaluator`, node visitors/handlers | Use exhaustive dispatch and `UnsupportedFeatureError` for known gaps. |
| `engine/__init__.py` | `do_eval`, `doInvoke`, infix calls, argument checking, delayed args | `Evaluator`, `Invocation`, `ArgumentBinder`, `EvaluationContext` | Keep explicit argument kinds and nested closures; do not use Ruby reflection as a substitute.[5] |
| `engine/invocations/__init__.py` | Standard function/operator registry and metadata | `FunctionRegistry`, `FunctionSpec`, semantic-family modules | Registry is immutable per configuration; distinguish standard, STU, and host functions.[6] |
| `engine/invocations/{family}.py` | Existence, filtering, equality, logic, math, strings, navigation, aggregate implementations | `FHIRPath::Functions::{Family}` | Port behavior through shared tests, not source code. |
| `engine/nodes.py` | Special values, quantities, temporal values, resource wrappers, type info | `Value::*`, `Quantity`, `Temporal`, `Element`, `TypeInfo` | Preserve semantic information; use Ruby-native value objects and explicit unit service.[7] |
| `engine/util.py` | Collection normalization, data unwrapping, primitive handling, user table adaptation | `Collection`, `ValueAdapter`, `ElementAdapter`, `ArgumentBinder` | Centralize empty/singleton semantics; never scatter coercion.[7] |
| `models/*` | Release-specific path/type/choice maps | `ModelProvider`, `FHIR::R4`, `FHIR::R5` adapters | Load versioned metadata as data; keep core independent.[7][9][10] |
| `tests/conftest.py` | YAML collection, resource fixtures, context/variables, result comparison | `test/support/yaml_suite_loader`, fixture adapters, conformance reporter | Preserve fixture provenance; replace string-only comparison with typed expected values/errors.[8] |

## 7. Standards-required versus implementation-specific behavior

| Area | Standards-required behavior | Implementation-specific choice |
|---|---|---|
| Grammar | Accepted tokens, precedence, literals, operators, function syntax, and release-specific features must match the declared FHIRPath target.[1][2] | ANTLR versus hand-written parser; generated-file layout; AST class names. |
| Collections | Empty, singleton, multi-item, flattening, ordering, duplicates, and singleton coercion must follow FHIRPath semantics.[1] | `Collection` class shape, enumerable methods, and whether `to_a` allocates. |
| Boolean logic | Empty-aware logical truth tables and implication semantics.[1] | Internal truth-table helper names and storage representation. |
| Equality/equivalence | `=`/`!=` versus `~`/`!~`, collection behavior, precision, dates/times, quantities, and type rules.[1] | Value-object implementation and diagnostic wording. |
| Types and values | FHIRPath primitive/model types, conversions, date/time precision, quantity semantics, and type operators for the declared release.[1] | Decimal/temporal/UCUM libraries, internal wrappers, and public conversion policy. |
| Functions | Standard function names, arities, argument semantics, delayed evaluation, and results.[1] | Registry data structure, module grouping, extension-registration API. |
| Root/context | Evaluation is relative to a focus/root and supports standard variables and external constants according to the declared host/model contract.[1] | Ruby keyword names, context object classes, default variables, cache ownership. |
| FHIR navigation | A FHIR adapter must expose logical model properties, choice types, primitive extensions, and model types correctly for its release.[1] | Which FHIR releases/dependencies ship, metadata format, and adapter class names. |
| `resolve()`/terminology | Behavior is only available when the relevant host services and model contract are supplied.[1] | Whether services are synchronous, asynchronous, cancellable, local, remote, or disabled by default. |
| Parsing errors | Invalid/trailing input must not evaluate as a successful prefix. | Error classes, codes, spans, and message wording. |
| Compilation | Reusing a parsed/compiled expression must not alter its result semantics. | Whether compilation means an AST wrapper, closures, bytecode, or cached plan. |
| Tracing | If exposed, trace output must not change expression results. | Trace sink interface, event shape, redaction, and performance policy. |
| Conformance reporting | Reports must identify expression, fixture, expected/actual result or error, target release, and classification. | Report file format, CI integration, dashboard, and naming conventions. |

## 8. Compatibility risks and mitigations

| Risk | Failure mode | Mitigation |
|---|---|---|
| Release skew | 2.0 normative, 3.0 STU, and continuous grammar are mixed without a declaration | Capability object, feature gates, pinned grammar/test snapshots, release-labelled reports.[1][2] |
| Ruby truthiness | `nil`, `false`, and arrays collapse empty and Boolean semantics | Dedicated `Collection` and explicit three-valued logic tests. |
| Eager macro arguments | `where`, `iif`, or `aggregate` evaluates the wrong focus or invalid branch | AST closures and `FunctionSpec` argument kinds; test nested `$this` and lazy branches.[5][6] |
| Precision loss | Float/Date/Time conversions change decimal, temporal, or quantity results | Dedicated Decimal/temporal/Quantity values and boundary conversion tests.[1][7] |
| FHIR choice fields | JSON lookup misses logical `value` or returns the wrong choice | Versioned model provider with choice maps and R4 fixtures.[7][9] |
| Mutable evaluation state | Compiled expressions leak `$this`, variables, traces, or caches across calls | Immutable AST/registry; fresh per-call context; concurrency tests. |
| Host I/O surprises | `resolve` or terminology calls leak data or make pure tests nondeterministic | Explicit `HostServices`, disabled by default, timeouts/cancellation, host-dependent classification. |
| Error incompatibility | Consumers depend on another engine's exception text/class | Stable Ruby error codes/spans; compatibility adapter only where needed. |
| Stale implementation prose | README feature claims lag actual code, especially in `fhirpath.js` | Pin source/package/test revisions and make code-level behavior plus shared tests authoritative.[9][10] |
| License contamination | Generated/copied code or runtime dependencies impose unnoticed obligations | Original Ruby implementation, dependency inventory, NOTICE policy, and release audit. |

## 9. First vertical implementation slice

The first slice is intentionally narrow but end-to-end:

> Parse and evaluate path navigation, literals, indexers, `where`, `select`, `first`, `exists`, equality, and Boolean logic over plain Ruby Hash/Array/object data, with source locations and deterministic errors.

It should include:

1. a pinned parser grammar subset with complete-input validation;
2. immutable AST nodes and source spans;
3. `Collection`, `EvaluationContext`, and nested focus closures;
4. `PlainModel` navigation for Hash, Array, and simple Ruby objects;
5. Boolean/string/integer/decimal literals needed by the slice;
6. member navigation and indexer semantics;
7. delayed `where` and `select` predicates;
8. `first()` and `exists()` with and without criteria;
9. equality plus `and`/`or`/`implies` behavior for empty and singleton operands;
10. `FHIRPath.parse`, `compile`, `evaluate`, and `evaluate_first`; and
11. focused tests for valid expressions, invalid/trailing input, empty navigation, singleton violations, nested focus, and deterministic error fields.

The slice is complete only when the same compiled expression can be evaluated against multiple independent resources without shared state. It must not add FHIR R4 metadata, terminology, `resolve()`, network I/O, or STU3-only syntax unless a test demonstrates that the slice cannot be expressed without it.

## 10. Open decisions before implementation

1. Choose ANTLR-generated parsing or a Ruby-native parser after a small parser/error-quality spike; either choice must implement the pinned HL7 grammar and complete-input rule.
2. Confirm whether `Collection` remains the public result object or whether a compatibility layer also exposes a plain Array view.
3. Select the first FHIR model dependency and release after the pure slice; R4 is the likely first adapter because the project’s surrounding interoperability work targets R4, but this is a project decision, not a core-language requirement.
4. Select a Decimal/temporal/UCUM dependency policy and document license compatibility before adding it to the gem.
5. Decide whether host-defined functions are namespaced and whether they can shadow standard functions; default recommendation is no shadowing.
6. Define cache ownership and maximum compiled-expression lifetime before enabling a global cache.

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
