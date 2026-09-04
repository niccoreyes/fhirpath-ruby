# FHIRPath for Ruby

This repository is the foundation for a Ruby implementation of the [HL7 FHIRPath](https://hl7.org/fhirpath/) expression language.

The project is intentionally small at this stage. It provides a loadable `FHIRPath` namespace and version, but does not yet claim parser or evaluator support. The public API and staged implementation plan will follow the architecture review in `docs/architecture.md` and `docs/roadmap.md`.

## Requirements

- Ruby 2.6 or newer
- Bundler

## Setup

```sh
bundle install
```

## Development commands

Run the test suite:

```sh
bundle exec rake test
```

Run the formatter/linter:

```sh
bundle exec rubocop
```

Build the gem locally:

```sh
bundle exec rake build
```

The default Rake task runs the test suite, so `bundle exec rake` is also supported.

## Current scope

Supported now:

- `require "fhirpath"`
- `FHIRPath::VERSION`
- `FHIRPath.version`

Not implemented yet:

- Lexing and parsing
- Abstract syntax tree nodes
- Expression evaluation
- FHIR resource/model integration
- FHIRPath type and collection semantics
- FHIRPath conformance claims

Unsupported behavior will be added deliberately behind stable public boundaries. Until those slices land, consumers should not interpret this scaffold as a working FHIRPath engine.

## License

No redistribution license has been selected yet. See `LICENSE`; the source is not currently offered for reuse under an open-source license.
