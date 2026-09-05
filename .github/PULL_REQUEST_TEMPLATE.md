<!-- PR template: pre-release FHIRPath Ruby -->
## Summary

<!-- One or two lines: the user-visible behavior and the FHIRPath rule it
     implements, or the config/process change. -->

## What changed

- [ ] Behavior / code
- [ ] Docs (feature matrix, README, API, architecture)
- [ ] Conformance/vector evidence
- [ ] CI / release tooling

## FHIRPath rule & compatibility

- Normative target: `2.0.0` (STU3 only where explicitly gated).
- Reference engine / suite case used: (suite + pinned commit / link).
- Classification: `normative` / `stu3` / `host-dependent` / `unsupported` / `defect`.

## Tests & verification

<!-- TDD: describe the RED→GREEN test and the exact local verification. -->

- [ ] Written a focused failing test first (RED observed)
- [ ] Minimal change passes it (GREEN observed)
- [ ] `bundle exec rake test` passes
- [ ] `bundle exec rubocop` passes
- [ ] `bundle exec rake vectors` passes
- [ ] `bundle exec rake build` and gem-install smoke pass
- [ ] `git diff --check` clean

## Known limitations

<!-- Anything deliberately out of scope, host-dependent, or deferred. -->

## Related

Closes #<issue>
