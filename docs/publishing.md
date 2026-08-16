# Publishing guide

GitHub is the canonical source. The Hugging Face Space is a static, no-inference showcase that links back to GitHub.

## Candidate destinations

- GitHub: `https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe`
- Hugging Face: `https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe`

The URLs above are the publication targets for this release. Rerun `scripts/validate-release.ps1` immediately before publishing.

## GitHub

From the repository root, after reviewing the staged diff:

```powershell
git remote add origin https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe.git
git push -u origin main
```

Create the empty public repository through the GitHub UI or your authenticated GitHub CLI. Do not add another README, license, or `.gitignore` during remote creation.

## Hugging Face static Space

Create a public Space named `Qwen3.8-27B-RTX5090-128K-Recipe` with the Static SDK. Upload the contents of `hf-space/` as the Space repository root. No GPU hardware or hosted inference is required.

If using the authenticated Hugging Face CLI, inspect the installed CLI's current help before running its repository-create or upload commands; command flags can change between client versions.

## Release gate

Do not publish when any of these are true:

- the secret/privacy scan fails;
- a model-weight extension appears in Git history;
- example JSON or script syntax fails;
- placeholders do not match the selected public owner and final URLs;
- attribution links or licenses have not been rechecked;
- the diff contains local evidence, logs, session identifiers, or private paths.

X posting is manual only. The draft is in `social/x-thread-ko.md`.
