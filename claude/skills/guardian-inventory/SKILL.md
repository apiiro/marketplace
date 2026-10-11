---
name: guardian-inventory
description: "Use when the user asks what a repo contains rather than what is wrong: the APIs, dependencies, PII or sensitive data, secrets, and technologies Apiiro has mapped. Risks: guardian-risks; new local scan: guardian-scan."
---

# Apiiro Inventory

List inventory items via the Apiiro CLI. Inventory is what Apiiro has mapped in the code (APIs, dependencies, sensitive data, secrets, technologies), independent of whether any of it is risky.

## List Inventory

Repository is auto-detected from git when no scope flag is given.

```bash
apiiro inventory                                  # Auto-detect repo from git
apiiro inventory --repo my-repo-name              # Specify repo (defaults to its default branch)
apiiro inventory --repo my-repo-name --branch dev # Target a specific monitored branch
apiiro inventory --repository-id <repo-id>        # Target a branch profile directly
apiiro inventory --application-id <app-id>        # Scope to an application
apiiro inventory --entity-type API                # Only APIs
apiiro inventory --entity-type Dependency -o json # Only dependencies, as JSON
apiiro inventory --entity-type SensitiveData      # Sensitive data handling
apiiro inventory --entity-type Secret             # Secrets Apiiro has mapped
apiiro inventory --repo my-repo --max-pages -1    # Fetch every page (default cap: 5)
```

Entity types: `API`, `Dependency`, `SensitiveData`, `Secret`, `Technology`. The value is passed to the server as-is.

Pagination: `--page-size <1..1000>` (default 100), `--max-pages <count>` (default 5, `-1` for all). Large repos need `--max-pages -1` to see everything; say so when the result looks truncated.

## Choosing the right command

- "What does this repo contain / expose / depend on" → `apiiro inventory`.
- "What is risky / vulnerable / a finding" → `apiiro risks` (guardian-risks skill).
- "Scan my changes for secrets right now" → `apiiro fast-scan secrets` (guardian-scan skill).

## Global Options

`-o, --output <json|text>`, `--json`, `-f, --file <path>`, `--remote <name>`, `--repository-key <key>`, `--timeout <seconds>`, `--no-color`.
