---
name: Conformance / differential evidence
about: Add shared-suite, compatibility, or differential evidence for a capability.
title: "[conformance] "
labels: ["type:feature", "area:conformance"]
assignees: ''

---

## Capability

Which FHIRPath capability / function family this evidence covers.

## Evidence source

- HL7 shared suite case / category: (link or category)
- `fhirpath-py` reference expression: (link to upstream case at a pinned SHA)
- Independent engine used (e.g. fhirpath.js, Firely, HAPI): (version)

## Classification

`normative` / `stu3` / `host-dependent` / `unsupported` / `defect`

## Records to add

- [ ] JSONL vector record with `origin.suite`/`origin.commit` and
      `expected` result (or structured `error`)
- [ ] Differential record: `suite, suite_commit, expression, input_fixture,
      model, expected, actual, target, host_features, classification`
- [ ] Update `docs/conformance.md` and `docs/feature-matrix.md`

## Notes

Do NOT report a single aggregate "compatibility %" without the classification
breakdown and target release.
