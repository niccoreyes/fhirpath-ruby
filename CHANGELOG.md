# Changelog

All notable changes to this project are documented here. The project is pre-1.0; the API and supported behavior may change between releases.

## [Unreleased]

- Correct `&` string concatenation to treat empty operands as empty strings, with regression coverage for both operators' empty-collection behavior.
- Correct parser precedence for relational, union, and type operators to match the FHIRPath grammar.
- Harden documentation, package verification, CI, coverage reporting, and contributor workflows.
- Add the release support matrix, exact package capability metadata, versioning policy, and gated RubyGems/GitHub publication workflow.
- Declare the project under the MIT License and encode the license in gem metadata.

## [0.1.0.pre1] - 2026-09-04

- Added the Ruby-native parser, immutable AST, collection-first evaluator, plain model boundary, structured errors, capability object, and function registry.
- Added path navigation, literals, arithmetic, selected comparisons, Boolean operators, indexers, filtering, existence functions, and reusable compiled expressions.
- Added collection-aware equality/equivalence, normalized string and decimal equivalence, empty/not/all functions, string addition, union, membership, primitive type operators, comments, and strict string-escape handling.
- Added a small JSONL differential-vector runner and six checked-in compatibility vectors.
- Documented the prototype scope, architecture, limitations, and staged conformance plan.

[Unreleased]: https://github.com/niccoreyes/fhirpath-ruby/compare/v0.1.0.pre1...HEAD
[0.1.0.pre1]: https://github.com/niccoreyes/fhirpath-ruby/releases/tag/v0.1.0.pre1
