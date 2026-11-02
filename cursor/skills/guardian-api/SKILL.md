---
name: guardian-api
description: "Use when the user needs Apiiro data no dedicated command covers: org-wide or cross-repo Apiiro REST queries, filters the risks/inventory commands can't express, applications, diff scans by id. Repo-scoped risks: guardian-risks."
---

# Apiiro API

Send an authenticated request to any Apiiro REST API endpoint. The CLI adds the base URL and credentials; everything else passes through like `curl`. Endpoint reference: https://docs.apiiro.com/api

## Discovering endpoints

Start with `apiiro api list` before guessing a path. It reads the OpenAPI document the connected server publishes at `/rest-api/v1/openapi.json`, so it reflects that server's version, and shows each endpoint's method, path, summary, and the access-token permission it requires (`any token` when none).

```bash
apiiro api list                          # every published endpoint
apiiro api list risks                    # filter on path, summary, operation id, or tag
apiiro api list applications -o json     # machine-readable: data.endpoints[] with method, path, operationId, summary, tags, permission, queryParameters
apiiro api get /rest-api/v1/openapi.json # the full document, for parameters and schemas
```

If the server answers 404, it predates the discovery endpoint; fall back to https://docs.apiiro.com/api.

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

## When to use this instead of a dedicated command

- Cross-repository or org-wide data (`risks` and `inventory` are scoped to one repository or application).
- Filters the dedicated commands do not expose (dates, arbitrary `filters[...]` fields, sorting).
- Endpoints with no CLI command: applications, projects, servers, diff-scan lookups by id.
- Mutations (POST/PATCH/DELETE) — show the user the exact command, method, path, and body for them to run in their own terminal. Read paths (GET) need no confirmation.

Quote paths containing `[`, `]`, `?`, or `&` so the shell does not expand them. Do not guess endpoint paths or filter names; run `apiiro api list <term>` (or fetch `/rest-api/v1/openapi.json` for parameters), fall back to https://docs.apiiro.com/api, and say when a path is unverified.

## Global Options

`--api-url <url>`, `--timeout <seconds>`, `--no-color`.
