# Changelog

All notable changes to this project are documented here. The project is pre-1.0; the API and supported behavior may change between releases.

## [Unreleased]

- Add the `last()` member function (FHIRPath 2.0.0, existence/navigation functions): it returns the last item in the input collection, an empty collection when the input is empty, and requires zero arguments.
- Correct numeric arithmetic with a zero right operand: `+`, `-`, `*` treat zero as a normal operand, while `/`, `div`, `mod` divide and a zero divisor returns an empty collection (never an error).
- Correct `union` (`|`) to eliminate duplicate values from both operands using `=` equality in first-seen order, including numerically-equal integers and decimals.
- Accept a finite JSON `Float` as a `Decimal` for comparison, equality, arithmetic, and the `is Decimal` type test; reject `NaN`/`Infinity` as non-numeric.
- Correct `contains` so a multi-item right operand raises a singleton-required error even when the searched collection is empty, and so an empty right operand yields an empty result.
- Correct `&` string concatenation to treat empty operands as empty strings, with regression coverage for both operators' empty-collection behavior.
- Correct parser precedence for relational, union, and type operators to match the FHIRPath grammar.
- Harden documentation, package verification, CI, coverage reporting, and contributor workflows.
- Add the release support matrix, exact package capability metadata, versioning policy, and gated RubyGems/GitHub publication workflow.
- Declare the project under the MIT License and encode the license in gem metadata.
- Bound parser recursion: excessively nested expressions (parentheses, unary chains, function calls, indexers, and deep AST-building flat expressions) now raise `FHIRPath::ParseError` with code `nesting_depth_exceeded` instead of letting `SystemStackError` escape the `FHIRPath::Error` boundary.
- Stop freezing the caller-owned source string: `parse`/`compile` retain an internal frozen snapshot of the expression, so mutating the caller's String afterwards does not affect the compiled program.

## [0.1.0.pre1] - 2026-09-04

- Added the Ruby-native parser, immutable AST, collection-first evaluator, plain model boundary, structured errors, capability object, and function registry.
- Added path navigation, literals, arithmetic, selected comparisons, Boolean operators, indexers, filtering, existence functions, and reusable compiled expressions.
- Added collection-aware equality/equivalence, normalized string and decimal equivalence, empty/not/all functions, string addition, union, membership, primitive type operators, comments, and strict string-escape handling.
- Added a small JSONL differential-vector runner and six checked-in compatibility vectors.
- Documented the prototype scope, architecture, limitations, and staged conformance plan.

[Unreleased]: https://github.com/niccoreyes/fhirpath-ruby/compare/v0.1.0.pre1...HEAD
[0.1.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.1.0.pre1
