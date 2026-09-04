# FHIRPath Ruby usability audit

> Historical audit snapshot (2026-09-04). Current release-hardening status is tracked in [`docs/release-checklist.md`](release-checklist.md); do not read the point-in-time gaps below as the current implementation state.

Post-audit update (2026-09-05): the project license decision was resolved in
favor of MIT. The historical findings below that describe an unresolved license
remain evidence from the audit revision and are superseded by the current
release checklist.

Audit date: 2026-09-04
Audited revision: `b172b32` (`Pin CI development tooling`)
Repository: https://github.com/niccoreyes/fhirpath-ruby [14]

## Executive conclusion

The project is a coherent, loadable prototype for a deliberately small Ruby-native FHIRPath slice. It is not yet a generally usable FHIRPath library, a drop-in `fhirpath-py` equivalent, or a release-ready gem.

The current slice is useful for plain Hash navigation, literals, selected arithmetic/comparison/Boolean behavior, indexers, `where`, `select`, `first`, `exists`, `count`, external constants, immutable parsed/compiled boundaries, and structured errors. The repository documents those limits clearly in `README.md` and `docs/first-slice.md`.

The most important correctness finding is that `lib/fhirpath/evaluator.rb` requires singleton operands for `=`/`!=` and equivalence. FHIRPath equality is collection-aware: the specification defines pairwise behavior for multiple-item collections and empty propagation.[17] This is a semantic defect, not merely a missing feature. The current test in `test/foundation_test.rb` encodes the same singleton behavior and should be replaced with specification-backed tests before expanding the implementation.

The most important release blockers are the unresolved license, the absence of a conformance/shared-suite harness, the very small tested feature surface, and CI/package metadata that do not yet establish a declared support policy. No RubyGems release or repository release exists, which is appropriate while the license remains unresolved.

## Evidence snapshot

Local verification at `b172b32`:

- `bundle exec rake test`: 29 runs, 102 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop`: 22 files inspected, no offenses locally.
- `git diff --check`: passed.
- `bundle exec rake build`: built `pkg/fhirpath-0.1.0.pre1.gem`.
- Local Ruby is 2.6.10; the gemspec declares `>= 2.6.0`.
- The built gem reports version `0.1.0.pre1`, required Ruby `>= 2.6.0`, and `licenses: []`; its package file list contains the runtime, README, Gemfile, Rakefile, `.rubocop.yml`, and placeholder `LICENSE`, but not the `docs/` directory.
- GitHub Actions run 33840252202 is green for the current revision, with Ruby 3.2 and 3.3 jobs. The preceding run for `6b0622e` failed RuboCop; that was fixed by the current revision.
- GitHub reports no tags, no releases, and no branch protection for `main`.[14][15]

The local green run is evidence that the prototype works on its current development environment; it is not evidence of FHIRPath conformance or support for every Ruby version in the gemspec.

## What the comparison project establishes

The comparison is against the current `master` state of `beda-software/fhirpath-py`, whose latest observed commit is `19f6316` and whose latest release is `v2.2.4`.[1][16]

Observed project expectations:

1. **Installable, versioned library.** Its README documents `pip install fhirpathpy`, `evaluate`, `compile`, FHIR model use, and user-defined functions. Its package metadata declares Python `>=3.10`, typed packaging, MIT licensing, runtime dependencies, project URLs, and a Production/Stable classifier.[2][3][9]
2. **Broad behavior and model coverage.** The repository contains parser grammar/source, an engine split into evaluator and semantic function families, FHIR model maps for DSTU2/STU3/R4/R5, resource fixtures, AST fixtures, and a large YAML case corpus covering paths, existence, filtering, subsetting, combining, conversion, strings, math, tree navigation, equality, comparison, types, collections, Boolean logic, aggregates, variables, extensions, quantities, and FHIR R4.[8][11][12]
3. **Repeatable automated verification.** Its build workflow tests Python 3.10 through 3.14, runs pytest with coverage output, and uploads coverage to Codecov. Its repository also contains pre-commit checks for formatting and YAML/TOML validity.[4][6]
4. **Release mechanics.** Its publish workflow builds package artifacts on a GitHub release and publishes to PyPI. It maintains a changelog and an MIT license.[5][7][13]
5. **Contribution documentation is limited.** There is no `CONTRIBUTING.md` in the observed repository tree.[8] Therefore, the comparison should not invent a contributor policy that the reference project does not state; the practical expectations above come from its README, metadata, test layout, CI, publish workflow, changelog, and license.

Its parser module constructs the generated lexer/parser and attaches an error listener, which is a useful parser/error-boundary comparison point.[10]

These are useful maturity baselines, not requirements that Ruby copy Python APIs, ANTLR-generated artifacts, mutable resource annotations, or Python packaging choices. The HL7 specification and shared test cases remain the conformance authority.

## Definition of usable

Use the following gates instead of a single compatibility percentage.

### Gate A — documented prototype usability

Pass only when all are true:

- `require "fhirpath"` works from a clean bundle and exposes a version.
- `parse`, `compile`, `evaluate`, and `evaluate_first` have documented signatures and stable result policy.
- Every advertised expression either has a passing focused test or raises a documented structured `FHIRPath::Error` classification.
- Empty collections, singleton extraction, ordering/flattening, nested focus, `$this`, `$index`, `$total`, external constants, and compiled-expression reuse are directly tested.
- Malformed and trailing input cannot be accepted as a valid prefix.
- The README's supported/deferred lists match executable behavior.

The current project largely meets this gate, subject to the equality defect and the parser escape cases noted below.

### Gate B — dependable core library

Add all of the following:

- A pinned FHIRPath target and grammar/test-suite revision, plus a feature matrix.
- Specification-backed tests for collection-aware equality/equivalence, three-valued logic, singleton-required operators, numeric precision, escapes, and error behavior.
- An importer for the official shared FHIRPath cases, preserving fixture provenance and reporting `pass`, `fail`, `unsupported`, `host-dependent`, and `not-run` separately.
- Differential tests against a pinned `fhirpath-py` version or another independent engine, with every difference classified against the HL7 specification.
- The remaining normative model-independent value/function families (or an explicit capability report that keeps them unsupported).
- A stable error serialization contract covering parse, evaluation, type, singleton, unknown function/constant, model, host, and unsupported-feature failures.
- Thread/reentrancy tests proving a compiled expression does not retain resources, variables, focus, trace state, or mutable caches.

The current project does not meet this gate.

### Gate C — FHIR-integrated usability

Add a separately loaded, versioned model adapter and fixtures for an approved FHIR release. It must cover resource/type roots, logical paths, choice elements such as `Observation.value`, primitive extensions, type checks, and missing-field behavior without making the core depend on one FHIR package.

The current project has `PlainModel` only and does not meet this gate.

### Gate D — releasable gem

Before calling the package production/stable or publishing it:

- Select and document a project license; set `spec.license`/`spec.licenses` and license metadata; replace the placeholder `LICENSE`.
- Define the supported Ruby versions and test every declared supported line in CI, or narrow `required_ruby_version` to the tested policy.
- Build and install the gem in CI, inspect its contents and metadata, and smoke-test it from a clean temporary project.
- Add changelog/release notes, API compatibility policy, security/contact guidance, and a repeatable tag/release workflow.
- Include coverage and conformance summaries in release evidence.
- Audit runtime/development dependencies and any grammar/generated artifacts for license/notice obligations.
- Protect the release branch and require passing CI before merge once collaboration begins.

The current project does not meet this gate. Publication is specifically blocked by the unresolved license.

## Prioritized gap inventory

Priority labels:

- **P0 / defect or release blocker:** fix before expanding claims or publishing.
- **P1 / required capability:** needed for dependable library usability, but can be staged.
- **P2 / enhancement:** valuable after the core contract and evidence exist.

| ID | Priority and type | Finding | Concrete recommendation |
|---|---|---|---|
| U-01 | P0 — release blocker | `LICENSE` is a placeholder and `fhirpath.gemspec` does not set a license. The built gem reports no licenses, while the public repository is visible on GitHub. | Decide the license deliberately; replace `LICENSE`; add `spec.license` or `spec.licenses`, SPDX/project metadata, and any required `NOTICE`. Update `README.md` and add a dependency/license inventory before any release or reuse claim. |
| U-02 | P0 — semantic defect | `Evaluator#equality` calls `require_singleton` for both operands. This rejects expressions such as `{1, 2} = 2` instead of applying collection-aware equality. Equivalence is treated as singleton-only as well. The current `test_equality_requires_singleton_operands` preserves the defect. | Add RED tests from the pinned HL7 cases for equality/equivalence over empty, singleton, and multi-item collections; implement the standard pair/collection rules in `lib/fhirpath/evaluator.rb`; remove or relabel the contradictory foundation test. Keep singleton enforcement for operators that actually require it. |
| U-03 | P0 — support-policy gap | The gemspec declares Ruby `>= 2.6.0`, but CI tests only 3.2 and 3.3. Conversely, Ruby 2.6 is locally exercised but not remotely verified. The project cannot make a support promise from this matrix. | Choose a maintained Ruby support policy. Either test every declared line (including compatibility constraints for 2.6) or narrow `required_ruby_version`. Add a CI job for gem build/install smoke tests and run tests/lint/build on every matrix entry. |
| U-04 | P0 — conformance/release blocker | The project has no shared-suite importer, pinned conformance corpus, differential runner, coverage report, or machine-readable feature matrix. The 29-run suite is valuable but only tests the hand-built slice. | Add `test/support` or `conformance/` loaders and a report format containing suite commit, expression, fixture, target release, expected/actual result or error, host features, and classification. Add coverage collection and publish the report as a CI artifact. |
| U-05 | P1 — missing normative behavior | `FunctionRegistry.standard` contains only `where`, `select`, `first`, `exists`, and `count`; the evaluator special-cases those functions. The reference project's registry and cases cover substantially broader standard families. | Implement in vertical semantic families, beginning with collection combining/subsetting, type/conversion, exact numeric behavior, strings, and remaining existence/filtering functions. Each family needs capability labels, focused tests, shared cases, and differential evidence before it is advertised. |
| U-06 | P1 — missing value system | Runtime values are mostly Ruby `Integer`, `BigDecimal`, `String`, and Boolean. Date/DateTime/Time, Quantity/UCUM, Long/STU features, type operators, precision/timezone rules, and advanced conversion semantics are deferred. | Add immutable `Value::*` classes and explicit conversion/precision policy. Keep temporal and UCUM dependencies behind documented boundaries and audit their licenses. Do not add convenience coercions that collapse empty or singleton semantics. |
| U-07 | P1 — missing FHIR integration | `PlainModel` supports Hash and Struct access only; there is no versioned FHIR model provider, logical path map, choice-element handling, primitive-extension handling, or FHIR fixture suite. | Define and implement `ModelProvider` plus a separately loaded first-release adapter. Add fixtures for resource roots, choice fields, primitive extensions, logical types, and missing fields. Keep core tests dependency-free. |
| U-08 | P1 — capability contract is descriptive only | `Capability` records release/features, but parser/evaluator behavior does not enforce capability flags. Parser syntax and evaluator support are therefore not yet mechanically tied to the advertised capability. | Add a capability/feature matrix and tests showing each gated feature is either enabled with behavior or rejected as `UnsupportedFeatureError`. Pin grammar and shared-suite revisions. Make conformance output include the capability. |
| U-09 | P1 — API compatibility/stability work missing | The Ruby API intentionally differs from `fhirpath-py` (collection-first results and `evaluate_first` are reasonable choices), but there is no compatibility policy for path objects with `base`, typed compile helpers, raw values, default variables, or option behavior. | Document that this is a Ruby-native API, then add API contract tests for keyword arguments, return types, immutability, compiled reuse, custom function registration, and error fields. Add compatibility conveniences only when a concrete consumer needs them. |
| U-10 | P1 — host/error boundary incomplete | `HostServices` exposes resolver, terminology, children, and trace slots, but only constants are callable. Custom function exceptions are not consistently normalized, and `FunctionSpec#receiver` is not validated. | Either document these as reserved interfaces or implement them with explicit `HostError`/capability behavior. Validate receiver/arity/parameter kinds, preserve safe causes, and test host failures without leaking sensitive context. |
| U-11 | P1 — parser edge correctness | The lexer silently drops the backslash for unknown escapes (`'a\\q'` becomes `aq`) and handles `\\U` as four hex digits rather than a full code point. Comments, delimited identifiers, date/time/quantity literals, and other grammar constructs are not supported. | Pin the selected grammar revision; add lexer tests for every supported escape and invalid escape, comments, identifiers, and Unicode boundary cases. Reject unsupported constructs with a stable parse/unsupported classification rather than silently changing source meaning. |
| U-12 | P1 — documentation/release evidence | README and design docs are unusually clear for a prototype, but there is no `CHANGELOG.md`, API reference, conformance report, support matrix, contribution guide, or release checklist. `docs/` is not included in the built gem. | Add `CHANGELOG.md`, `docs/api.md` or generated API docs, a support/feature matrix, conformance-report instructions, and a short contributor workflow. Decide whether user-facing docs belong in the gem and test the chosen package contents. |
| U-13 | P1 — CI quality gate | Current CI runs tests and RuboCop, but not `git diff --check`, gem build/install, coverage, conformance, dependency/license checks, or a supported-Ruby matrix matching the gemspec. | Extend `.github/workflows/ci.yml` incrementally: test, lint, diff/package checks, gem smoke install, coverage, and conformance report. Keep release publishing in a separate workflow triggered only by an approved/tagged release. |
| U-14 | P2 — maintainability enhancement | The evaluator uses a growing node/function `case` and special-cases standard functions, making completeness auditing harder as the function surface expands. | Once behavior is covered, migrate toward registry metadata plus semantic-family handlers/visitor dispatch. Do not refactor before shared tests and capability labels exist; architecture should follow verified behavior. |
| U-15 | P2 — operational enhancement | There is no trace implementation, cancellation policy, compiled-expression cache policy, or concurrency benchmark. These are not required for the pure prototype, but matter for embedding in servers. | Add only for a concrete host use case. Define redaction, ownership, invalidation, cancellation, and thread-safety contracts before adding global caches or I/O. |
| U-16 | P2 — repository governance | GitHub reports no protection on `main`, no tags, and no releases. This is acceptable for a private-style prototype but insufficient for a public collaborative release. | After the license and contribution policy are settled, protect `main`, require CI, tag from reviewed commits, and use release notes tied to a conformance summary. |

## Recommended implementation order

1. **Correctness gate:** fix U-02 with specification-backed tests; add parser escape tests from U-11; preserve explicit unsupported behavior.
2. **Contract/evidence gate:** implement U-04's pinned suite loader, feature matrix, classifications, coverage, and a small differential corpus before adding large feature families.
3. **Support gate:** resolve U-03 and extend CI/package smoke checks in U-13.
4. **Normative core gate:** deliver U-05 and U-06 in small vertical slices, keeping the README and capability output synchronized with passing evidence.
5. **FHIR gate:** deliver U-07 as a separate adapter and fixture lane.
6. **Release gate:** resolve U-01, add U-12 release documentation, and only then consider a non-pre-release gem and protected release workflow.
7. **Optional hardening:** U-10, U-14, U-15, and U-16 as real embedding/repository needs arise.

Do not use the existence of `Capability`, value-object placeholders, or a successful gem build as evidence that the corresponding behavior is implemented. Every release claim should point to executable tests and a classified conformance report.

## Sources

External comparison evidence was retrieved from the following current upstream files and repository APIs:

[1] https://github.com/beda-software/fhirpath-py — current comparison repository; observed latest release `v2.2.4` and MIT license.

[2] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/README.md — installation, API, FHIR model, custom function, and development instructions.

[3] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/pyproject.toml — Python/package metadata, dependencies, classifiers, typing, pytest, and lint configuration.

[4] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/.github/workflows/build.yaml — CI matrix, pytest, coverage generation, and Codecov upload.

[5] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/.github/workflows/publish.yaml — release-triggered package build and PyPI publishing workflow.

[6] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/.pre-commit-config.yaml — formatting and YAML/TOML pre-commit checks.

[7] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/CHANGELOG.md — release history and stated feature progression.

[8] https://api.github.com/repos/beda-software/fhirpath-py/git/trees/master?recursive=1 — current repository tree, including parser, engine/function families, FHIR models, fixtures, YAML cases, AST fixtures, and absence of `CONTRIBUTING.md`.

[9] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/__init__.py — current public API, version `2.2.4`, compile helpers, options, and result conversion.

[10] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/parser/__init__.py — parser construction and error-listener setup.

[11] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/fhirpathpy/engine/invocations/__init__.py — standard function/operator registry and metadata examples.

[12] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/tests/conftest.py — YAML collection, resources, variables, models, expected results, and current comparison harness.

[13] https://raw.githubusercontent.com/beda-software/fhirpath-py/master/LICENSE.md — MIT license text.

[14] https://github.com/niccoreyes/fhirpath-ruby — audited Ruby repository.

[15] https://github.com/niccoreyes/fhirpath-ruby/actions/runs/33840252202 — current revision's successful GitHub Actions run.

[16] https://api.github.com/repos/beda-software/fhirpath-py/commits/master — observed current upstream `master` commit and release bump.

[17] https://raw.githubusercontent.com/HL7/FHIRPath/master/input/pages/index.md — normative collection, equality, and equivalence semantics; specifically the Operations/Equality sections.

Local evidence and recommendations refer to the audited checkout's files and line ranges at revision `b172b32`; no source code was changed by this audit.
