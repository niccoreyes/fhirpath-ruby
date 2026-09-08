# Changelog

All notable changes to this project are documented here. The project is pre-1.0; the API and supported behavior may change between releases.

## [Unreleased]

## [0.2.0.pre7] - 2026-09-08
- Change the default FHIR model from `PlainModel` to `FHIR::R4::ModelProvider`: omitted `model:` now uses R4, enabling choice navigation (`Observation.value`) and logical-type `is`/`as` metadata by default. Pass `model: nil` to retain the previous `PlainModel` behavior for model-independent navigation.

## [0.2.0.pre6] - 2026-09-08
- Add the `aggregate()` function with `$this`, `$total`, and `$index` variables for general-purpose collection aggregation (issue #43). The function signature is `aggregate(expression, initial)` where the expression is evaluated per item with the accumulator as `$total`. Empty collections return the initial value (or empty if omitted). Closes issue #43.
- Add keyword-named functions (`contains`, `in`) usable after member access (`Patient.name.contains('John')`) — the lexer previously classified these as binary operators only, preventing function-call syntax after `.` (issue #66). Also registers both as standard functions with arity 1.
- Accept raw JSON strings in `FHIRPath.evaluate()` and `CompiledExpression#evaluate`: strings starting with `{` or `[` after optional whitespace are parsed via `JSON.parse` once per call; malformed JSON raises `JSONInputError` (code `:invalid_json`); `Hash`/`Array` inputs pass through unchanged; other strings remain singleton string values (issue #56).
- Add bounded Quantity/UCUM support: immutable `BigDecimal`-backed `FHIRPath::Quantity` type with case-sensitive conversion for the explicit subset (`m`, `cm`, `mm`, `km`, `g`, `kg`, `mg`, `Mg`, `ug`, `ng`, `L`, `mL`, `ML`, `uL`, `mol`, `mmol`, `umol`, `s`, `min`, `h` and products/quotients such as `mmol/L`). Same-dimension comparison/addition/subtraction/multiplication by scalar/division; incompatible or unsupported-unit operations return empty. The UCUM parser is dependency-free and exponents are bounded to 12 to prevent CPU/memory amplification (issue #44).
- Expand R4 model adapter choice elements: `Medication`, `Condition`, `Procedure`, and `DiagnosticReport` choice elements now resolve through the FHIRPath navigation layer (issue #46).
- Import and check in the full official HL7 FHIRPath shared test suite (935 cases from `fhir-test-cases` release `1.7.69`) with a new `load_full_suite` importer mode that bypasses the pinned `case_ids` subset (issue #47).
- Document JSON input behavior in `docs/api.md` and add FHIR-native JSON examples to the README Quick Start.
- Clean up redundant README badges and update the version reference to `0.2.0.pre6`.
- Fix the release workflow asset verification to derive the exact gem filename from `RELEASE_TAG` instead of a literal glob (previous `jq index("fhirpath-*.gem")` always failed).

## [0.2.0.pre5] - 2026-09-07
- Add a dependency-free, explicitly bounded FHIRPath `Quantity` type. Quantity values always store a finite `BigDecimal` and expose `value`, `unit`, `system`, and `code`; the supported UCUM unit subset and the maximum exponent bounds are documented in the release support matrix. Same-dimension operations work; incompatible or unsupported-unit operations return an empty collection.
- Accept raw JSON string documents in `FHIRPath.evaluate` and `CompiledExpression#evaluate`. Strings that begin with `{` or `[` after optional whitespace are parsed as JSON; malformed JSON raises `JSONInputError`. All other strings continue to be treated as singleton string values.
- Add `ofType()` and FHIR resource-type filtering.
- Add Date, Time, and DateTime types with literals, functions, timezone support, comparisons, and component extractors.
- Add FHIR primitive extension accessors (`._<name>`).
- Expand R4 model adapter choice elements for `Medication`, `Condition`, `Procedure`, and `DiagnosticReport`.

## [0.2.0.pre4] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre3] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre2] - 2026-09-06
- n/a (release pipeline preparation)

## [0.2.0.pre1] - 2026-09-06
- Initial public pre-release on RubyGems.
