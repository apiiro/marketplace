---
name: apiiro-fast-scan
description: |
  Apiiro CLI command for quick local security scanning: fast-scan for secrets and OSS vulnerabilities, plus pre-commit hooks. Use this skill whenever the user mentions scanning code locally, secrets detection, OSS vulnerabilities, pre-commit hooks, or wants to check files for security issues before committing. Even if the user doesn't say "apiiro", trigger when they say things like "scan for secrets", "check my code before I push", "are there any leaked credentials", "check dependencies for vulnerabilities", or want to set up local security scanning. For comparing git references in CI/CD, use apiiro-diff-scan instead.
---

# Apiiro Fast Scan

Quick local scan for secrets and OSS vulnerabilities via the Apiiro CLI. Requires a git repo with an `origin` remote. Auto-detects changed files when none specified.

## Commands

```bash
apiiro fast-scan secrets                          # Scan for secrets
apiiro fast-scan secrets src/config.ts            # Scan specific files
apiiro fast-scan secrets --staged                 # Staged files only (pre-commit)
apiiro fast-scan oss package.json bun.lock        # OSS vulnerabilities
apiiro fast-scan all                              # Both concurrently
apiiro fast-scan config                           # Get scan configuration
```

Options: `--staged`, `--full` (scan entire file, not just git-changed lines), `--timeout <ms>` (default: 2000), `--fail-on <severity>` (`any` (default), `none`, or `informational|low|medium|high|critical`), `-o, --output <json|text>`, `-f, --file <path>`.

Exit codes: 0 = clean, 1 = findings at or above the `--fail-on` threshold (default: any finding).

## Pre-commit Hook

```bash
apiiro hooks pre-commit install                   # Install (scans all types)
apiiro hooks pre-commit install --scan-type secrets --force
apiiro hooks pre-commit status
apiiro hooks pre-commit uninstall
```

Skip temporarily with `git commit --no-verify`.

## Global Options

`-o, --output <json|text>`, `-f, --file <path>`, `--no-color`.
