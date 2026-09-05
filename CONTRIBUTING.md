# Contributing to FHIRPath for Ruby

Thanks for helping improve the Ruby implementation. It is a pre-1.0 project with a deliberately narrow supported slice, so correctness and honest scope are more important than adding a large number of names quickly.

## Development setup

Requirements:

- Ruby 3.2 or 3.3 (the supported CI matrix);
- Bundler; and
- Git.

From a fresh checkout:

```sh
bundle install
bundle exec rake test
bundle exec rubocop
bundle exec rake vectors
bundle exec rake build
bundle exec ./script/verify_gem_install.sh pkg/fhirpath-*.gem
```

Optional coverage:

```sh
COVERAGE=1 bundle exec rake test
bundle exec ruby script/check_coverage.rb coverage/summary.json
```

The repository intentionally does not require Python for its runtime or vector workflow.

## Change workflow

1. Open or find an issue describing the behavior or documentation change.
2. Read `docs/architecture.md`, `docs/feature-matrix.md`, and `docs/conformance.md` before changing evaluator semantics.
3. For behavior changes, write a focused failing test first (RED), implement the smallest change (GREEN), then run the complete checks above.
4. Add or update a vector when behavior has an independent reference or specification case.
5. Update the README, API docs, feature matrix, limitations, and changelog when the public contract changes.
6. Keep parser, evaluator, model, and host boundaries explicit. Do not add expression-controlled Ruby method dispatch, global evaluator state, or network I/O.
7. Keep commits focused and do not include build output, credentials, local state, or unrelated work.

## Pull requests

A useful pull request explains:

- the user-visible behavior and the FHIRPath rule it implements;
- tests added, including expected RED-to-GREEN behavior where relevant;
- vector/conformance evidence and any host-dependent exclusions;
- supported Ruby versions exercised; and
- documentation or compatibility impact.

Before requesting review, verify `git diff --check`, `bundle exec rake test`, `bundle exec rubocop`, `bundle exec rake vectors`, `bundle exec rake build`, and the gem-install smoke test. Do not claim complete FHIRPath conformance unless the official suite and release evidence support that claim.

For release work, also review [`docs/support-matrix.md`](docs/support-matrix.md),
[`docs/release-checklist.md`](docs/release-checklist.md), and
[`docs/releasing.md`](docs/releasing.md). Version changes must update
`lib/fhirpath/version.rb` and the matching `CHANGELOG.md` section; do not push a
release tag from a dirty or unreviewed checkout.

## Scope and licensing

The repository is licensed under the [MIT License](LICENSE), but remains
pre-release and does not claim complete FHIRPath conformance. Do not represent
it as a complete or production-ready engine; document compatibility evidence
and limitations in every behavior change. See `SECURITY.md` for vulnerability
reports.
