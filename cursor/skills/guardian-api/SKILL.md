---
name: guardian-api
description: |
  Apiiro CLI passthrough to any Apiiro REST API endpoint, with authentication handled by the CLI. Use this skill when the user needs Apiiro data or actions that no dedicated command covers: org-wide or cross-repository queries, filtering by date or fields the `risks` and `inventory` commands do not expose, applications, diff scans by id, or any endpoint from https://docs.apiiro.com/api. Trigger on "call the Apiiro API", "hit the REST endpoint", "query Apiiro for X across all repos", or when another guardian skill's command cannot express the filter the user asked for. For repo-scoped risks, inventory, scans, or Guardian questions, prefer the dedicated skills.
---

# Apiiro API

Send an authenticated request to any Apiiro REST API endpoint. The CLI adds the base URL and credentials; everything else passes through like `curl`. Endpoint reference: https://docs.apiiro.com/api

## Usage

```bash
apiiro api "/rest-api/v1/risks?filters[RiskLevel]=Critical"      # GET with filters
apiiro api /rest-api/v1/applications                              # GET
apiiro api /rest-api/v1/applications -d '{"name": "my-app"}'     # POST (inferred from --data)
apiiro api /rest-api/v1/applications/<key> -X PATCH -d @patch.json
cat body.json | apiiro api /rest-api/v1/diffScans -d @-           # body from stdin
apiiro api /rest-api/v1/risks -i                                  # include status + headers
apiiro api /rest-api/v1/risks -H "Accept: application/json"      # extra header (repeatable)
```

Options: `-X, --method <GET|POST|PUT|PATCH|DELETE>` (default GET, or POST when `--data` is given), `-d, --data <json|@file|@->`, `-H, --header "Name: value"` (repeatable), `-i, --include`, `--api-url <url>`, `--timeout <seconds>`.

Output: the response body goes to stdout, pretty-printed on a terminal and raw when piped, so it composes with `jq`. Exit code 0 for 2xx, 1 otherwise; on failure the error body is printed.

## When to use this instead of a dedicated command

- Cross-repository or org-wide data (`risks` and `inventory` are scoped to one repository or application).
- Filters the dedicated commands do not expose (dates, arbitrary `filters[...]` fields, sorting).
- Endpoints with no CLI command: applications, projects, servers, diff-scan lookups by id.
- Mutations (POST/PATCH/DELETE) — show the user the exact method, path, and body and get their confirmation before sending any non-GET request. Read paths (GET) need no confirmation.

Quote paths containing `[`, `]`, `?`, or `&` so the shell does not expand them. Do not guess endpoint paths or filter names; check https://docs.apiiro.com/api and say when a path is unverified.

## Global Options

`--api-url <url>`, `--timeout <seconds>`, `--no-color`.
