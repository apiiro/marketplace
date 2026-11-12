---
name: guardian-inventory
description: "Apiiro inventory: applications, application groups, teams, artifacts, APIs, dependencies, sensitive data, secrets, validity, technologies, modules, SBOMs, contributors, OSS, licenses, incidents, feed, advisories, repositories, SCM tags, monitoring."
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

## Artifacts

Artifact lists take `--page-size` 1–200, default 100.

```bash
apiiro artifacts
apiiro artifacts --type Sbom --application-id <app-id> --team-id <team-id>
apiiro artifacts <artifact-id>                   # Versions
apiiro artifacts <artifact-id> --risks           # Risks of one artifact
apiiro artifacts --container-images              # Container images from the v1 API
apiiro artifacts --import <import-id>            # Import status
apiiro artifacts import --file sbom.json --version 1.0 --name my-sbom --application-id <app-id> --yes
apiiro artifacts import --file sbom.json --version 2.0 --artifact <artifact-id> --yes
apiiro artifacts delete <artifact-id>
apiiro artifacts delete <artifact-id> --version <version-id>
apiiro artifacts delete <artifact-id> -o json     # id, version (null for whole artifact), deleted
```

`--risks` requires an artifact ID. `--container-images` selects the v1 container image list and accepts paging and output options only. Both return text rows by default, or `items` and `truncated` with `-o json`. Use `--page-size` (1–200) and `--max-pages` to control paging. SBOM imports stream files up to 512 MB.

Importing asks before sending; use `--yes` only after the user approves the exact command. `artifacts delete` is for SBOM artifacts only and permanently deletes versions, dependencies and findings. Like `api call`, always hand the delete command to the user to run in a terminal and type the artifact ID. Agents must never answer this prompt or bypass it.

Artifact commands accept `-o json` and `-f <output-path>` before or after the subcommand. Import uses `--file` for the SBOM input and `-f`/`--output-file` for saved output. With `--version`, delete removes only that version and names it in the confirmation prompt. Empty artifact IDs and versions fail before confirmation.

## OSS, Incidents, Feed and Custom Advisories

Use these for vulnerability or package content and organization-wide security incidents. They need "Full control" read permission, with write permission for advisory changes. Custom advisories require the CustomAdvisories feature enabled.

```bash
apiiro oss CVE-2021-44228
apiiro oss 'pkg:npm/lodash@4.17.20'
apiiro oss 'pkg:npm/lodash' --license              # IDs, source, source URLs
apiiro oss 'pkg:npm/lodash' --license --full       # Full license text (also in JSON)
apiiro incidents
apiiro incidents <id>
apiiro incidents <id> --scope --since 2026-10-01
apiiro feed --repo <key> --application <key> --team <key> --status Followed
apiiro feed --questions --type Announcement
apiiro advisories
apiiro advisories <id>
apiiro advisories update --input advisory.json
apiiro advisories delete <id>
```

All accept `-o json|text` and `-f <file>` for output. CVE input is uppercased; JSON merges CVE fields with `epss`. Package JSON is `{package, dependency}`. `--license` needs a package URL; `--full` needs `--license`.

Lists default to `--page-size 100 --max-pages 5`. Max page size: 100 for incidents/scope, 1000 for feed/advisories. `--max-pages -1` fetches all. A JSON list is `{items, truncated}`; check `truncated` before claiming completeness. Single incident/advisory reads reject paging. Incidents have no list filters. `--since` needs an incident ID and `--scope`.

Feed key flags scope counts and do not hide items. Status is `ForYou|Followed|Dismissed`; the server default `ForYou` includes followed items. `--questions` accepts status and `--type Manual|Seed|Announcement`, rejects paging and key flags, and returns a raw array in JSON. Text leaves out `insightPredicate` and `ruleTarget`.

Advisory update creates or replaces the whole advisory: omitted fields reset and affected packages are re-scored. The input must contain `advisoryId`; the server validates the other fields. Update accepts `--yes`. As with secret writes, show the exact update and get approval in chat before using `--yes`. Deletion requires the user to type the exact advisory ID in a terminal and has no `--yes`. Show the delete command for the user to run. Both writes send nothing without confirmation. `--input` reads the body; `-f` saves the output.

## Choosing the right command

- "What does this repo contain / expose / depend on" → `apiiro inventory`.
- "Who works on this code" → `apiiro contributors`.
- "List or import SBOM artifacts / check import status" → `apiiro artifacts`.
- "What is risky / vulnerable / a finding" → `apiiro risks` (guardian-risks skill).
- "Scan my changes for secrets right now" → `apiiro fast-scan secrets` (guardian-scan skill).

## Global Options

`-o, --output <json|text>`, `--json`, `-f, --file <path>`, `--remote <name>`, `--repository-key <key>`, `--timeout <seconds>`, `--no-color`.

Only run writes when the user asks. Show the exact create or update command, get approval in chat, then use `--yes`. Ask the user to run deletes in their terminal. `--set` always sends a string. Use repeatable `--set-json field=json` for JSON values; invalid JSON is rejected before sending.

## Applications and Application Groups

```bash
apiiro applications --page-size 100 --max-pages 5 -o json
apiiro applications <key>
apiiro applications create --data @application.json
apiiro applications update <key> --set name=Payments --set businessImpact=High --set-json isInternetFacing=true --add-tag team:payments --remove-tag old
apiiro applications delete <key>
apiiro application-groups --page-size 100 --max-pages 5 -o json
apiiro application-groups <key>
apiiro application-groups create --data '{"name":"Payments","tags":[],"applications":["app-key"],"pointsOfContact":[]}'
apiiro application-groups update <key> --data @group.json
apiiro application-groups delete <key>
```

Lists default to 100 items per page and 5 pages; `--max-pages -1` fetches all pages. JSON includes `items` and `truncated`; raise `--max-pages` when truncated. Create and update ask before sending; `--yes` skips that question. Deletes always require the exact key typed in a terminal. Application updates send one JSON Patch; a partial update reports failed fields and exits non-zero. Group updates replace the full body and require at least one application key.

## Teams

```bash
apiiro teams --page-size 100 --max-pages 5 -o json
apiiro teams <key>
apiiro teams create --data @team.json
apiiro teams update <key> --set name=Payments --set parentKey=parent-team --add-tag owner:payments --remove-tag old
apiiro teams delete <key>
```

Teams page, update and delete like applications. Text shows the key, name and parent key. Deleting a team clears the parent key of its child teams and removes the roles scoped to it.

## Repositories

```bash
apiiro repositories --page-size 100 --max-pages 5 -o json
apiiro repositories <key-or-name>
apiiro repositories https://github.com/org/repo
apiiro repositories --detect                 # Detect and verify the current repo
apiiro repositories --clear                  # Clear this repo's cached detection
apiiro repositories --clear --global         # Clear all cached detections
apiiro repositories update <scm-key> --monitor
apiiro repositories update <scm-key> --unmonitor
apiiro repositories update <scm-key> --monitor-branch main
apiiro repositories update <scm-key> --unmonitor-branch old
apiiro repositories update <scm-key> --add-tag team:payments
apiiro repositories update <scm-key> --remove-tag team
apiiro repos update <scm-key> --monitor     # repos is an alias of repositories
apiiro scm-repositories --page-size 100 --max-pages 5 -o json
apiiro scm-repositories <key-or-name>
apiiro scm-repositories --tag team:payments
apiiro scm-repositories <scm-key> -o json      # Only tags, as a JSON array
apiiro scm-repositories update <scm-key> --monitor
apiiro scm-repositories update <scm-key> --unmonitor
apiiro scm-repositories update <scm-key> --monitor-branch main
apiiro scm-repositories update <scm-key> --unmonitor-branch old
apiiro scm-repositories update <scm-key> --add-tag team:payments
apiiro scm-repositories update <scm-key> --remove-tag team
```

`repositories` lists monitored branch profiles. A URL (including `git@` URLs) filters by exact repository URL; other values try a key first, then an exact name after a 404. A key lookup prints the API's JSON object. `scm-repositories` lists SCM records; a value first tries an SCM key and prints its tags (a JSON array with `-o json`), then searches by name after a 404. A name matches part of the name, without case, and `--tag name:value` lists the records that carry that tag (split on the first `:`). A name or key lookup with no matches exits 1; an empty tag search prints `0 SCM repository(s)` and exits 0. A key that starts with `-` goes after `--`, for example `apiiro repositories -- -AbC123`.

Lists default to 100 items per page and 5 pages; `--max-pages -1` fetches all pages. JSON lists include `items` and `truncated`. `--tag` cannot be combined with a repository argument. `--detect` and `--clear` take no repository argument and no paging flags; `--global` requires `--clear`. Detection failures exit 2. `--detect -o json` returns `{ "success": true, "data": { "name": "...", "key": "...", "url": "...", "branch": "..." }, "metadata": { "timestamp": "..." } }`.

`repositories update` (also `repos update`) and `scm-repositories update` use the same SCM repository key, options and SCM routes. Updates take exactly one change per run and ask before sending; `--yes` skips the question. `--add-tag` uses the same `name:value` form as `--tag`. Updates print the response JSON, or a success message for an empty response.

Only run SCM updates when the user asks. Show the exact command, get approval in chat, then use `--yes`.
