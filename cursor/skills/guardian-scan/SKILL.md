---
name: guardian-scan
description: "Use to scan code with the Apiiro CLI for secrets, leaked credentials, or vulnerable OSS dependencies, set up pre-commit hooks, or diff-scan branches and PRs for CI gates (\"check my code before I push\", \"scan this PR\")."
---

# Apiiro Scan

Security scanning via the Apiiro CLI. Two modes:

- **Fast scan** — quick local scan for secrets and OSS vulnerabilities. Requires a git repo with an `origin` remote. Auto-detects changed files when none specified.
- **Diff scan** — compare two git references for security risks. Primary CI/CD integration point.

## Fast Scan

```bash
apiiro fast-scan secrets                          # Scan for secrets
apiiro fast-scan secrets src/config.ts            # Scan specific files
apiiro fast-scan secrets --staged                 # Staged files only (pre-commit)
apiiro fast-scan oss package.json bun.lock        # OSS vulnerabilities
apiiro fast-scan all                              # Both concurrently
apiiro fast-scan config                           # Get scan configuration
```

Options: `--staged`, `--full` (scan entire file, not just git-changed lines), `--timeout <seconds>` (default: 2, max: 5 — higher values are clamped with a warning), `--fail-on <severity>` (`any` (default), `none`, or `informational|low|medium|high|critical`), `-o, --output <json|text>`, `-f, --file <path>`.

Exit codes: 0 = clean, 1 = findings at or above the `--fail-on` threshold (default: any finding) or a block by the organization's prevention workflows. When the scan response carries a server verdict (the organization defines prevention workflows), that verdict decides instead of the default threshold: `Block` fails, `Warn`/`Success` do not. An explicitly passed `--fail-on <severity>` stays a floor under a `Success` verdict; `--fail-on none` always keeps exit 0.

### Git Hooks

```bash
apiiro hooks pre-commit install                   # Install pre-commit (scans all types), post-commit and post-rewrite
apiiro hooks pre-commit install --scan-type secrets --force
apiiro hooks pre-commit install --global          # Opt in to the global core.hooksPath directory instead
apiiro hooks pre-commit status
apiiro hooks pre-commit uninstall
```

The pre-commit hook scans staged files; skip it temporarily with `git commit --no-verify`. The post-commit and post-rewrite hooks link each new, amended, or rebased commit to the coding session that produced it and never block a commit. An existing hook is kept as `<hook>.pre-apiiro` and runs first; `--force` overwrites it instead.

## Diff Scan

```bash
apiiro diff-scan -b main -c feature-branch -r https://github.com/org/repo --wait
apiiro diff-scan -b main -c feature-branch -r https://github.com/org/repo --wait --wait-external
apiiro diff-scan -b abc123 -c def456 -r <repo-url> --baseline-type Commit --candidate-type Commit --wait
apiiro diff-scan -s <scan-id>                     # Check existing scan status
apiiro diff-scan -i                               # Interactive mode
```

Exit codes: 0 = success/warn, 1 = blocked/failed, 2 = scan still pending.

`--wait` polls until results land. `--timeout <seconds>` bounds the wait (default: 300). When the timeout elapses, exit code 2 is returned along with the scan ID so the user can re-check later with `-s <scan-id>`.

## Global Options

`-o, --output <json|text>`, `-f, --file <path>`, `--no-color`.
