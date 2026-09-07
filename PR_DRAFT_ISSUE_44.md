## feat: add bounded Quantity/UCUM support (issue #44)

### Summary
Adds a dependency-free, explicitly bounded FHIRPath `Quantity` type with UCUM unit support for common clinical and scientific units.

### Changes
- **FHIRPath::Quantity**: Immutable value object storing a finite `BigDecimal` and exposing `value`, `unit`, `system`, and `code`
- **UCUM module**: Dependency-free, explicitly bounded unit conversion and validation supporting:
  - Length: m/cm/mm/km
  - Mass: g/kg/mg/Mg/ug/ng  
  - Volume: L/mL/ML/uL
  - Amount: mol/mmol/umol
  - Time: s/min/h
  - Simple products/quotients: mmol/L
- **Parser**: Supports integer, decimal, exponent, signed, single-quoted and double-quoted Quantity literals
- **Evaluator**: Supports Quantity arithmetic (+, -, *, /), comparisons, unary signs, scalar multiplication/division, Quantity/Quantity ratios
- **Type operators**: `ofType(Quantity)`, `is Quantity`, `as Quantity`
- **Safety**: Exponent bounds (`MAX_EXPONENT=12`) prevent CPU/memory amplification; case-sensitive unit symbols (Mg ≠ MG); incompatible operations return empty collection
- **Documentation**: Updated README.md, CHANGELOG.md, docs/feature-matrix.md, docs/support-matrix.md, and lib/fhirpath/capability.rb

### Testing
- 25 focused quantity tests / 105 assertions
- Full suite: 307 runs, 903 assertions, 0 failures
- Vectors: 5 runs, 19 assertions, 0 failures  
- RuboCop: Clean
- Coverage: 93.2% (1449/1554 executable lines)
- Gem build and release verification passed

### Limitations (explicitly documented)
- Not complete UCUM conformance — bounded subset only
- Derived-unit composition such as `km/h` deferred
- Quantity×Quantity operations deferred  
- Calendar-duration arithmetic deferred
- Mixed Quantity/scalar addition returns empty collection

### Verification
All changes were developed in isolated worktrees and verified through:
- Independent quality/security review (passed: true, no blockers)
- Combined integration gate with JSON input feature (passed: true)
- Full test suite, RuboCop, vector tests, coverage, gem build, and release verification

Ready for review and merge.