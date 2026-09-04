# Security policy

## Scope

This project evaluates expressions against caller-supplied Ruby data. The supported pure-evaluation boundary does not perform network I/O and the plain model intentionally does not dispatch arbitrary Ruby methods selected by an expression.

Do not provide production credentials, personal data, or live clinical data in issues, vectors, fixtures, or pull requests.

## Reporting a vulnerability

Please do not disclose an exploitable vulnerability in a public issue. Use GitHub's private vulnerability reporting or security-advisory channel for this repository when available. If that channel is unavailable, contact the repository owner through GitHub and provide only the minimum reproducible details needed to triage the issue.

Reports should include the affected version/commit, Ruby version, expression and fixture reduced to synthetic data, impact, and a suggested mitigation if known. Please allow time for investigation before public disclosure.

## Supported versions

The project is MIT-licensed but pre-release. Security fixes are evaluated
against the current `main` branch and the latest published version, if any.
The gem is not yet published as a production release; see
`docs/release-checklist.md` for the remaining release gates.
