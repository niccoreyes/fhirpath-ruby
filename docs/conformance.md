# Conformance and differential workflow

The project distinguishes specification conformance from compatibility evidence.

- The HL7 FHIRPath specification and official shared test cases are normative.
- Checked-in JSONL vectors are small, reviewable regression probes inspired by observed behavior in `fhirpath-py`.
- No Python runtime is required to run the Ruby vector harness.
- The current repository does not yet ship an importer for the official HL7 shared XML suite; complete conformance remains deferred.

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

## Future official-suite importer

A future importer should preserve the source suite revision and case identifier, normalize fixtures without losing typed values, and report `pass`, `defect`, `unsupported`, `host-dependent`, and `not-run` separately. It must not turn unsupported cases into passes. Release notes should include the target release, suite revision, counts, and known host/model exclusions.
