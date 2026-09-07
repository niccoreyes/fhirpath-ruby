# Plan for Issue #47: Expand to full HL7 shared test suite

## Current State
- The conformance importer currently loads only a small pinned subset (4 test cases) from official-r4-core.json
- The official HL7 test suite is much larger and provides comprehensive validation
- We need to expand the importer to load the complete test suite

## Required Changes
1. Modify the conformance importer to optionally load ALL test cases from the XML suite
2. Update the manifest format to support loading the full suite
3. Ensure the vector runner can handle the larger test set
4. Update documentation and usage instructions

## Implementation Approach
- Add a flag or manifest option to load the full test suite instead of just pinned cases
- When loading full suite, bypass the case_ids filtering in select_tests()
- Ensure all existing functionality remains intact (backward compatibility)
- Update the official-r4-core.json manifest to support both modes

## Files to Modify
- lib/fhirpath/conformance/importer.rb
- conformance/official-r4-core.json (manifest)
- docs/conformance.md (documentation)
- Possibly: script/import_vectors.rb (if CLI changes needed)