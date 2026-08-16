# Repository instructions

This is a public, documentation-first deployment recipe. It must never contain model weights, credentials, private logs, workstation-specific paths, usernames, job/session identifiers, or internal repository names.

Before changing a benchmark value, trace it to an existing evidence record and preserve its sample size and limitations. Do not invent or interpolate missing results. Keep the two runtime roles distinct: SGLang NVFP4 for long/complex work and llama.cpp Q5_K_M MTP3 for bounded work.

Validation:

```powershell
pwsh -NoProfile -File .\scripts\validate-release.ps1
```

The examples are intentionally generic and loopback-only. Do not add automatic model downloads, public network binds, or commands that run both generation servers at once.
