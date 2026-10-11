---
name: guardian-risks
description: "Use when the user asks about known security risks, vulnerabilities, or findings in this repo (\"what risks does this repo have\"), or filters Apiiro risks by severity or category. Org-wide: guardian-query --global; fixing: guardian-fix."
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
