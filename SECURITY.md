# Security policy

## Scope

This repository contains configuration examples and benchmark documentation. It does not host or redistribute model weights.

## Safe defaults

- All example servers bind to `127.0.0.1`.
- Example credentials are non-secret local placeholders.
- Model paths are placeholders and must be replaced locally.
- Only one generation runtime should be resident at a time.
- The router fails closed when the selected endpoint is unavailable or the other runtime is still listening.

## Reporting

Do not open a public issue containing credentials, private prompts, source code, logs, or filesystem paths. Use the repository owner's private security-reporting channel if one is enabled. Otherwise, provide a minimal redacted reproducer and ask for a private contact channel.

## Release hygiene

Run `scripts/validate-release.ps1` before publishing. It checks tracked content and Git history for common secret and private-path patterns. Review all findings manually; a clean automated scan is not a proof that content is safe.
