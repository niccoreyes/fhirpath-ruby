# Conformance and differential workflow

The project distinguishes specification conformance from compatibility evidence.

- The HL7 FHIRPath specification and official shared test cases are normative.
- Checked-in JSONL vectors are small, reviewable regression probes inspired by observed behavior in `fhirpath-py`.
- No Python runtime is required to run the Ruby vector harness.
- The repository ships a Ruby-only importer for official XML suites and the pinned `fhirpath-py` YAML case format.
- The default manifest imports a pinned subset; `load_full_suite: true` imports the complete official suite.

## Run the checked-in vectors

From a clean checkout:

```sh
bundle install
bundle exec ruby script/run_vectors.rb conformance/core.jsonl
```

The same check is available as:

```sh
bundle exec rake vectors
```

The runner emits JSON containing `total`, counts for each classification, and per-case actual results/errors. Classifications are:

- `pass`: actual result or expected structured error matches;
- `defect`: behavior differs from the vector;
- `unsupported`: the Ruby engine raised `UnsupportedFeatureError`;
- `host-dependent`: evaluation needs an unavailable host service; and
- `not-run`: reserved for cases intentionally skipped by a future importer.

A vector has this shape:

```json
{"id":"eq-string-001","target":"2.0.0","expression":"'ab c' ~ 'Ab  C'","resource":{},"variables":{},"expected":[true],"origin":{"suite":"fhirpath-py","commit":"19f6316","case":"manual"}}
```

For errors, use an expected object instead of treating any exception as success:

```json
{"id":"bad-input-001","target":"2.0.0","expression":"1 ???","resource":{},"expected":[],"error":{"class":"FHIRPath::ParseError","code":"invalid_token"},"origin":{"suite":"manual","case":"parser"}}
```

Values that JSON cannot represent should use explicit tagged values when that family is implemented, for example `{"$type":"decimal","value":"1.10"}`. Keep each vector's expression, target release, fixture, expected result/error, and provenance together.

## Adding a vector

1. Confirm the expected behavior against the HL7 specification.
2. If using another implementation as a probe, record its exact commit and case in `origin`; never copy implementation internals into the gem.
3. Add a focused Ruby test for the behavior.
4. Add the JSONL vector and run the complete test, lint, build, and vector commands.
5. Update `docs/feature-matrix.md`, README limitations, and `CHANGELOG.md` if the public scope changes.

## Import the complete official suite

Set `load_full_suite: true` in the manifest to bypass `case_ids` filtering and import every XML case from the official suite. The importer still applies the same fixture normalization, provenance tracking, and `not-run` classification rules as the pinned-subset mode.

```json
{
  "schema": "fhirpath-conformance-v1",
  "suite": "FHIR/fhir-test-cases",
  "suite_commit": "1.7.69",
  "target": "2.0.0",
  "model": "plain",
  "source": "r4/fhirpath/tests-fhir-r4.xml",
  "fixture_root": "r4",
  "load_full_suite": true
}
```

## Import a pinned suite subset

The importer accepts the checked-in manifest and a local checkout of its pinned source:

```sh
bundle exec ruby script/import_vectors.rb /path/to/fhir-test-cases
```

It emits one JSON record per selected XML case. XML fixtures are resolved to verified same-resource JSON counterparts when available (structural match: matching resource type and id), and converted via `FHIRXmlConverter` when no verified JSON fixture exists. The converter raises `UnsupportedStructureError` for structures it cannot faithfully represent; the importer records those as `not-run` with an explicit reason rather than emitting a resource with wrong types. `input_fixture` retains the original XML path and `fixture_source` records the actual source used. Otherwise the record is retained as `not-run` with an explicit reason. Disabled cases are also retained as `not-run` and are never evaluated.

The same importer accepts a `fhirpath-py` YAML case file when initialized with its checkout as `source_root`. YAML is parsed with safe loading, group and `disable` state are preserved, expression lists become independent records, and each record keeps the suite commit and original fixture path. `error: true` means a FHIRPath error is expected; an unrelated Ruby `StandardError` remains a defect.

Every record includes `suite`, `suite_commit`, `expression`, `input_fixture`, `model`, `host_features`, `expected`, `target`, and provenance. Runner reports include per-capability totals for `pass`, `defect`, `unsupported`, `host-dependent`, and `not-run`. Unsupported and host-dependent cases remain evidence rather than passes; defects and unexplained skips block release checks.
