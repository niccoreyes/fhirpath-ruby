## feat: add raw JSON string input (issue #56)

### Summary
Enables `FHIRPath.evaluate` and `CompiledExpression#evaluate` to accept raw JSON document strings directly, eliminating the need for manual `JSON.parse` by callers processing FHIR JSON in its common HTTP-body form.

### Changes
- **Automatic JSON parsing**: Strings that open with `{` or `[` after leading whitespace are parsed as JSON objects/arrays
- **Preserved semantics**: Hash/Array resources and non-document strings (plain text, JSON scalars like `"null"`/`"123"`, quoted primitives) retain their existing behavior
- **Immutability**: Caller's String and Hash/Array resources are never mutated or re-serialized
- **Encoding support**: Handles UTF-8, UTF-16LE/BE, UTF-32LE/BE with BOM stripping
- **Error handling**: Invalid JSON raises structured `FHIRPath::JSONInputError` (code `:invalid_json`) with:
  - Generic public message: "resource string is not valid JSON"  
  - Parser detail only accessible via `original_cause` (no document content echo)
- **Documentation**: Updated docs/api.md, docs/feature-matrix.md, CHANGELOG.md, and README.md

### Testing
- 16 focused JSON-input tests / 44 assertions
- Full suite: 283 runs, 802 assertions, 0 failures
- Vectors: 5 runs, 19 assertions, 0 failures
- RuboCop: Clean
- Coverage: 92.6% (1319/1424 executable lines)
- Gem build and release verification passed

### Verification
All changes were developed in isolated worktrees and verified through:
- Independent quality/security review (passed: true, no blockers)
- Combined integration gate with Quantity/UCUM feature (passed: true)
- Full test suite, RuboCop, vector tests, coverage, gem build, and release verification

Ready for review and merge.