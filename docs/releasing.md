# Releasing FHIRPath for Ruby

This document defines the versioning, release-gate, RubyGems, and GitHub
publication workflow. Publication is performed only from a reviewed, pushed
tag; the release workflow never packages a dirty local checkout.

## Versioning policy

- The gem name is `fhirpath` and tags use the form `vVERSION`.
- Versions follow RubyGems-compatible Semantic Versioning. While the API and
  conformance surface are pre-1.0, use `0.MINOR.PATCH` and a prerelease suffix
  such as `0.1.0.pre1` for published previews.
- `lib/fhirpath/version.rb`, `CHANGELOG.md`, and the release tag must agree.
- `FHIRPath::RELEASE_CHANNEL` remains `pre-release` until the complete
  promotion decision is made. The release verifier rejects a stable-looking
  version while that channel is still pre-release.
- Every release updates the `Unreleased` section into a dated version section,
  adds the comparison link, and preserves explicit supported, unsupported, and
  host-dependent behavior.

## Required gates

A release tag advances only when all of these checks pass on the tagged source:

1. Ruby 3.2 and Ruby 3.3 CI matrix;
2. full Minitest suite and RuboCop;
3. checked-in compatibility vectors, with no `defect` or `not-run` cases;
4. coverage generation and summary validation;
5. `gem build` from the tag;
6. isolated local installation and `1 + 2` API smoke test;
7. package metadata verification, including version, MIT license, exact
   FHIRPath target, capability set, release status, and support-matrix URI;
8. release notes generated from the feature/support matrix and current vector
   evidence; and
9. a SHA-256 manifest covering the published gem and conformance report.

Unsupported and host-dependent behavior may remain in a pre-release, but it
must be listed in the support matrix and release notes. A defect or silently
skipped case is a hard failure.

## RubyGems publication

The `publish` job supports two authentication modes:

1. **Repository API key (default when configured):** store the owner's RubyGems
   API key as the `RUBYGEMS_API_KEY` repository secret (`gh secret set
   RUBYGEMS_API_KEY --repo niccoreyes/fhirpath-ruby`). The workflow passes it as
   `GEM_HOST_API_KEY` and runs `gem push` directly.
2. **RubyGems Trusted Publishing (fallback):** when the secret is absent, the
   workflow configures short-lived OIDC credentials and pushes with them.
   Configure a pending trusted publisher (for a new gem) or a trusted publisher
   (for an existing gem) with:

- owner: `niccoreyes`;
- repository: `fhirpath-ruby`;
- workflow name: `Release`;
- environment: `release`.

The workflow's `publish` job has only `id-token: write` and read access to
repository contents. It downloads the exact artifact produced by the gated
package job, pushes the exact gem, and reads the RubyGems API back until the
exact version is visible.

## GitHub release publication

After RubyGems confirms the exact version, the workflow creates a GitHub release
for the existing tag and attaches:

- the `.gem` artifact;
- `SHA256SUMS.txt`; and
- the JSON compatibility/conformance report.

The generated notes include the FHIRPath target, capability set, supported
behavior, explicit unsupported/deferred behavior, host-dependent behavior,
verification evidence, and artifact provenance. The GitHub release is marked
as a prerelease while the gem version is prerelease.

## Manual operator procedure

1. Update `lib/fhirpath/version.rb` and the `Unreleased` changelog section.
2. Run every command in `CONTRIBUTING.md`, inspect the gem contents, and review
   `docs/support-matrix.md` and `docs/release-checklist.md`.
3. Open and merge the review PR; do not tag an unreviewed or dirty checkout.
4. Create and push the matching `vVERSION` tag from the reviewed commit.
5. Approve the `release` environment if required by repository settings.
6. Verify the workflow, RubyGems version, GitHub release, assets, checksums, and
   notes. If any external readback disagrees, stop and investigate before retrying.
