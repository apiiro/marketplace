---
name: guardian-risks
description: "Use when the user asks about known security risks or findings in this repo (\"what risks does this repo have\"), filters Apiiro risks, or wants to accept, ignore, re-level, tag or triage one. Org-wide: guardian-query --global; fixing: guardian-fix."
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
apiiro risks -o json --max-pages 20               # Fetch more pages (default 5)
```

Filters: `--risk-level`, `--risk-category`, `--risk-insight`, `--finding-category`, `--application-id`.

Scope: `--repo <name>` (resolves to the repository's default branch), `--branch <name>` (pin a specific monitored branch — repos with multiple monitored branches have one profile per branch, each with its own ID), `--repository-id <id>` (target a branch profile directly). Without any scope, the repository is auto-detected from the current git checkout (including its branch).

Lists stop after `--max-pages` pages (default 5). In JSON, `"truncated": true` means more risks exist: raise `--max-pages` or narrow the filters before you say "these are all the risks".

## Other Reads

Each accepts only the flags listed; others are rejected. `--trend` prints the API's JSON as is; `--stats-by` and `--design` print `{items, truncated}`. `--category` and `--lifecycle` lists keep every field under `risks` only in `-o json`. An older CLI rejects these flags and `--max-pages` with `error: unknown option '<flag>'`; tell the user to update the CLI.

```bash
apiiro risks --category secrets                   # A category's own route: oss, sast, secrets, api-security, dast, manualAssessments, artifacts (same filters; artifacts takes no repo)
apiiro risks --lifecycle                          # Lifecycle records: discovered, resolved, closed reason (same filters)
apiiro risks --stats-by repositories              # Counts per repositories, applications or applicationGroups (with --category)
apiiro risks --trend mttr                         # mttr, top-risks, sla-breach, risk-score (last 7 days; top-risks is current). --repository-id, --application-id, --risk-level; risk-score needs one of the first two and takes no --risk-level
apiiro risks --design                             # Design risks (--risk-level, --application-id)
```

## Get Risk Details

```bash
apiiro risks <risk-id>
apiiro risks <risk-id> -o json
apiiro risks <risk-id> --category dast            # The category's own detail route
apiiro risks <risk-id> --lifecycle                # The risk's lifecycle record
```

An older CLI ignores a bare `<risk-id>` and lists risks instead; there, use `apiiro risks get <risk-id>`.

## Remediate

```bash
apiiro risks <risk-id> --remediate                # curated remediation prompt
```

On `error: unknown option '--remediate'` (older CLI), use `apiiro risks remediate <risk-id>`. For fixing risks, use the guardian-fix skill.

## Change Risks and Triage Findings

These write to Apiiro. Run them only when the user asks for that change. Your shell cannot answer the CLI's question: without a terminal it sends nothing and exits 130. So show the user the exact command, wait for their approval in chat, then run it with `--yes`.

```bash
apiiro risks update <risk-id> --status Accepted --reason "Compensating control in place"
apiiro risks update <risk-id> --status Ignored --ignore-reason FalsePositive   # NotRelevant or FalsePositive; required for Ignored
apiiro risks update <risk-id> --level Low --reason "Internal-only service"
apiiro risks update <risk-id> --set dueDate=2026-12-31T00:00:00Z
apiiro risks update <risk-id> --set riskTags=Owner:Platform,Env:prod          # Replaces all tags; riskTags= clears them
apiiro findings triage <risk-id>                                              # AI triage of a SAST finding: TruePositive, FalsePositive or NeedsManualReview
apiiro findings triage <risk-id> --override FalsePositive --reason "Test fixture only"
```

Pass one of `--status`, `--level` or `--set` per call. `--reason` is at most 500 characters (2000 for `--override`). Exit 130 means the change was not confirmed and nothing was sent. On `error: unknown option` for `--status`, `--level` or `--set`, or `unknown command 'findings'` (older CLI), these commands are not available; tell the user to update the CLI.

## Global Options

`-o, --output <json|text>`, `-f, --file <path>`, `--no-color`.
