---
name: guardian-risks
description: |
  Apiiro CLI commands for viewing and inspecting risks in a repository: list, filter, and get details on known risks. Use this skill whenever the user asks about security risks, vulnerabilities, or findings in their repository. Also trigger when they want to list, filter, or investigate risks by category or severity. Even without mentioning "apiiro", trigger when the user asks things like "what risks does this repo have", "any vulnerabilities here?", "show me the security findings", or "what's the risk level of this project". For fixing or remediating risks, use the guardian-fix skill instead.
---

# Apiiro Risks

View and inspect risks via the Apiiro CLI.

## List Risks

Repository is auto-detected from git when `--repo` is omitted.

```bash
apiiro risks                                      # List risks (auto-detect repo)
apiiro risks --repo my-repo-name                  # Specify repo (defaults to default branch)
apiiro risks --repo my-repo-name --branch master  # Pin a specific monitored branch
apiiro risks --repository-id <repo-id>            # Specify repo (branch) by ID
apiiro risks --risk-level Critical                # Filter by level
apiiro risks --risk-category "API Security"       # Filter by category
apiiro risks --risk-level High --finding-category "Secret Detection"
apiiro risks -o json --page-size 50               # JSON with pagination
```

Filters: `--risk-level`, `--risk-category`, `--risk-insight`, `--finding-category`, `--application-id`.

Scope: `--repo <name>` (resolves to the repository's default branch), `--branch <name>` (pin a specific monitored branch — repos with multiple monitored branches have one profile per branch, each with its own ID), `--repository-id <id>` (target a branch profile directly). Without any scope, the repository is auto-detected from the current git checkout (including its branch).

## Get Risk Details

```bash
apiiro risks get <risk-id>
apiiro risks get <risk-id> -o json
```

## Remediate / Fix

```bash
apiiro risks remediate <risk-id>   # curated remediation prompt only
apiiro risks fix <risk-id>         # curated, with automatic Guardian fallback (see guardian-fix skill)
```

For fixing risks, use the guardian-fix skill.

## Global Options

`-o, --output <json|text>`, `-f, --file <path>`, `--no-color`.
