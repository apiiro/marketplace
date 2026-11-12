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

### Scans

Read results for diff, pull-request and build scans, or trigger a new scan. Agent skill: `guardian-scan`.

```bash
apiiro scans <id>                              # Diff scan results (V2)
apiiro scans <id> --type pr --wait              # Wait for pull-request results
apiiro scans <id> --type build                  # Build scan results
apiiro scans <id> --legacy                     # V1 diff results (also supported for pr)
apiiro scans --config --git-url https://github.com/org/repo

apiiro scans trigger -b main -c feature-branch -r https://github.com/org/repo --wait --yes
apiiro scans trigger --type diff -b <base-sha> -c <candidate-sha> \
  --baseline-type Commit --candidate-type Commit --wait --yes
apiiro scans trigger --type pr --pr 42 -r https://github.com/org/repo --wait --yes
apiiro scans trigger --type build --commit <40-character-sha> --branch main --directory src --yes
apiiro scans trigger --finish-upload <id> --type pr --yes
```

Triggers ask for confirmation every time; `--yes` skips the question for automation. The default type is `diff`. Repository URLs are detected from git when `-r, --repository-url` is omitted. Diff triggers also support `-i, --interactive`, `--baseline-type` and `--candidate-type` (`Branch`, `Tag`, `Commit`), `--wait-external`, `--legacy`, and `--no-wait`. Pull-request and build triggers support `--wait`. `--wait-external` applies to diff and pull-request triggers. `--finish-upload` applies to diff and pull-request scans that wait for external findings.

Build scan commits must have 40 hexadecimal characters; uppercase letters are accepted and sent lowercase.

Results support `--wait`, `--timeout <seconds>` (default: 300), `-o json|text`, and `-f <path>`. Exit codes: 0 = `Success` or `Warn` (or a passing build), 1 = `Block`, a failing build or an error, including a wait timeout, 2 = not signed in or results still pending without `--wait`. Keep the scan ID to check again after a timeout.

### Quick Scans

Scan changed or staged files for secrets, OSS vulnerabilities, AI SAST code weaknesses, and IaC misconfigurations. The default runs all four scanners. AI SAST can take several minutes. Requires a git repository with a remote. Repository eligibility is checked before uploading file contents; unmonitored repositories are skipped unless Apiiro has enabled scanning them for your environment. Skipped scans are reported with a reason.

```bash
apiiro scans trigger --type quick --yes
apiiro scans trigger --type quick src/config.ts --scanners secrets --yes
apiiro scans trigger --type quick --staged --scanners secrets,oss --yes
apiiro scans trigger --type quick --scanners secrets,oss,ai-sast,iac --yes
```

Choose one scanner, or include both `secrets` and `oss` with optional `ai-sast` and `iac`.

Quick scans use the same output, server verdicts and exit codes as `fast-scan`: 0 for clean results or a scanner that could not run; 1 for findings, a server `Block`, or a usage error. With a server verdict, `Warn` and `Success` allow the scan even when findings are present. The new commands require sign-in (exit 2 when missing). The pattern-scanner budget is 2 seconds by default, capped at 5 with `--timeout`; individual AI SAST and IaC scans use their existing longer budgets.

The old names still work. `diff-scan` is a hidden, deprecated alias with its original flags (`-s <id>` to read results), and runs without confirmation. `fast-scan` and every subcommand remain available without warnings or confirmation for installed hooks and IDE integrations. For example, `apiiro fast-scan all --staged` runs secrets and OSS; `apiiro fast-scan secrets --full --fail-on high` scans whole files with an explicit severity threshold. Its `--commit` and `--base-commit` options remain available. Signed-out fast scans keep reporting a skipped scan with exit 0; `fast-scan config` requires sign-in.

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

### Pull Requests

```bash
apiiro pull-requests --repo <scmRepositoryKey> --status Blocked Pending -o json
apiiro pull-requests --stats --workflow <key> --look-back-days 30
apiiro pull-requests --server-url https://github.com --since 2026-10-01 --until 2026-10-31
```

Allowed statuses: `Blocked`, `Unblocked`, `Pending`, `TimedOut`. Filters also accept `--repo`, `--workflow`, and exact `--server-url`. `--look-back-days` accepts 0–365 (server default: 30); ISO `--since` and `--until` narrow that window. Both list and statistics use offset paging: `--page-size` defaults to 100 (max: 1000), `--max-pages` defaults to 5. A capped result prints a truncation note; JSON is `{items, truncated}`. Use `-o json|text` and `-f <path>` for output.

### CI/CD Records

```bash
apiiro cicd create --build --commit <40-lowercase-hex-sha> --repo <repositoryKey> \
  --version 1.2 --application payments --build-id 42 --build-url https://example.com/build/42 --yes
apiiro cicd create --deployment --deployment-id 42 --name production --url https://example.com/deploy/42 \
  --commit <sha1> <sha2> --repo-version payments=1.2 web=2.0 --yes
```

Choose exactly one of `--build` or `--deployment`. Build records require one commit and a repository key. Deployment records require `--deployment-id` and at least one `--commit` or `--repo-version`; `--name` and `--url` are optional. These commands record metadata through the existing CI/CD API. They ask before sending; `--yes` skips confirmation. Successful writes have an empty server response and print a success message (`{}` with `-o json`). Output supports `-o json|text` and `-f <path>`.

### Managed Semgrep

```bash
apiiro semgrep -o json
apiiro semgrep update --git https://github.com/org/rules --yes
apiiro semgrep update --git <url> --provider-repo <key> --yes
apiiro semgrep update --tar rules.tar --yes
```

Updates require exactly one of `--git` or `--tar`; `--provider-repo` requires `--git`. Updates ask before replacing the rules; `--yes` skips confirmation. Tar files stream from disk with a default request timeout of 600 seconds; set `--timeout <seconds>` to override it. Updates print the server's message. All commands support `-o json|text` and `-f <path>`. Configuration can be unavailable when AI SAST scan effort manages the rules.

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

### Findings and engagements

```bash
apiiro findings --repository-id <id> --application-id <id> --risk-level High -o json
apiiro findings --page-size 100 --max-pages -1
apiiro findings upload report.json
apiiro findings upload report.json --yes -o json
apiiro findings delete --system <id> --finding-id <id> --finding-id <other-id>
apiiro findings delete --system <id>
apiiro engagements --type Pentest --status Active --lead <key> -o json
apiiro engagements <key>
apiiro engagements create --data '{"name":"Annual assessment","type":"Pentest","startDate":"2026-11-01T00:00:00Z","status":"Active"}'
apiiro engagements update <key> --data @engagement.json
apiiro engagements delete <key>
```

`findings` lists manual-assessment findings. Its optional filters are `--repository-id`, `--application-id` and `--risk-level`. The list rejects `--repository-key` and `--remote`. Omitted filters leave the list organization-wide within your access scope. `engagements` lists or reads one key. List filters are `--type Pentest|General`, `--status Active|Scheduled|InReview|Closed` and `--lead <key>`. Both lists support `--page-size` (1–1000, default 100) and `--max-pages` (default 5, `-1` for all). JSON lists contain `{items, truncated}`; text output says when the page limit leaves more results. Both support `-o json` and `-f <path>`.

`findings upload` streams the file as a JSON request body and prints server warnings. Reports require `scanId`, `scanProjectName`, `providerName` and `providerId`; the server validates the report. Uploads use a ten-minute timeout unless you pass `--timeout <seconds>`. The confirmation shows the file path and size. `--yes` skips this confirmation.

Engagement create and update accept inline JSON or `--data @file` and ask before sending (`--yes` skips). Required fields are `name`, `type`, `startDate` and `status`. Optional fields include `externalUrl`, `summary`, `scope` (`applicationKeys` and `repositoryKeys` arrays), `endDate`, `tags`, `engagementLeadKey`, `provider` and `attachments`. **Update uses PUT to replace the whole engagement; omitted fields are reset.** Read the current engagement first and include all fields you want to keep.

Both delete commands always require typing the exact system id or engagement key in a terminal and have no `--yes`. `findings delete` deletes findings sent through the legacy general-findings API for the given system id. Without `--finding-id`, it targets **all legacy findings for that system id**. Findings sent by `findings upload` or listed by `findings` are stored separately. Success means the request was accepted; the server returns no deletion count, even for an unknown system id. Engagement delete permanently removes the engagement **and its findings and reports**. Without confirmation, nothing is sent (exit 130).

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
apiiro artifacts                                 # Artifacts; filter with --type, --application-id, --team-id
apiiro artifacts <artifact-id>                   # Versions of one artifact
apiiro artifacts <artifact-id> --risks           # Risks of one artifact
apiiro artifacts --container-images              # Container images from the v1 API
apiiro artifacts --import <import-id>            # SBOM import status
apiiro artifacts import --file sbom.json --version 1.0 --name my-sbom --yes
apiiro artifacts import --file sbom.json --version 2.0 --artifact <artifact-id> --yes
apiiro artifacts delete <artifact-id>            # Permanently delete an SBOM artifact; type its ID to confirm
apiiro artifacts delete <artifact-id> --version <version-id>
apiiro artifacts delete <artifact-id> -o json     # {"id":"...","version":null,"deleted":true}
apiiro secrets update <sha> --validity invalid --reason "Rotated"   # valid, invalid, or auto to clear the override
apiiro contributors                              # Contributors (5 pages by default); <key> for one
apiiro contributors --export -f contributors.jsonl                  # Every contributor as JSON Lines
```

`inventory <item-key>`, `--type module`, `--deleted`, `--secret`, `inventory sbom` and `contributors <key>` print the API's JSON. Artifact lists take `--page-size` 1–200 (default 100). `--risks` requires an artifact ID; text rows show risk ID, rule name and risk level. `--container-images` uses the v1 container image list; text rows show ID, image ID and type. Both support `--max-pages`, `-o json` (`items` and `truncated`) and `-f`. Container images use offset paging and accept only the paging and output options; the default artifact list uses v2. New artifact imports take `--name` and optional `--application-id`; existing artifacts take `--artifact`. SBOM imports stream from disk and accept files up to 512 MB. Imports ask before sending unless `--yes` is present. Artifact commands accept `-o json` and `-f <output-path>` before or after the subcommand; import uses `--file` for the SBOM input and `-f`/`--output-file` for saved output. `artifacts delete` works only on SBOM artifacts and permanently deletes their versions, dependencies and findings. With `--version`, it deletes only that version and names it in the confirmation prompt. Empty artifact IDs and versions are rejected before confirmation. Delete JSON includes `id`, `version` (null for the whole artifact), and `deleted: true`. In JSON, `"truncated": true` means the list stopped at `--max-pages`; raise it to fetch more. `secrets update` asks before it sends, like `risks update`, and changes every occurrence of the same secret value. `apiiro contributors` needs the contributors API enabled for your organization. API keys need "Inventory management" for inventory lists, `--deleted`, `--secret` and SBOMs, with write access for `secrets update`, and "Full control" for `inventory <item-key>`, `--type module` and `contributors`.

### Policies, coverage, issues and reports

These commands read data without confirmation prompts. Each supports `-o json|text` (default text) and `-f <file>`.

```bash
apiiro policies                                  # All enabled policies, no server paging
apiiro policies --repo my-repo -o json            # Raw policy array, all fields preserved
apiiro coverage                                  # Repository scanner coverage
apiiro coverage --repo my-repo --page-size 100 --max-pages -1
apiiro coverage --projects                       # External scanner projects; no repository filter
apiiro coverage --providers                      # Provider names, no server paging
apiiro issues                                    # Open issues across repositories
apiiro issues --repo my-repo                      # Issues linked through pull requests
apiiro issues --closed --issue-id ISSUE-123       # Closed issues, filtered by ID
apiiro reports list --search risk --type card --collection Security --limit 25
apiiro reports details --card 123                # Exactly one of --card or --dashboard
apiiro reports run --card 123 --param '{"id":"repository","value":["my-repo"]}'
apiiro reports run --card 123 --dashboard 10 --dashcard 20
apiiro reports compliance --framework soc2 --query control_summary --limit 20
apiiro reports compliance --framework soc2 --query repo_violations --repo my-repo
```

`policies`, repository `coverage`, and `issues` accept `--repo <name>` or `--repository-key <key>`. Policies and coverage select the default monitored branch by name or a specific branch profile by key; issues span all repository branches. Without either, they read across the organization. Ambiguous names need `--repository-key`. They do not auto-detect a repository. `coverage --projects --repo` is an error; `--providers` accepts no repository or paging flags.

Repository and project coverage and issues use `--page-size <1..1000>` (default 100) and `--max-pages <count>` (default 5; `-1` for all). JSON is `{items, truncated}`; text says when more items exist. Project pages can be empty while more pages exist. Issues can change during paging, so an updated issue may be skipped. Policies and provider names return their full raw arrays in JSON and have no paging flags. Issues expose only indexed filters: repository, issue ID and open/closed state.

Reports require Guardian enabled and use your own credentials. Report data can be up to an hour stale. `list` accepts `--search`, `--type card|model|dashboard|all`, `--collection`, and `--limit <1..100>` (server default 25). `details` requires exactly one positive `--card` or `--dashboard` ID and shows the name, description, parameter IDs and dashboard card IDs. `run` requires `--card`; dashboard filters need both `--dashboard` and `--dashcard`. Repeat `--param` for each JSON object, using parameter IDs from `details`. Runs return up to 100 rows; `truncated` marks a capped result. Reports have no `--page-size` or `--max-pages` flags. JSON preserves the tool result; text shows report entries, parameters, result rows or compliance summary fields.

`compliance` accepts `--framework soc2|pcidss|nist800-53|iso27001`; Guardian requires it except for `cross_framework`. Its `--query` is `control_summary` (default), `app_violations`, `cross_framework` or `repo_violations`. Only `repo_violations` takes and requires `--repo <name>`. `--limit <1..100>` defaults to 20 on the server.

### Applications and Application Groups

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

Lists default to 100 items per page and 5 pages; `--max-pages -1` fetches all pages. JSON includes `items` and `truncated`; raise `--max-pages` when truncated. Create and update ask before sending; `--yes` skips that question. Deletes always require the exact key typed in a terminal. `--set` always sends a string; repeatable `--set-json field=json` parses JSON and rejects invalid JSON. Application updates send one JSON Patch; a partial update reports failed fields and exits non-zero. Group updates replace the full body and require at least one application key.
### OSS, Incidents, Feed and Custom Advisories

Read vulnerability and package content, security incidents, and the security feed. API keys need "Full control" read permission; advisory writes need write permission. Custom advisories require the CustomAdvisories feature enabled for your organization.

```bash
apiiro oss CVE-2021-44228                        # CVE details merged with EPSS scores
apiiro oss 'pkg:npm/lodash@4.17.20'              # Package and dependency findings
apiiro oss 'pkg:npm/lodash@4.17.20' --license    # License IDs, source and source URLs
apiiro oss 'pkg:npm/lodash' --license --full     # Include full license text
apiiro incidents                                # Incident list
apiiro incidents <id>                           # One incident
apiiro incidents <id> --scope --since 2026-10-01 # Affected packages added after a date
apiiro feed --repo <key> --status Followed       # Computed feed; also --application and --team
apiiro feed --questions --type Announcement     # Feed rules; also Manual or Seed
apiiro advisories                               # Custom advisory list
apiiro advisories <id>                          # One custom advisory
apiiro advisories update --input advisory.json  # Create or replace, asks before sending
apiiro advisories delete <id>                   # Requires typing the ID in a terminal
```

All these commands accept `-o json|text` (default text) and `-f <file>` for output. CVE IDs are uppercased before lookup. `oss --license` requires a package URL; JSON includes full license text, while text includes it only with `--full`.

Lists fetch up to 5 pages by default. Use `--page-size <size>` (default 100; max 100 for incidents and scope, max 1000 for feed and advisories) and `--max-pages <count>` (`-1` for all). JSON lists return `{items, truncated}`; `truncated: true` and the text hint mean more items exist. An incident ID alone and an advisory ID reject paging flags. Incidents have no list filters; `--since` requires an ID and `--scope`.

Feed `--repo`, `--application` and `--team` take keys and scope the counts; they do not hide items. `--status` accepts `ForYou`, `Followed` or `Dismissed`; the server defaults to `ForYou`, which includes followed items. `--questions` is unpaged, accepts `--status` and `--type Manual|Seed|Announcement`, and rejects key and paging flags. Its JSON is the raw rule array; text shows a short summary without `insightPredicate` or `ruleTarget`.

`advisories update --input <file.json>` takes a JSON object with `advisoryId` and the advisory fields. It creates a new ID or **replaces the whole existing advisory**: omitted fields reset, and affected packages are re-scored. The server validates the body. Use `--yes` to skip update confirmation. `--input` is separate from the `-f` output path. Delete also re-scores packages, requires the exact ID typed in a terminal, and has no `--yes` option. Both operations send nothing when confirmation is refused.

### Connectors, Audit Logs and Export

```bash
apiiro connectors                                      # List connectors
apiiro connectors <id>                                 # Read one connector
apiiro connectors create --type github --url https://github.com/my-org
apiiro connectors update <id> --token-expiration-date 2027-01-01
apiiro audit-logs --status Failure --since 2026-11-01 --until 2026-11-08
apiiro export                                          # List available routes
apiiro export repositories --file repositories.json     # Stream an export to a file
apiiro export repositories/<key>/apis                   # Stream to stdout
```

Connector writes require a token from `APIIRO_CONNECTOR_TOKEN` or piped stdin with `--token-stdin` (which takes precedence and removes the trailing newline). Tokens cannot be passed as command arguments. Writes ask before sending; `--yes` skips the prompt. For piped stdin, use `--token-stdin --yes` after approving the change. The token is excluded from prompts and output. Creation supports `--type github|gitlab|bitbucket|azureDevops`, `--url`, optional `--description` and `--token-expiration-date` (ISO date). `--username` is required for `bitbucket` and `azureDevops`. Creation requires a server version that supports connector creation; older servers return a clear error. `connectors update <id>` changes the token and optional expiration date only; `-o json` returns `{id, tokenUpdated: true}`.

`audit-logs` supports `--event-type`, `--status Success|Failure`, `--user`, `--user-type User|Token|System`, and paired `--since` / `--until` dates (`yyyy-MM-dd`, `yyyy-MM-ddTHH:mm:ssZ` or `yyyy-MM-ddTHH:mm:ss.fffZ`). Date-only `--until` includes the whole day. The filters use indexed fields. Connector and audit-log lists fetch up to 5 pages by default. Both support `--page-size 1..1000` and `--max-pages <count>` (`-1` for all). Text output shows one line per item; connector reads show the ID, provider, URL and token expiration. Audit-log lines show time, event type, status, user and event description. JSON output includes `{items, truncated}`; `truncated: true` means more pages may exist. Lists and individual connector reads support `-o json` and `--file`.

`export` lists the routes available on your server, so the list can differ between versions. Pass the part after `/rest-api/v1/export/`, replacing any placeholders with real keys. Route segments are encoded separately. Put query parameters after `?` and quote the argument, for example `apiiro export 'applications/<key>/sbom?format=CycloneDx'`. Export responses stream directly to stdout or `--file`, with a 10-minute timeout by default; `--timeout <seconds>` overrides it. A file is replaced only after the download completes. `-o json` applies to the routes list; route downloads keep the response bytes. These commands require a token with **Full control** permission.

### Roles, role groups and users

Manage access roles and Apiiro user groups, and read users in those groups.

```bash
apiiro roles                                       # List roles
apiiro roles <key>                                 # Read a role (JSON)
apiiro roles create --data '{"name":"Security Admin","permissions":{"Governance":"Write"},"scope":null}'
apiiro roles update <key> --permission Governance=Read --assign-group Apiiro:<group-key>
apiiro roles update <key> --unassign-group Idp:<group-key>
apiiro roles delete <key>
apiiro role-groups                                 # List groups
apiiro role-groups <key>                           # Read a group (JSON)
apiiro role-groups create --data '{"name":"Platform","adminIds":["admin@example.com"],"memberIds":["member@example.com"]}'
apiiro role-groups update <key> --data '{"name":"Platform","memberIds":[]}'
apiiro role-groups delete <key>
apiiro users                                       # List users in role groups
apiiro users 'member@example.com'                   # Read group membership (JSON)
```

Lists use `--page-size <1..1000>` (default 100) and `--max-pages <count>` (default 5; `-1` fetches all). JSON list output (`-o json`) is `{items, truncated}`; text output warns when more results may exist. Lists contain `{key, name}` for roles and groups, and `{userId}` for users. User details contain `{userId, groups:[{groupKey, userRole}]}`. Users outside every role group return “No user <id> in any role group.”

Create and update ask before sending; `--yes` skips the prompt. `--data` accepts inline JSON or `@file`. Creates return the new key (text) or `{key}` (`-o json`). Delete always requires typing the key in a terminal. Deleting a role group also unassigns it from every role. Commands support `-o json` and `-f <path>`.

Roles require a name and permissions on create. A null scope grants global scope; scope can restrict applications, repositories and organizational teams. Optional `description`, `idpGroupIds` and `apiiroGroupIds` are accepted. Newer servers also support `scimGroupIds` and scope fields `applicationGroupKeys` and `connectorIds`. SCIM support depends on the server version and whether it is enabled for your organization.

Role updates accept repeatable `--permission Name=Read|Write`, `--assign-group type:groupKey` and `--unassign-group type:groupKey`, with type `Idp`, `Apiiro` or `Scim`. At least one flag is required. Name, description and scope cannot be changed after create. Requests run one at a time: permissions first, assignments next, removals last. On failure, the command stops and reports which changes were already applied; earlier changes stay applied.

Role-group updates require `name`. Omitted or null `description`, `adminIds` and `memberIds` keep their stored values; `[]` clears an admin or member list. Roles need the Roles access-token permission, role groups need OrganizationalTeams, and users need Users; reads require Read and writes require Write. For role create and update, the token must also hold every permission and scope the role grants; a token can only grant what it holds.

### Explorer

Run a read-only ApiiroQL query across your organization. The server validates the query and queried type.

```bash
apiiro explorer "<ApiiroQL>" --type RepositoryProfile
apiiro explorer "<ApiiroQL>" --type RiskTriggerSummary --columns name,url -o json
apiiro explorer "<ApiiroQL>" --type RepositoryProfile --max-pages -1 -f results.json -o json
```

`--type` is required (for example, `RepositoryProfile`, `RiskTriggerSummary`, `ApiElement`, or `DependencyDeclaration`). `--limit` caps matching rows processed by the query (1..100000, default 1000). `--columns` keeps comma-separated column keys locally; empty keys are rejected before submission, and an unknown key lists the valid keys. Available columns depend on the query.

The command submits the query, waits for completion, then fetches result pages. `--wait` caps the wait (default 300 seconds). On timeout, the error includes the query ID and says it is still running. `--page-size` defaults to 100 (maximum 1000); `--max-pages` defaults to 5, or `-1` for all pages within the query's limit. A concurrency limit error includes the server's retry delay when supplied; the command does not resubmit automatically.

`-o text` (default) prints a block per row and a row count. `-o json` prints `{queryId, columns, rows, truncated}` with rows keyed by column key. `truncated: true` means the page cap was reached; raise `--max-pages` to fetch more. `-f <path>` saves either format to a file. `--api-url <url>` selects the API server.

### Teams

```bash
apiiro teams --page-size 100 --max-pages 5 -o json
apiiro teams <key>
apiiro teams create --data @team.json
apiiro teams update <key> --set name=Payments --set parentKey=parent-team --add-tag owner:payments --remove-tag old
apiiro teams delete <key>
```

Teams page, update and delete like applications. Text shows the key, name and parent key. Deleting a team clears the parent key of its child teams and removes the roles scoped to it.

### Repositories

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

`repositories` lists monitored branch profiles. A URL (including `git@` and `ssh://` URLs) filters by exact repository URL. Azure DevOps SSH URLs and Bitbucket Server SSH URLs on port 7999 are converted to their repository web URLs. Other values try a key first, then an exact name after a 404. A key lookup prints the API's JSON object. `scm-repositories` lists SCM records; a value first tries an SCM key and prints its tags (a JSON array with `-o json`), then searches by name after a 404. A name matches part of the name, without case, and `--tag name:value` lists the records that carry that tag (split on the first `:`). A name or key lookup with no matches exits 1; an empty tag search prints `0 SCM repository(s)` and exits 0. A key that starts with `-` goes after `--`, for example `apiiro repositories -- -AbC123`.

Lists default to 100 items per page and 5 pages; `--max-pages -1` fetches all pages. JSON lists include `items` and `truncated`. `--tag` cannot be combined with a repository argument. `--detect` and `--clear` take no repository argument and no paging flags; `--global` requires `--clear`. Detection failures exit 2.

`repositories update` (also `repos update`) and `scm-repositories update` use the same SCM repository key, options and SCM routes. Updates take exactly one change per run and ask before sending; `--yes` skips the question. `--add-tag` uses the same `name:value` form as `--tag`. Updates print the response JSON, or a success message for an empty response.

### AutoFix

Queue server-side fixes for risks, list jobs, and follow their results:

```bash
apiiro autofix                                           # Newest jobs first
apiiro autofix --risk <riskKey> --status Queued AgentWorking
apiiro autofix --status Completed --status Failed -o json
apiiro autofix --page-size 100 --max-pages 10
apiiro autofix <jobId>                                   # Includes per-risk results and pull request details
apiiro autofix <jobId> --open-pr                          # Ask to queue a pull request
apiiro autofix trigger <riskKey...>                       # Ask to queue fixes for 1-100 distinct risks
apiiro autofix trigger <riskKey...> --dry-run --yes        # Push branches without opening pull requests
```

Statuses: `Queued`, `AssemblingContext`, `AgentWorking`, `Completed`, `Failed`, `Cancelled`.
`--status` accepts several values and can be repeated. List filters are `--risk` and `--status`.
Lists fetch up to 5 pages of 20 jobs by default (`--page-size` max 100); use `--max-pages -1` for no limit. A warning says when more jobs exist.
Job IDs and `--open-pr` cannot be combined with list filters or paging flags.

Both writes ask for confirmation each time; `--yes` skips the question. Trigger removes duplicate risk keys.
`--dry-run` pushes a branch without opening a pull request. Organization simulation settings may also make a job a dry run.
Trigger prints queued jobs and skipped risks with their reasons, and exits nonzero if every risk is skipped.
`--open-pr` works only on a completed dry-run job with no pull request yet (`canOpenPr: true`). It queues the request; run `apiiro autofix <jobId>` later to see the pull request link.

All modes accept `-o json|text` and `-f <path>`. List JSON is `{ items, truncated }`; other modes keep the server response fields. Put trigger flags after `trigger`, for example `apiiro autofix trigger <riskKey...> --yes -o json`.
API tokens need AutoFix read permission for reads and write permission for writes.
A trigger permission error can also mean AI consent is off for the organization.

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
| `APIIRO_CONNECTOR_TOKEN` | Connector token for `connectors create` / `update`; `--token-stdin` overrides it. | — |
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
