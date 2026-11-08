# Apiiro Guardian CLI

Command-line interface for the [Apiiro](https://apiiro.com) Guardian Agent — discover inventory, assess risk, detect vulnerabilities, fix risk, and prevent risk.

## Installation

### One-line install (macOS / Linux / Windows)

The recommended install path. Downloads the right binary for your platform, verifies its checksum, installs it to a user directory (no sudo), and configures PATH.

```bash
# macOS / Linux
curl -fsSL https://apiiro.com/install.sh | bash
```

```powershell
# Windows (PowerShell)
irm https://apiiro.com/install.ps1 | iex
```

Then run `apiiro login` and `apiiro init` to wire skills + prevention hooks into your coding agents.

Environment overrides: `APIIRO_INSTALL_DIR`, `APIIRO_VERSION` (the version to install), `APIIRO_NO_MODIFY_PATH`.

Every install method updates itself to the version your organization selects in Apiiro; see [Update](#update).

### npm (macOS / Linux / Windows)

Requires Node.js 18+. No Bun needed — the right prebuilt binary is installed automatically for your platform.

```bash
npm i -g apiiro-cli    # installs the `apiiro` command
apiiro --help
```

Or run without installing:

```bash
npx apiiro-cli --help
```

### Other install methods

<details>
<summary>Homebrew, direct download, RPM</summary>

**Homebrew (macOS / Linux)**

```bash
brew tap apiiro/tap
brew trust apiiro/tap    # required on Homebrew 6.0+
brew install apiiro
```

> Homebrew 6.0+ refuses formulae from untrusted third-party taps, so the one-time `brew trust` step is
> required. Trust the **tap**, not the individual formula — trusting only `apiiro/tap/apiiro` leaves
> Homebrew erroring on the tap's other formula (`apiiro-latest`) in later commands.

**Direct Download**

Pre-compiled binaries for all platforms are available on the [releases page](https://github.com/apiiro/marketplace/releases):

| Platform | Binary |
|----------|--------|
| macOS Apple Silicon (M1/M2/M3/M4) | `apiiro-macos-arm64` |
| macOS Intel | `apiiro-macos-x64` |
| Linux x64 | `apiiro-linux-x64` |
| Linux ARM64 | `apiiro-linux-arm64` |
| Windows x64 | `apiiro-win.exe` |

```bash
# macOS / Linux: download, make executable, and move to PATH
chmod +x apiiro-*
sudo mv apiiro-* /usr/local/bin/apiiro
```

On Windows, move `apiiro-win.exe` to a directory on your `PATH` (optionally rename to `apiiro.exe`).

**RPM (Linux)**

```bash
sudo yum install -y https://github.com/apiiro/marketplace/releases/latest/download/apiiro-<version>-1.x86_64.rpm
```

</details>

### Organization-wide deployment (macOS/MDM)

Jamf deployments use the [versioned policy script](jamf/README.md), with no package to build or upload. The policy downloads a pinned public CLI release, verifies its checksum, and installs one root-owned binary at `/opt/apiiro/bin/apiiro` before configuring the logged-in user's skills and hooks. Jamf only installs the CLI: after that, the CLI follows the version your organization selects in Apiiro. To let Jamf manage the version instead, set the Apiiro CLI version setting to **Off**.

The default profile enables Secure Prompt for Claude Code and leaves scanning disabled. Set Parameter 6 to the approved release version; use Parameter 7=`all` when ready to enable the other public prevention capabilities. Parameter 8 defaults to `published`; use `pkg` to configure an approved package build without downloading or replacing its binary. Keep opted-out computers excluded from the policy scope. Read the [Jamf guide](jamf/README.md) for triggers, authentication, and verification.

### pre-commit

Add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/apiiro/marketplace
    rev: <VERSION>  # get latest from https://github.com/apiiro/marketplace/releases
    hooks:
      - id: apiiro-fast-scan     # secrets + OSS
      # - id: apiiro-secrets-scan  # secrets only
      # - id: apiiro-oss-scan      # OSS only
```

> Windows: pre-commit hooks are POSIX shell scripts; run them via Git Bash (bundled with [Git for Windows](https://git-scm.com/download/win)) or WSL.

### AI coding agent setup

The recommended setup detects Claude Code, Cursor, GitHub Copilot CLI, OpenAI Codex, and opencode, installs their skills and prevention hooks, then verifies the result:

```bash
apiiro init
apiiro doctor
```

Common options:

```bash
apiiro init --claude          # Claude only; --cursor, --copilot, --codex, and --opencode are also available
apiiro init --skills-only     # Skip prevention hooks
apiiro init --dry-run         # Preview file changes
apiiro init --non-interactive # Unattended / MDM setup
apiiro uninstall              # Remove skills and hooks
apiiro uninstall --remove-binary
```

Restart Claude Code and opencode after setup. For skills without prevention hooks, use `apiiro agents install`. Without the CLI, install them with [Vercel Skills](https://github.com/vercel-labs/skills):

```bash
npx skills add apiiro/marketplace
```

Marketplace plugins are also available for interactive installs. Each host offers
an `apiiro` skills plugin and an opt-in `apiiro-prevention` hooks plugin:

```bash
# OpenAI Codex
codex plugin marketplace add apiiro/marketplace
codex plugin add apiiro@apiiro
codex plugin add apiiro-prevention@apiiro

# GitHub Copilot CLI
copilot plugin marketplace add apiiro/marketplace
copilot plugin install apiiro@apiiro
copilot plugin install apiiro-prevention@apiiro
```

Claude Code and Cursor expose the same two plugin names through their plugin
browsers. Choose either the prevention plugin or `apiiro init`/`apiiro hooks
<agent> install` for a host, not both, because hosts combine hook sources. Fleet
and Jamf deployments should continue using `apiiro init --non-interactive`.

Available skills: `guardian-risks`, `guardian-fix`, `guardian-inventory`, `guardian-api`, `guardian-query`, `guardian-threat-model`, `guardian-scan`, `guardian-secure-prompt`, `guardian-setup`.

## Authentication

```bash
# Login via OAuth (opens browser)
apiiro login

# Login by entering a short code in any browser — when the usual browser
# sign-in cannot complete on this machine
apiiro login --device

# Check status
apiiro auth status

# Logout
apiiro logout
```

Alternatively, set the `APIIRO_API_KEY` environment variable.

## Commands

### Fast Scan

Quick local scanning for secrets and OSS vulnerabilities. Requires a git repository with an `origin` remote. The CLI checks repository eligibility before uploading file contents; unmonitored repositories are skipped unless Apiiro has enabled scanning them for your environment. Skipped scans are not reported as clean. Auto-detects changed files in the current git repo. Agent skill: `guardian-scan`.

```bash
apiiro fast-scan secrets            # Scan for secrets
apiiro fast-scan secrets --staged   # Scan staged files only (pre-commit)
apiiro fast-scan secrets --full     # Scan entire file, not just git-changed lines
apiiro fast-scan oss                # Scan for OSS vulnerabilities
apiiro fast-scan all                # Run both concurrently
apiiro fast-scan config             # Get scan configuration
apiiro fast-scan secrets --timeout 5      # Scan budget in seconds (default 2, max 5)
apiiro fast-scan all --commit <sha> --base-commit <ref>   # Attribute the scan to a commit / diff against a baseline ref (both default: HEAD)
```

Exit codes: 0 = clean, or a scan that could not run; 1 = findings at or above the `--fail-on` threshold (default: any finding), a block by your organization's prevention workflows, or a usage error (a file that does not exist, a `--commit` or `--base-commit` that is not a commit, an output file that cannot be written, or running outside a git repository). A scan that cannot run never fails the command: when you are not signed in, the repository is not monitored or is outside your Apiiro user scope, your role lacks the Fast scan permission, Fast Scan is not enabled, the scan times out, or a scanner errors, the CLI prints the reason as a warning and exits 0, so a pre-commit hook built on it lets the commit through.

When your organization defines prevention (FastScan) workflows, the scan response carries a server verdict and that verdict decides the exit code instead of the default `--fail-on` threshold — `Block` fails the run, `Warn` and `Success` do not, even when High/Critical findings are present. An explicitly passed `--fail-on <severity>` stays a floor (findings at or above it still fail the run under a `Success` verdict), and `--fail-on none` always keeps exit 0 (report-only). Without a verdict the `--fail-on` behavior is unchanged.

### Diff Scan

Compare two git references for security risks. Primary CI/CD integration point. Agent skill: `guardian-scan`.

```bash
# Trigger and wait for results
apiiro diff-scan -b main -c feature-branch -r https://github.com/org/repo --wait

# Use commit SHAs
apiiro diff-scan -b abc123 -c def456 -r https://github.com/org/repo \
  --baseline-type Commit --candidate-type Commit --wait

# Check status of an existing scan
apiiro diff-scan -s <scan-id>

# Interactive mode
apiiro diff-scan -i
```

Exit codes: 0 = `Success` or `Warn`, 1 = `Block` or an error (including a `--wait` timeout), 2 = not signed in, or the scan checked with `-s` is still running. A blocked scan exits 1 whether you wait for it with `--wait` or check it later with `-s <scan-id>`.

### Risks

List, inspect and change risks. Agent skills: `guardian-risks` (list/inspect/change), `guardian-fix` (remediate).

```bash
apiiro risks                                     # List risks (auto-detects repo)
apiiro risks --repo my-repo-name                 # Specify repo (defaults to its default branch)
apiiro risks --repo my-repo-name --branch dev    # Target a specific monitored branch
apiiro risks --repository-id <repo-id>           # Specify repo (branch) by ID
apiiro risks --risk-level Critical               # Filter by risk level
apiiro risks --risk-category "API Security"      # Filter by category
apiiro risks --max-pages 20                      # Fetch more pages (default cap: 5)
apiiro risks --category secrets                  # Read a category's own route, with its extra fields
apiiro risks --lifecycle                         # Lifecycle records: discovered, resolved, closed reason
apiiro risks --stats-by repositories             # Risk counts per repository, application or applicationGroups
apiiro risks --trend mttr                        # mttr, top-risks, sla-breach, risk-score (last 7 days; top-risks is current)
apiiro risks --design                            # Design risks from design reviews
apiiro risks <risk-id>                           # Risk details (add --category or --lifecycle for those routes)
apiiro risks <risk-id> --remediate               # Remediation prompt
apiiro risks fix <risk-id>                       # Curated remediation when available, Guardian fallback otherwise
```

Each monitored branch is its own profile with its own ID; use `--branch` or `--repository-id` to pin one. Lists stop after `--max-pages` pages; JSON output then has `"truncated": true`. `--trend` and `<risk-id>` with `--category` or `--lifecycle` print the API's JSON as is; `--stats-by` and `--design` print `{items, truncated}`. Lists with `--category` or `--lifecycle` keep every field under `risks` in `-o json`; text output shows the common columns. `--trend risk-score` needs exactly one of `--repository-id` or `--application-id`. The old `apiiro risks get` and `risks remediate` still work but are deprecated.

Change risks and triage findings:

```bash
apiiro risks update <risk-id> --status Accepted --reason "Compensating control in place"
apiiro risks update <risk-id> --status Ignored --ignore-reason FalsePositive
apiiro risks update <risk-id> --level Low --reason "Internal-only service"
apiiro risks update <risk-id> --set dueDate=2026-12-31T00:00:00Z
apiiro risks update <risk-id> --set riskTags=Owner:Platform,Env:prod   # Replaces all tags; riskTags= clears them
apiiro findings triage <risk-id>                                       # AI triage of a SAST finding
apiiro findings triage <risk-id> --override FalsePositive --reason "Test fixture only"
```

Each write shows the change and asks before it sends. `--yes` sends without asking; without a terminal and without `--yes`, nothing is sent (exit 130). API keys need the "Change risk status" permission for `--status`, "Override risk level" for `--level`, the "Risks" permission group with write access for `--set`, and "Full control" for `findings triage`. Reading `<risk-id>` or `--design` also needs "Full control".

### Inventory

List inventory items (APIs, dependencies, sensitive data, secrets) for a repository or application. The list needs a scope (auto-detected from git, or one of the explicit flags).

```bash
apiiro inventory                                 # Auto-detect repo from git
apiiro inventory --repo my-repo-name             # Specify repo (defaults to its default branch)
apiiro inventory --repo my-repo-name --branch dev # Target a specific monitored branch
apiiro inventory --application-id <app-id>       # Scope to an application
apiiro inventory --entity-type API               # Filter: API, Dependency, Secret, SensitiveData, ...
apiiro inventory --repo my-repo -o json          # JSON output
apiiro inventory --repo my-repo --max-pages -1   # Fetch every page (default cap: 5)
apiiro inventory --type secret                   # api, dependency, secret, sensitive-data, technology, module
apiiro inventory <item-key>                      # One item
apiiro inventory --deleted --since 2026-10-01    # Items deleted since a date (kept for 30 days)
apiiro inventory --secret <sha>                  # A secret's validity override
apiiro inventory sbom --repository-id <repo-id>  # SBOM; or --application-id, --format cyclonedx|spdx
apiiro secrets update <sha> --validity invalid --reason "Rotated"   # valid, invalid, or auto to clear the override
apiiro contributors                              # Contributors (5 pages by default); <key> for one
apiiro contributors --export -f contributors.jsonl                  # Every contributor as JSON Lines
```

`inventory <item-key>`, `--type module`, `--deleted`, `--secret`, `inventory sbom` and `contributors <key>` print the API's JSON. In JSON, `"truncated": true` means the list stopped at `--max-pages`; raise it to fetch more. `secrets update` asks before it sends, like `risks update`, and changes every occurrence of the same secret value. `apiiro contributors` needs the contributors API enabled for your organization. API keys need "Inventory management" for inventory lists, `--deleted`, `--secret` and SBOMs, with write access for `secrets update`, and "Full control" for `inventory <item-key>`, `--type module` and `contributors`.

### Raw API Access

Send an authenticated request to any Apiiro REST API endpoint. `apiiro api list` shows which endpoints exist, read from the OpenAPI document your server publishes at `/rest-api/v1/openapi.json`. Use `apiiro api get <path>` for reads and `apiiro api call <path>` for writes. Endpoint reference: https://docs.apiiro.com/api

```bash
apiiro api list                                                 # every published endpoint: method, path, summary, required permission
apiiro api list risks                                           # filter by path, summary, operation id, or tag
apiiro api list applications -o json                            # machine-readable
apiiro api get /rest-api/v1/openapi.json                        # the full OpenAPI document (parameters, schemas)
apiiro api get "/rest-api/v1/risks?filters[RiskLevel]=Critical" # GET with filters
apiiro api call /rest-api/v1/applications -d '{"name": "my-app"}' # POST (inferred from --data)
apiiro api call /rest-api/v1/applications/<key> -X PATCH -d @patch.json
apiiro api get /rest-api/v1/risks -i                           # include response status + headers
```

Writes are off until you set `APIIRO_ENABLE_API_CALL=1`. Each write asks a person to type the exact `<METHOD> <path>` in a terminal; no flag skips this step. `-d @-` is unsupported because stdin is needed for confirmation; use inline JSON or `-d @file`. Transient retries are GET-only.

The response body goes to stdout (raw when piped, so it composes with `jq`); exit code is 0 for 2xx and 1 otherwise. The old `apiiro api <path>` form still works but is deprecated.

### Threat Model

Perform STRIDE-based threat analysis on feature specs, requirements, or architectural changes. Agent skill: `guardian-threat-model`.

```bash
apiiro threat-model "Add REST API for file uploads to S3"
apiiro threat-model "Implement OAuth2 with PKCE" --title "Auth redesign"
apiiro threat-model "Add webhook support" -o json
apiiro threat-model "Migrate sessions to JWT" -f threat-report.md
```

### Ask

Query Apiiro's AI agent for security analysis and insights. Agent skill: `guardian-query`.

```bash
apiiro ask "what risks exist in this repo"
apiiro ask "deep analysis of auth flow" --model normal
apiiro ask "what is STRIDE?" --global
apiiro ask "detailed analysis" --timeout 120
apiiro ask "what risks exist here" --remote gh   # detect via a non-origin remote
```

### Secure Prompt

Enhance a coding task with security considerations. Requires a repository monitored by Apiiro: run it inside one (detected from the git remote) or pass `--repository-key <key>`. Use `--file <path>` to save the result, `--force` to bypass the classifier gate, or `-o json` for JSON output.

```bash
apiiro secure-prompt "Add a file upload endpoint"
```

The old `apiiro guardian query` and `apiiro guardian secure-prompt` names still work but are deprecated.

### Guardian Repository

```bash
apiiro guardian repository detect    # Detect and verify repo in Apiiro
apiiro guardian repository clear     # Clear cached repo info
```

### Hooks

A git pre-commit scanning hook and lifecycle hooks for Claude Code, Cursor, GitHub Copilot CLI, OpenAI Codex, and opencode. The agent hooks authenticate at session start and add security context where each host protocol permits it.

Claude Code waits for startup sign-in before submitting the first prompt. If
authentication is missing in an existing session, Secure Prompt starts sign-in
and continues the same prompt after authentication succeeds. Concurrent sessions
share one browser sign-in, with a four-minute login budget. If sign-in fails or
times out, the prompt is sent without security enrichment and the hook shows a
notice to run `apiiro login`. Explicitly disabling all hook features also
disables startup sign-in.

```bash
apiiro hooks pre-commit install     # Install the pre-commit hook
apiiro hooks pre-commit status      # Check the hook
apiiro hooks pre-commit uninstall   # Remove the hook, restoring any it ran in front of
apiiro hooks pre-commit install --global   # Install into the global core.hooksPath instead (opt-in)

apiiro hooks claude install            # Enable the apiiro-prevention plugin (CLI equivalent of /plugin install)
apiiro hooks claude status             # Check status
apiiro hooks claude uninstall          # Disable the plugin
apiiro hooks claude install --system   # Target Claude Code managed settings (admin/MDM scope)

apiiro hooks cursor install         # Install the Cursor session and commit-scan hooks
apiiro hooks cursor status          # Check hook status and integrity
apiiro hooks cursor uninstall       # Remove the hook

apiiro hooks codex install          # Install the Codex session, prompt, and pre-tool hooks (then trust each entry once, see below)
apiiro hooks codex status           # Check which hooks are installed
apiiro hooks codex uninstall        # Remove the hooks

apiiro hooks copilot install        # Install the Copilot CLI user hook file
apiiro hooks copilot status         # Check which hooks are installed
apiiro hooks copilot uninstall      # Remove the hook

apiiro hooks opencode install       # Install the opencode plugin (session context, prompt enrichment, commit scan)
apiiro hooks opencode status        # Check whether the plugin is installed and current
apiiro hooks opencode uninstall     # Remove the plugin

apiiro hooks update                 # Refresh locally-installed hook artifacts once out of date
apiiro hooks update --dry-run       # Preview without making changes
```

`apiiro hooks pre-commit install` writes a `pre-commit` hook into the repository's `.git/hooks` that scans staged files. A hook that already exists (Husky, Lefthook, your own script) is kept: it is renamed to `pre-commit.pre-apiiro`, runs first with the same arguments and input, and is restored by `uninstall`; pass `--force` to overwrite it instead. The pre-commit hook refuses a commit only when your organization's prevention workflows block it or a finding meets the `--fail-on` threshold; when the scan cannot run it prints why and lets the commit through. When the Apiiro coding-agent hook has already checked the same staged files for the same commit and reached a decision the git hook would repeat, the git hook skips its own scan, so a commit is scanned once, and repeats the reason when that decision was "the scan could not run here" (for example a repository outside your user scope); a warning-level verdict, any finding, a partial scan, another remote, branch or API URL, or a run with `--repository-key` is scanned again. A file that was staged and then deleted from the working tree is scanned from the index, because that is what the commit contains. `install`, `uninstall` and `apiiro hooks update` also remove the `post-commit` and `post-rewrite` hooks that earlier versions installed, restoring any hook they ran in front of. In a global `core.hooksPath` directory, `install` and `update` leave a small pass-through in their place that sends nothing, so your repositories' own `post-commit` and `post-rewrite` hooks keep running; `uninstall --global` removes it, unless other hooks in `~/.apiiro/git-hooks` keep `core.hooksPath` in use. `--global` installs into the directory your global `core.hooksPath` points to (creating `~/.apiiro/git-hooks` and setting `core.hooksPath` when none is configured) and is never used unless you ask for it.

With server support for session context, Claude Code and opencode prevention hooks also send bounded repo-relative file paths and sanitized ticket/link references so follow-up prompts retain the task context. A link reference keeps only its scheme and host, so paths, query strings, and credentials never leave your machine, and these hooks send no edit contents, diffs, or tool response bodies and never block an edit. Secret-pattern redaction and length bounds apply to the prompt text that prompt enrichment sends; session records expire after 24 hours without use. `apiiro hooks config disable disableEnrichSession` turns these context hooks off together with the session-start context.

`apiiro hooks config enable preventLog` keeps each prompt that Secure Prompt enriches on your machine in `~/.apiiro/prevent-log/<session-id>.jsonl` (readable only by you): the time, session id, working directory, the first 200 characters of the prompt, and the security context added to it, with common secrets (bearer tokens, cloud and Git provider tokens, private keys, and `api_key=` or `password=`-style values) redacted. The log is off by default. Any plugin or process running as you can read it, so on machines where Claude Code's managed settings keep prompt content and hook output away from other plugins, enabling it gives up that isolation. Nothing in this log is sent anywhere. While the log is enabled, each prompt deletes session logs that have not been written to for seven days. Disabling it (`apiiro hooks config disable preventLog`, or `disable all`) stops that cleanup, so delete `~/.apiiro/prevent-log` yourself to clear what remains.

The Claude Code prevention hooks also report each commit a Claude Code shell command makes, so Apiiro can attribute the commit to the session that produced it. The report runs in the background after the command, never blocks or changes it, and gives up silently after three seconds, without credentials, outside a monitored repository, or when the feature is not enabled for your organization. Commits made outside Claude Code shell commands (a terminal, an IDE, a rebase) are not reported.

These context hooks run in the background (Claude Code does not wait on them before continuing), each capped at a few seconds so a slow network never leaves a process behind. In a headless `claude -p` run, Claude Code can end the session before a background hook finishes, so a fragment from the run's final tool call may not be recorded.

Restart Claude Code after installing or uninstalling its plugin for the change to take effect. Copilot CLI does not support per-prompt output from config-file hooks, and Cursor's prompt hook cannot inject context at all, so on both hosts Apiiro adds its context at session start and scans at commit time. opencode has no hook configuration file, so `apiiro hooks opencode install` writes an Apiiro plugin to `~/.config/opencode/plugins/apiiro.js` (under `$XDG_CONFIG_HOME` when set) that runs the same session, prompt, commit-scan, and session-context hooks; restart opencode to load it. The `apiiro hooks <agent> install` commands are the non-interactive Jamf fallback; the Codex and Copilot marketplaces package the same lifecycle definitions for interactive installation.

Codex runs a hook only after you trust it once: run `codex` in a terminal, type `/hooks`, and trust each Apiiro entry (one per hook). Until then Codex skips the hook silently — the desktop app does not prompt — and editing a hook requires trusting that entry again. `apiiro hooks update` (also run by `apiiro update`) repairs existing Cursor, Codex, Copilot CLI, opencode, and direct Claude Code user installs whose entries are missing or outdated, including hooks that still point at a removed Homebrew version (a machine-wide managed install is left to your administrator); review the changed Codex entries in `/hooks` afterwards.

When your organization defines prevention workflows, the commit scan carries a server verdict and each host renders it through its own hook protocol. A `Block` verdict stops the commit on every host, with the matched workflows and the findings behind them. Each finding carries the fix data the scan returns for it — the upgrade version and advisory IDs for a vulnerable dependency, the remediation for a malicious package, the secret type — so the coding agent can fix it and commit again for a fresh scan. `fast-scan` prints the same lines under each new finding. A `Warn` verdict lets the commit through, and whether you see the warning depends on the host:

| Host | `Warn` verdict |
|------|----------------|
| Claude Code | Commit proceeds, warning shown |
| OpenAI Codex | Commit proceeds, warning shown |
| opencode | Commit proceeds, warning shown as a TUI toast |
| Cursor | Commit proceeds, **no message shown** |
| GitHub Copilot CLI | Commit proceeds, **no message shown** |

Cursor's `preToolUse` protocol attaches messages only to a denied action, and the published GitHub Copilot CLI `preToolUse` contract defines no field for surfacing a warning to you on an allowed call either, so on both hosts a hook cannot let a commit through and still warn you about it. Blocking works the same there as everywhere else. What is lost is every message the hook would attach to a commit it allows — the warning above, and the notice that a scan finished only partially. Until those protocols carry a user-visible message on an allowed action, run `apiiro fast-scan all --staged` on Cursor and Copilot CLI to see warning-level prevention results.

Two optional files tune the hooks:

- `~/.apiiro/hooks-config.json` — `{"<hook-key>": true}` disables that hook; unset means enabled. `{"enablePreventLog": true}` turns on the local prompt log. Manage with `apiiro hooks config`.
- `./.apiiro/scan-ignore.json` — `{"ignore": [{"rule": "<rule-id>", "file": "<path | dir/** | *.ext>"}], "ignorePatterns": ["<glob>"]}` suppresses findings by rule and/or file, or any matched value.

### Doctor

Unified health check for your Apiiro setup — CLI version, auth state, per-agent skills, Claude Code plugin status, Cursor hook integrity, Copilot/Codex hook configuration, opencode plugin, pre-commit hook, and hook toggles. Works without authentication.

```bash
apiiro doctor           # Human-readable report
apiiro doctor --json    # Machine-readable
```

### Update

The CLI keeps itself on the version your organization selects in Apiiro: the latest stable release (the default), a locked version, or Off when your device management controls the version. Every install method works the same way, including Homebrew, npm, RPM and Jamf: the installed file never changes. The CLI downloads the exact release from the [public releases](https://github.com/apiiro/marketplace/releases), checks its SHA-256 checksum and runs it once to verify it, keeps it in your account's own folder (`~/.apiiro/versions`, or `%LOCALAPPDATA%\Apiiro\versions` on Windows), and from then on runs that version.

When a different version is required, a command waits while the CLI downloads it (up to 10 minutes in a terminal, 2 minutes in an agent session-start hook, 90 seconds for other runs), then runs on the new version. Short hooks, such as commit scans, never wait: they switch at once when the new version is ready. If an update cannot finish, the CLI keeps working on its current version and tries again later. CI runs keep the version they install unless you set `APIIRO_AUTO_UPDATE=on`. When your organization has no version setting, the CLI only shows a notice once a day when a newer stable release exists.

```bash
apiiro update            # Update now to your organization's version (or the latest stable release)
apiiro update --check    # Only check; don't install
apiiro update --disable  # Turn off automatic updates for your account on this machine
apiiro update --enable   # Turn them back on
```

An update also refreshes the installed hook files once. Turning automatic updates off on one machine is also possible with `APIIRO_AUTO_UPDATE=off`. On Windows, an elevated terminal ("Run as administrator") never updates the CLI: it runs the installed version, and `apiiro update` there changes nothing.

## Global Options

Most commands support:
- `-o, --output <format>` — `text` (default) or `json`
- `-f, --file <path>` — Save output to file
- `--api-url <url>` — Override API endpoint
- `--no-color` — Disable colored output
- `--no-merge-system-ca` — Skip the automatic TLS retry that merges OS CA certificates; use if you hit `certificate has expired` errors. Works before or after the subcommand.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_EXTRA_CA_CERTS` | PEM file appended to the CA bundle on the TLS retry. | — |
| `APIIRO_CA_EXPORT_TIMEOUT_MS` | Timeout (ms) for exporting OS CA certificates (max 20 min). | `180000` |
| `APIIRO_CA_EXPORT_MAX_BUFFER_BYTES` | Max bytes read when exporting OS CA certificates. | `104857600` |
| `APIIRO_FORCE_SECURITY_EXPORT` | macOS: set to `1` to force keychain export via `security` for OS roots. | — |
| `APIIRO_TELEMETRY` | Set to `0` to disable anonymous usage analytics. | enabled |
| `APIIRO_AUTO_UPDATE` | `off` turns off automatic updates; `on` turns them on where they are off by default (CI). | on, off in CI |
| `APIIRO_NO_UPDATE_NOTIFIER` | Set to any value to silence the new-version notice. | — |
| `DO_NOT_TRACK` | Standard opt-out convention; also disables anonymous usage analytics. | — |
| `APIIRO_CLIENT` | Surface invoking the CLI: `cli` or `ide`. Used in analytics only. | `cli` |
| `APIIRO_CLIENT_VERSION` | Version of the invoking surface (e.g. IDE extension version). | CLI version when `APIIRO_CLIENT=cli` |
| `CLAUDE_CONFIG_DIR` | Claude Code config directory used for agent detection, plugin setup, skills, status, and doctor. | `~/.claude` |
| `CODEX_HOME` | OpenAI Codex config directory used for agent detection, hook installation, status, and doctor. Skills stay in `~/.agents/skills`, where Codex reads them. | `~/.codex` |
| `XDG_CONFIG_HOME` | Parent of the opencode config directory (`opencode/`) used for agent detection, plugin installation, skills, status, and doctor. | `~/.config` |
| `COPILOT_HOME` | GitHub Copilot CLI config directory used for agent detection, hook installation, skills, status, and doctor. | `~/.copilot` |

## Privacy & Telemetry

The CLI may send anonymous usage analytics (command name, success/failure, duration, OS, CLI version, client surface, and tenant id from your access token) to help Apiiro understand which features are used. It also records when a pre-commit scan is bypassed with `git commit --no-verify`, together with the coding-agent surface the bypass came from. Analytics never collect source code, repository URLs, file paths, finding details, email addresses, or tokens.

The first time analytics would be recorded in an interactive terminal, the CLI prints a one-time notice on stderr. Telemetry is disabled automatically in CI environments, and you can opt out at any time with `APIIRO_TELEMETRY=0` or the standard `DO_NOT_TRACK=1`.

Separately from analytics, the Claude Code prevention hooks report each commit a Claude Code shell command makes to **your own Apiiro tenant**: the repository key, commit sha, parent shas, branch, commit time, the Claude Code session id (and whether git printed the commit or it was inferred), the coding agent, and the CLI version — never file content, diffs, or messages. It is how Apiiro attributes a commit to the session that produced it; it is only sent when you are signed in, and a failure to send it never affects the commit.

To keep itself on your organization's version, the CLI asks **your own Apiiro tenant** for the version setting about once an hour while you use it. That request carries the operating system, processor architecture, install method, update state, last update error, the latest stable version the CLI found, and a random id for this account on this machine, so your administrators can see which versions are in use. It is only sent when you are signed in, and it never contains code or repository data.

Likewise, a bypassed pre-commit scan is also reported to **your own Apiiro tenant**, so your administrators can see in the Guardian actions log that a scan was skipped. That report carries your repository's git URL, branch, and the coding-agent surface — the same repository context the scans themselves send — and never any file content or findings. It is a security record rather than product analytics, so neither the analytics opt-out above nor `apiiro hooks config disable disablePreCommitScan` suppresses it; it is only sent when you are signed in to Apiiro, and a failure to send it never blocks your commit.

The prompt hook's local log of enriched prompts (see [Hooks](#hooks)) stays on your machine and is never sent to Apiiro or included in analytics.

## Troubleshooting

- **TLS / HTTPS errors** (corporate TLS inspection) — Point `NODE_EXTRA_CA_CERTS` at a PEM file from your IT team and retry.
- **"Certificate has expired"** — Try `apiiro login --no-merge-system-ca`.
- **macOS: keychain export slow or failing** — Raise `APIIRO_CA_EXPORT_TIMEOUT_MS` / `APIIRO_CA_EXPORT_MAX_BUFFER_BYTES`, or set `APIIRO_FORCE_SECURITY_EXPORT=1`.

## Support

For help with the Apiiro CLI or the Apiiro plugin for ChatGPT and Codex, submit a ticket at [support.apiiro.com](https://support.apiiro.com) or from your Apiiro tenant.

Please include:

- The host you are using (ChatGPT, Codex CLI, Codex app, or Codex IDE extension)
- The plugin version, or the CLI version from `apiiro --version`
- A short description of the issue and the steps to reproduce it
- Any error message, with credentials, tokens, and other sensitive values removed

Do not post credentials, confidential code, or security findings in public GitHub issues or discussions. Include them only in a support ticket.

## Documentation

Full documentation is available at [docs.apiiro.com](https://docs.apiiro.com).

## License

Use of the Apiiro CLI is subject to the [Developer Tools EULA](https://github.com/apiiro/marketplace/blob/main/Apiiro%20Developer%20Tools%20EULA.pdf).
