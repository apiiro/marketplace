---
name: guardian-scan
description: |
  Apiiro CLI commands for security scanning: fast local scans for secrets and OSS vulnerabilities (plus pre-commit hooks), and diff scans that compare two git references for security risks — the primary CI/CD integration point. Use this skill whenever the user mentions scanning code, secrets detection, OSS vulnerabilities, pre-commit hooks, comparing branches or commits for security issues, CI/CD security gates, or blocking PRs on risk. Even if the user doesn't say "apiiro", trigger when they say things like "scan for secrets", "check my code before I push", "are there any leaked credentials", "check dependencies for vulnerabilities", "scan this PR", "compare main to my branch for security", "block merges on critical risks", or want to set up local or CI security scanning.
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

Exit codes: 0 = clean, 1 = findings at or above the `--fail-on` threshold (default: any finding).

### Pre-commit Hook

```bash
apiiro hooks pre-commit install                   # Install (scans all types)
apiiro hooks pre-commit install --scan-type secrets --force
apiiro hooks pre-commit status
apiiro hooks pre-commit uninstall
```

Skip temporarily with `git commit --no-verify`.

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
