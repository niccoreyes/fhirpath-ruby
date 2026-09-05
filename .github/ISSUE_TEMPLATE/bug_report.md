---
name: Bug report
about: Report a behavior that doesn't match the declared FHIRPath contract.
title: "[bug] "
labels: ["type:bug", "area:core"]
assignees: ''

---

## Summary

Describe the failing behavior. State the exact expression, input resource, and
the declared contract you expect (cite the FHIRPath rule or docs page).

## Reproduction

```ruby
require "fhirpath"

# input
resource = { ... }

# expression
expression = "..."
```


Expected:
```
<expected>
```

Actual:
```
<actual error or value>
```

## Context

- FHIRPath target: `2.0.0`
- Ruby version: (e.g. 3.3)
- `fhirpath` gem version / commit:
- Is this `unsupported` (documented) or a `defect`?

## Regression criteria

Small test that must pass once fixed (one per behavior). Include the expected
RED output (fails for the missing behavior) in your description.

## Checklist

- [ ] Reproduced on current `main`
- [ ] Proposed fix is a small vertical slice with a failing-test-first change
- [ ] Will update `docs/feature-matrix.md` and limitations when scope changes
