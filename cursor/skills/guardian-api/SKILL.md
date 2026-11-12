---
name: guardian-api
description: "Apiiro REST queries across repos or organizations, connectors, audit logs and exports. Policies, coverage, issues and reports have dedicated commands. Applications and application groups: guardian-inventory. Repo risks: guardian-risks."
---

# Apiiro API

Send an authenticated request to any Apiiro REST API endpoint. The CLI adds the base URL and credentials; everything else passes through like `curl`. Endpoint reference: https://docs.apiiro.com/api

## Explorer: read-only ApiiroQL queries

Use `apiiro explorer "<ApiiroQL>" --type <QueriedType>` for org-wide ApiiroQL queries. The server validates the query and type; examples of types are `RepositoryProfile`, `RiskTriggerSummary`, `ApiElement`, and `DependencyDeclaration`. This read-only command needs no confirmation.

It submits the query, polls until completion, and fetches rows. `--limit` caps matching rows processed (default 1000, maximum 100000). `--columns key1,key2` filters columns locally; empty keys are rejected before submission, and unknown keys list valid keys. `--page-size` defaults to 100 (maximum 1000); `--max-pages` defaults to 5, and `-1` fetches all pages within the query's limit. `--wait` caps the completion wait (default 300 seconds); a timeout includes the query ID.

Use `-o json` for `{queryId, columns, rows, truncated}`; the default text format prints one block per row. `truncated: true` means to raise `--max-pages` for more rows. `-f <path>` saves output. A concurrency error shows the retry delay when supplied; do not resubmit until that delay passes. Do not guess ApiiroQL syntax or column keys.

## Discovering endpoints

Start with `apiiro api list` before guessing a path. It reads the OpenAPI document the connected server publishes at `/rest-api/v1/openapi.json`, so it reflects that server's version, and shows each endpoint's method, path, summary, and the access-token permission it requires (`any token` when none).

```bash
apiiro api list                          # every published endpoint
apiiro api list risks                    # filter on path, summary, operation id, or tag
apiiro api list applications -o json     # machine-readable: data.endpoints[] with method, path, operationId, summary, tags, permission, queryParameters
apiiro api get /rest-api/v1/openapi.json # the full document, for parameters and schemas
```

If the server answers 404, it predates the discovery endpoint; fall back to https://docs.apiiro.com/api.

## Connectors, audit logs and export

Prefer these dedicated commands for connector management, audit logs and export:

```bash
apiiro connectors                                  # List, up to 5 pages
apiiro connectors <id>                             # Read one
apiiro connectors create --type github --url https://github.com/my-org --yes
apiiro connectors update <id> --token-expiration-date 2027-01-01 --yes
apiiro audit-logs --status Failure --since 2026-11-01 --until 2026-11-08 -o json
apiiro export                                      # List routes on this server
apiiro export repositories --file repositories.json
apiiro export repositories/<key>/apis
```

Before a connector write, show its type, URL or ID and expiration date, ask the user to approve the change in chat, then use `--yes`. Never ask for or place a token in a command argument or chat. The token must already be in `APIIRO_CONNECTOR_TOKEN`, or come from piped stdin with `--token-stdin --yes`. Stdin takes precedence and its trailing newline is removed. Missing tokens fail before any request. Tokens are excluded from prompts and output.

Create types: `github`, `gitlab`, `bitbucket`, `azureDevops`; `--url` is required. `--username` is required for `bitbucket` and `azureDevops`; `--description` and ISO `--token-expiration-date` are optional. Older servers may lack creation routes. Update changes only the token and optional expiration date. With `-o json`, update returns `{id, tokenUpdated: true}`.

Connector and audit-log lists support `--page-size` (1..1000), `--max-pages` (default 5, `-1` for all), `-o json` and `--file`. Text output shows one line per item; connector reads show the ID, provider, URL and token expiration. Audit-log lines show time, event type, status, user and event description. JSON lists include `{items, truncated}`; raise `--max-pages` when truncated. `audit-logs` exposes indexed filters only: `--event-type`, `--status Success|Failure`, `--user`, `--user-type User|Token|System`, paired `--since` and `--until` dates (`yyyy-MM-dd`, `yyyy-MM-ddTHH:mm:ssZ` or `yyyy-MM-ddTHH:mm:ss.fffZ`). Date-only `--until` covers the whole day.

For export, first list routes, then pass the part after `/rest-api/v1/export/`, replacing placeholders with real keys. Routes vary by server version. Put query parameters after `?` and quote the argument, for example `apiiro export 'applications/<key>/sbom?format=CycloneDx'`. Downloads preserve response bytes and stream to stdout or `--file`; a file is replaced after completion. The default download timeout is 10 minutes; explicit `--timeout <seconds>` overrides it. `-o json` applies to the routes list. These commands require **Full control** permission.

## Usage

```bash
apiiro api get "/rest-api/v1/risks?filters[RiskLevel]=Critical"  # GET with filters
apiiro api get /rest-api/v1/applications                          # GET
apiiro api get /rest-api/v1/risks -i                              # include status + headers
apiiro api get /rest-api/v1/risks -H "Accept: application/json"  # extra header (repeatable)
```

On `The path must start with "/" (got "get")` (older CLI), use `apiiro api <path>` for reads; for writes, ask the user to update the CLI.

For writes, show the user the exact command and ask them to run it in their own terminal:

```bash
APIIRO_ENABLE_API_CALL=1 apiiro api call /rest-api/v1/applications -d '{"name": "my-app"}'
APIIRO_ENABLE_API_CALL=1 apiiro api call /rest-api/v1/applications/<key> -X PATCH -d @patch.json
```

`apiiro api call` is off by default and requires the exact `<METHOD> <path>` to be typed in a terminal for every request. Do not run it yourself; show the user the exact command and ask them to run it in their own terminal. `-d @-` is unsupported; use inline JSON or `-d @file`.

Options: `api get` supports `-H, --header "Name: value"` (repeatable) and `-i, --include`. `api call` also supports `-X, --method <POST|PUT|PATCH|DELETE>` and `-d, --data <json|@file>` (default POST when `--data` is given). Both support `--api-url <url>` and `--timeout <seconds>`.

Output: the response body goes to stdout, pretty-printed on a terminal and raw when piped, so it composes with `jq`. Exit code 0 for 2xx, 1 otherwise; on failure the error body is printed.

## Policies, Coverage, Issues and Reports

Use these dedicated read commands before constructing a raw request. They need no confirmation. All support `-o json|text` (default text), `--json`, and `-f <file>`.

```bash
apiiro policies --repo my-repo -o json
apiiro coverage --repo my-repo --max-pages -1
apiiro coverage --projects
apiiro coverage --providers
apiiro issues --repo my-repo --page-size 100 --max-pages -1
apiiro issues --closed --issue-id ISSUE-123
apiiro reports list --search risk --type card --collection Security --limit 25
apiiro reports details --card 123
apiiro reports run --card 123 --param '{"id":"repository","value":["my-repo"]}'
apiiro reports run --card 123 --dashboard 10 --dashcard 20
apiiro reports compliance --framework soc2 --query repo_violations --repo my-repo --limit 20
```

- Policies, repository coverage and issues accept `--repo <name>` or `--repository-key <key>`, and read across the organization when omitted. Policies and coverage select the default monitored branch by name or a specific branch profile by key. Issues span all branches of the selected repository. They do not auto-detect the repository. Ambiguous names require a key.
- Policies return enabled policies as a raw JSON array, without trimming. Text lists name, type, risk level and enabled state. The server has no paging.
- Coverage defaults to repositories. `--projects` has no repository filter; passing one is an error. `--providers` returns all provider names and rejects repository and paging flags.
- Repository/project coverage and issues accept `--page-size <1..1000>` (default 100), `--max-pages <count>` (default 5, `-1` for all). JSON is `{items, truncated}`. Fetch more before claiming the list is complete. Empty project pages can precede later results.
- Issues default to open; `--closed` selects closed issues. `--issue-id` filters by ID. Repository filtering follows pull request links. Text shows ID, title, status, type and external URL. These are the only indexed filters exposed. Updated issues can be skipped during paging.
- Reports require Guardian enabled and use the caller's credentials. Data can be up to an hour stale. JSON is the raw tool result; text lists reports, details, result rows or compliance summary fields. They have no paging flags.
- Report `list` takes `--search`, `--type card|model|dashboard|all`, `--collection`, `--limit <1..100>` (server default 25). `details` requires exactly one of positive `--card` or `--dashboard` IDs. Use `details` to inspect parameter IDs and dashboard card IDs before running a report.
- Report `run` requires a positive `--card` ID; optionally pass both positive `--dashboard` and `--dashcard` IDs. Repeat `--param` with one JSON object each. It returns up to 100 rows, with `truncated` marking the cap.
- Report `compliance` accepts `--framework soc2|pcidss|nist800-53|iso27001` (Guardian requires it except for `cross_framework`), takes `--query control_summary|app_violations|cross_framework|repo_violations` (default `control_summary`), and `--limit <1..100>` (server default 20). Only `repo_violations` requires and accepts `--repo <name>`.
- An older CLI prints `unknown command` for these commands; ask the user to update it.

## Dedicated access-management commands

Use `apiiro roles [key]`, `apiiro role-groups [key]` and `apiiro users [id]` for reads. Lists accept `--page-size` (1..1000, default 100), `--max-pages` (default 5; -1 for all) and `-o json` (`{items, truncated}`). Detail reads print JSON. Users lists contain `{userId}`; details contain `{userId, groups:[{groupKey, userRole}]}`. Only users in role groups are included.

Roles and role groups have `create --data <json|@file>` and `delete <key>`. Creates return a key, or `{key}` with `-o json`. Role-group updates use `update <key> --data <json|@file>`: name is required; omitted or null description/adminIds/memberIds keep stored values, and [] clears lists.

Role updates use `update <key>` with repeatable `--permission Name=Read|Write`, `--assign-group type:groupKey`, `--unassign-group type:groupKey`; type is Idp, Apiiro or Scim. SCIM needs server support and must be enabled. Name, description and scope cannot change after create. Updates run permissions, assignments, then removals; failure stops remaining requests and reports what was applied.

Before create or update, show every change and get the user's approval in chat, then run with `--yes`. Deletes always need the exact key typed in a terminal; ask the user to run them. Deleting a role group also unassigns it from every role. Users have no write commands. Roles need the Roles permission, groups OrganizationalTeams, users Users; Read for reads, Write for writes. For role create and update, the token must also hold every permission and scope the role grants; a token can only grant what it holds.

## Dedicated findings and engagements commands

Use `apiiro findings` for manual-assessment findings (`--repository-id <id>`, `--application-id <id>`, `--risk-level <level>`), `apiiro findings upload <file>` for streamed JSON reports, and `apiiro engagements [key]` for engagements. The findings list rejects `--repository-key` and `--remote`. Both lists accept `--page-size` (1–1000) and `--max-pages` (default 5, `-1` for all); `-o json` returns `{items, truncated}`.

Engagement lists accept `--type Pentest|General`, `--status Active|Scheduled|InReview|Closed` and `--lead <key>`. Use `engagements create --data <json|@file>` and `engagements update <key> --data <json|@file>` for writes. Update replaces the whole object with PUT; read it first and keep every field the user wants preserved. Required fields are `name`, `type`, `startDate` and `status`.

Before upload, create or update, show the user the exact change and ask for confirmation in chat; after they agree, run the command with `--yes`. Upload confirmation includes the file path and size; uploads use ten minutes unless `--timeout <seconds>` is explicit and print server warnings.

For `apiiro findings delete --system <id> [--finding-id <id>...]` and `apiiro engagements delete <key>`, show the exact command for the user to run in their terminal. They must type the system id or key; there is no `--yes`. `findings delete` deletes findings sent through the legacy general-findings API for that system id. Without a finding id, it targets all legacy findings for that id. Findings sent by `findings upload` or listed by `findings` are stored separately. Success means the request was accepted; the server returns no deletion count, even for an unknown system id. Deleting an engagement also permanently deletes its findings and reports. Keep `findings triage` for SAST triage.

## When to use this instead of a dedicated command

- Cross-repository or org-wide data (`risks` and the `inventory` list are scoped to one repository or application).
- Filters the dedicated commands do not expose (dates, arbitrary `filters[...]` fields, sorting).
- Endpoints with no CLI command: projects and servers. Scan lookups by id use `apiiro scans <id> [--type diff|pr|build]`; pull requests use `apiiro pull-requests`.
- Mutations without a dedicated command (POST/PUT/PATCH/DELETE) — show the user the exact command, method, path, and body for them to run in their own terminal. Read paths (GET) need no confirmation.

Quote paths containing `[`, `]`, `?`, or `&` so the shell does not expand them. Do not guess endpoint paths or filter names; run `apiiro api list <term>` (or fetch `/rest-api/v1/openapi.json` for parameters), fall back to https://docs.apiiro.com/api, and say when a path is unverified.

## Global Options

`--api-url <url>`, `--timeout <seconds>`, `--no-color`.
