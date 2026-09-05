# Release checklist

This checklist is the gate for a reusable public release. It is intentionally explicit because a successful gem build is not the same as a legally releasable or conformant package.

## Current assessment (`0.1.0.pre1`)

| Criterion | Status | Evidence / rationale |
|---|---|---|
| `require "fhirpath"` from a clean install | Met | `script/verify_gem_install.sh` and API tests |
| Documented parse/compile/evaluate API | Met | `README.md`, `docs/api.md` |
| Explicit supported Ruby policy | Met | gemspec and CI matrix target Ruby 3.2/3.3; publication contract is `docs/support-matrix.md` |
| Exact FHIRPath target and capability set in package metadata | Met | `Capability.current`, gemspec metadata, and `script/verify_release.rb` |
| Tests, static checks, package build in CI | Met | `.github/workflows/ci.yml` |
| Reproducible checked-in vector workflow | Met | `docs/conformance.md`, `conformance/core.jsonl` |
| Coverage summary | Met | `COVERAGE=1` test workflow and `script/check_coverage.rb` |
| Tagged release workflow and checksummed assets | Met | `.github/workflows/release.yml` and `docs/releasing.md` |
| RubyGems publication and external readback | Ready | Trusted Publishing environment gate and `gem push`; requires one-time RubyGems publisher setup |
| Contributor and security guidance | Met | `CONTRIBUTING.md`, `SECURITY.md` |
| Changelog/release notes | Met | `CHANGELOG.md` and this checklist |
| Complete official HL7 shared-suite conformance | Partial | importer and full suite remain deferred |
| FHIR release model adapter | Partial | `PlainModel` only; adapters are host-dependent |
| License selected and encoded in package metadata | Met | MIT License text is checked in at `LICENSE`; `fhirpath.gemspec` declares `MIT` |
| RubyGems/public reusable release | Pre-release only | The workflow permits prerelease tags; stable promotion remains blocked by the channel and incomplete conformance/model gates |

## Required before publication

- Audit runtime and development dependency licenses and any future grammar/fixture provenance.
- Confirm the supported Ruby matrix and run it on the tagged source revision.
- Build from a clean committed checkout; inspect gem contents and metadata.
- Run the complete tests, RuboCop, vectors, coverage, and gem-install smoke test.
- Generate release notes with scope, limitations, conformance counts, known host/model exclusions, and checksum/provenance.
- Create a reviewed version tag and use `.github/workflows/release.yml` with the approved `release` environment; do not publish from a dirty tree.
- Verify the RubyGems readback, pushed commit, tag, GitHub release metadata, and uploaded artifacts after each external action.

The license decision is complete. This implementation adds the gated workflow,
but does not commit, push, create a tag, or publish a release.

## Integration countercheck (2026-09-05)

The post-hardening working tree was independently reviewed against the HL7 FHIRPath operator documentation and exercised locally. This pass corrected two implementation gaps: `&` now treats an empty operand as `''`, and relational/union/type parser precedence now follows the normative ordering. The nonstandard `\\UXXXXXXXX` string escape is rejected; valid UTF-16 `\\uXXXX` surrogate pairs are combined.

Verification on Homebrew Ruby 4.0.4 (the repository's local bundle contains native extensions for this runtime):

- `bundle exec rake test`: 50 runs, 191 assertions, 0 failures, 0 errors, 0 skips;
- `bundle exec rubocop`: 31 files inspected, no offenses;
- `bundle exec rake vectors`: 8 total, 8 pass, 0 defect, 0 unsupported, 0 host-dependent, 0 not-run;
- `bundle exec rake build`: `pkg/fhirpath-0.1.0.pre1.gem` built;
- `script/verify_gem_install.sh`: clean isolated install and `1 + 2` smoke test passed;
- `COVERAGE=1 bundle exec rake test` plus `script/check_coverage.rb`: 88.9% (829/932 executable lines); and
- `git diff --check`: passed.

The project is usable as a clearly scoped MIT-licensed pre-release core slice,
but it is not yet a complete FHIRPath implementation or production release.
The official HL7 shared-suite importer, temporal/quantity semantics, FHIR model
adapters, and broader standard function families remain explicitly deferred.
No commit, push, tag, publication, or external repository setting change was
performed.
