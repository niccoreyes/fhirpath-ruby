# FHIRPath first parity slice

Status: implemented prototype slice
Target: normative FHIRPath 2.0.0 core expressions

This slice exercises the complete Ruby path from source text through lexer/parser, immutable AST, per-evaluation context, and collection-first evaluator. It is intentionally a small compatibility slice, not a complete FHIRPath implementation.

## Supported behavior

- Boolean, string, integer, decimal, and scientific-notation numeric literals
- Empty and comma-separated collection literals (`{}` and `{1, 2}`)
- Parentheses and unary `+`/`-`
- Numeric `+`, `-`, `*`, `/`, `div`, and `mod`; string `+` and `&` concatenation semantics
- Numeric and string relational comparisons (`<`, `<=`, `>`, `>=`)
- Collection-aware equality (`=`, `!=`) and equivalence (`~`, `!~`), including order-independent duplicate matching
- Union (`|`) and string concatenation (`+` propagates empty operands; `&` treats empty operands as `''`)
- Membership (`in`, `contains`) and built-in primitive type operators (`is`, `as`)
- Empty-aware `and`, `or`, `xor`, and `implies`
- Plain Hash/Array/object member navigation with collection flattening
- Expression indexers, including empty, out-of-range, and singleton/type checks
- `where`, `select`, `first`, `exists`, `count`, `empty`, `not`, `all`, and Boolean aggregate functions
- `$this`, `$index`, and `$total` focus variables inside delayed predicates
- `%name` external constants through the existing variable/host boundary
- Complete-input parsing with source spans on syntax and evaluation errors, comments, and strict Unicode escapes
- Reusable compiled expressions with no retained resource or evaluation context

Every public evaluation returns `FHIRPath::Collection`; `evaluate_first` remains the explicit scalar convenience API.

## Intentional deviations and deferrals

- Union, string concatenation, membership, and primitive type operators are implemented for the supported built-in value subset; complex types and FHIR model metadata remain deferred.
- Equivalence normalizes case and runs of whitespace for strings and rounds numeric operands to their least precise decimal place. Full equivalence semantics for all FHIRPath types remain deferred with the broader value system.
- Division always produces an exact `BigDecimal`; temporal, quantity, UCUM, and advanced numeric semantics are deferred.
- Empty arithmetic and relational operands return the empty collection. Empty equality follows FHIRPath's empty-aware result policy; equivalence of two empty collections returns `true`.
- dependency-free FHIR R4 JSON choice navigation for `Observation.value[x]`;
- broader FHIR-specific model metadata, primitive extensions, terminology, `resolve()`, temporal/quantity values, advanced functions, and the official shared-suite importer remain deferred.
- Trial-use FHIRPath 3.0 features remain disabled by the normative 2.0.0 capability.

## Verification

Focused coverage is in `test/parity_slice_test.rb`; the existing foundation tests were updated where expression indexers now accept the standard expression form. The slice covers successful arithmetic/comparison/logic, empty propagation, nested predicate focus, index validation, type and singleton errors, malformed/trailing input, unsupported operators, compiled-expression reuse, and plain-model end-to-end navigation.

Run:

```sh
bundle exec rake test
bundle exec rubocop
git diff --check
```

## Compatibility references

- HL7 FHIRPath specification: https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/index.md
- HL7 FHIRPath grammar: https://raw.githubusercontent.com/HL7/FHIRPath/master/input/images/fhirpath.g4
- HL7 FHIRPath shared tests: https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/tests.md
- fhirpath-py public API: https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/__init__.py
- fhirpath-py evaluator and invocation registry: https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/__init__.py
