---
name: Feature request
about: Propose new FHIRPath behavior or an operational capability.
title: "[feat] "
labels: ["type:feature"]
assignees: ''

---

## Summary

What behavior/capability should be added, and which FHIRPath rule (or
usability gap) it implements.

## Why

Motivation / supported use case. Reference the HL7 FHIRPath spec section and
any `fhirpath-py` behaviour used as compatibility evidence.

## Proposed solution

How it should work within the existing Ruby-native API
(`parse` / `compile` / `evaluate` / `evaluate_first`, `Collection`,
`FHIRPath::Error` taxonomy). Name the capability/family and the public
surface it touches.

## Acceptance criteria

- [ ] Focused failing test written FIRST (RED), minimal change passes it (GREEN)
- [ ] Complete local checks pass (`rake test`, `rubocop`, `rake vectors`,
      `rake build`, gem-install smoke)
- [ ] `docs/feature-matrix.md`, README limitations, and changelog updated when
      the public contract changes
- [ ] Each capability is classified `normative` / `stu3` / `host-dependent` /
      `unsupported` / `defect`

## Alternatives considered

Any other approaches and why not.
