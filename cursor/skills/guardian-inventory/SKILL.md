---
name: guardian-inventory
description: "Use when the user asks what a repo contains: APIs, dependencies, sensitive data, secrets, technologies, modules, an SBOM, contributors, or marking a secret valid/invalid. Risks: guardian-risks; new local scan: guardian-scan."
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

`--type api|dependency|secret|sensitive-data|technology|module` is the short form of `--entity-type`; pass one, not both.

Pagination: `--page-size <1..1000>` (default 100), `--max-pages <count>` (default 5, `-1` for all). In JSON, `"truncated": true` means the list stopped at `--max-pages`: raise it before you say "this is everything".

## Other Reads

Inventory reads and `contributors <key>` print the API's JSON; the contributors list prints text unless `-o json`. Inventory modes reject flags they cannot use.

```bash
apiiro inventory <item-key>                       # One item
apiiro inventory --type module --repo my-repo     # Modules (no paging)
apiiro inventory --deleted --since 2026-10-01     # Deleted since a date (kept 30 days); takes --type, --application-id
apiiro inventory --secret <sha>                   # A secret's validity override (sha = secretDigest)
apiiro inventory sbom --repository-id <repo-id>   # SBOM; or --application-id; --format cyclonedx|spdx; -f to save
apiiro contributors                               # Contributors, 5 pages by default; -o json
apiiro contributors <key>                         # One contributor
apiiro contributors --export -f contributors.jsonl  # Every contributor as JSON Lines
```

The contributors list fails with "not enabled for this organization" when the contributors API is off. An older CLI ignores `<item-key>` and `sbom` and lists inventory instead; it prints `unknown option` for `--type`, `--deleted` and `--secret`, and `unknown command` for `contributors` and `secrets`. Then tell the user to update the CLI.

## Change a Secret's Validity

This writes to Apiiro. Run it only when the user asks. Your shell cannot answer the CLI's question: without a terminal it sends nothing and exits 130. So show the user the exact command, wait for their approval in chat, then run it with `--yes`. The change applies to every occurrence of the same secret value.

```bash
apiiro secrets update <sha> --validity invalid --reason "Rotated on 2026-10-01"
apiiro secrets update <sha> --validity valid
apiiro secrets update <sha> --validity auto       # Clear the override; the secret goes back to Apiiro's own result
```

`--reason` is at most 500 characters and does not apply to `auto`.

## Choosing the right command

- "What does this repo contain / expose / depend on" → `apiiro inventory`.
- "Who works on this code" → `apiiro contributors`.
- "What is risky / vulnerable / a finding" → `apiiro risks` (guardian-risks skill).
- "Scan my changes for secrets right now" → `apiiro fast-scan secrets` (guardian-scan skill).

## Global Options

`-o, --output <json|text>`, `--json`, `-f, --file <path>`, `--remote <name>`, `--repository-key <key>`, `--timeout <seconds>`, `--no-color`.
