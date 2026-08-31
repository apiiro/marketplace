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

Environment overrides: `APIIRO_INSTALL_DIR`, `APIIRO_VERSION` (pin a version), `APIIRO_NO_MODIFY_PATH`.

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

Fleet rollouts use the same one-line installer — no package to build or upload. From an MDM policy script (or any login script), run as each user:

```bash
curl -fsSL https://apiiro.com/install.sh | bash
apiiro init --non-interactive
```

Pin the fleet to a specific version with `APIIRO_VERSION=<version>`. `apiiro init --non-interactive` detects each user's installed AI coding agents and wires in Agent Skills and prevention hooks with no prompts. Managed-device admins: see your Apiiro contact for the ready-made Jamf policy and extension attribute scripts (self-bootstrapping, with version pinning and drift repair).

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

The recommended setup detects Claude Code and Cursor, installs their skills and prevention hooks, then verifies the result:

```bash
apiiro init
apiiro doctor
```

Common options:

```bash
apiiro init --claude          # Claude only; use --cursor or --all as needed
apiiro init --skills-only     # Skip prevention hooks
apiiro init --dry-run         # Preview file changes
apiiro init --non-interactive # Unattended / MDM setup
apiiro uninstall              # Remove skills and hooks
apiiro uninstall --remove-binary
```

Restart Claude Code after setup. For skills without prevention hooks, use `apiiro agents install`. Without the CLI, install them with [Vercel Skills](https://github.com/vercel-labs/skills):

```bash
npx skills add apiiro/marketplace
```

Manual Claude setup remains available through `/plugin marketplace add apiiro/marketplace`, followed by `/plugin install apiiro@apiiro` and, optionally, `/plugin install apiiro-prevention@apiiro`.

Available skills: `guardian-risks`, `guardian-fix`, `guardian-query`, `guardian-threat-model`, `guardian-scan`, `guardian-secure-prompt`.

## Authentication

```bash
# Login via OAuth (opens browser)
apiiro login

# Check status
apiiro auth status

# Logout
apiiro logout
```

Alternatively, set the `APIIRO_API_KEY` environment variable.

## Commands

### Fast Scan

Quick local scanning for secrets and OSS vulnerabilities. Auto-detects changed files in the current git repo. Agent skill: `guardian-scan`.

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

### Risks

List and inspect risks for a repository. Agent skills: `guardian-risks` (list/inspect), `guardian-fix` (remediate).

```bash
apiiro risks                                     # List all risks (auto-detects repo)
apiiro risks --repo my-repo-name                 # Specify repo (defaults to its default branch)
apiiro risks --repo my-repo-name --branch dev    # Target a specific monitored branch
apiiro risks --repository-id <repo-id>           # Specify repo (branch) by ID
apiiro risks --risk-level Critical               # Filter by risk level
apiiro risks --risk-category "API Security"      # Filter by category
apiiro risks get <risk-id>                       # Get risk details
apiiro risks remediate <risk-id>                 # Get remediation instructions
apiiro risks fix <risk-id>                       # Curated remediation when available, Guardian fallback otherwise
```

Each monitored branch is its own profile with its own ID; use `--branch` or `--repository-id` to pin one.

### Inventory

List inventory items (APIs, dependencies, sensitive data, secrets) for a repository or application. Requires a scope (auto-detected from git, or one of the explicit flags).

```bash
apiiro inventory                                 # Auto-detect repo from git
apiiro inventory --repo my-repo-name             # Specify repo (defaults to its default branch)
apiiro inventory --repo my-repo-name --branch dev # Target a specific monitored branch
apiiro inventory --application-id <app-id>       # Scope to an application
apiiro inventory --entity-type API               # Filter: API, Dependency, Secret, SensitiveData, ...
apiiro inventory --repo my-repo -o json          # JSON output
apiiro inventory --repo my-repo --max-pages -1   # Fetch every page (default cap: 5)
```

### Raw API Access

Send an authenticated request to any Apiiro REST API endpoint — a curl-style passthrough where the CLI supplies the base URL, authentication, and headers. Endpoint reference: https://docs.apiiro.com/api

```bash
apiiro api "/rest-api/v1/risks?filters[RiskLevel]=Critical"    # GET with filters
apiiro api /rest-api/v1/applications -d '{"name": "my-app"}'   # POST (inferred from --data)
apiiro api /rest-api/v1/applications/<key> -X PATCH -d @patch.json
cat body.json | apiiro api /rest-api/v1/diffScans -d @-        # body from stdin
apiiro api /rest-api/v1/risks -i                               # include response status + headers
```

The response body goes to stdout (raw when piped, so it composes with `jq`); exit code is 0 for 2xx and 1 otherwise.

### Threat Model

Perform STRIDE-based threat analysis on feature specs, requirements, or architectural changes. Agent skill: `guardian-threat-model`.

```bash
apiiro threat-model "Add REST API for file uploads to S3"
apiiro threat-model "Implement OAuth2 with PKCE" --title "Auth redesign"
apiiro threat-model "Add webhook support" -o json
apiiro threat-model "Migrate sessions to JWT" -f threat-report.md
```

### Guardian (AI Agent)

Query Apiiro's AI agent for security analysis and insights. Agent skill: `guardian-query`.

```bash
apiiro guardian query "what risks exist in this repo"
apiiro guardian query "deep analysis of auth flow" --model normal
apiiro guardian query "what is STRIDE?" --global
apiiro guardian query "detailed analysis" --timeout 120
apiiro guardian query "what risks exist here" --remote gh   # detect via a non-origin remote
```

### Guardian Repository

```bash
apiiro guardian repository detect    # Detect and verify repo in Apiiro
apiiro guardian repository clear     # Clear cached repo info
```

### Hooks

Git pre-commit hook for automatic security scanning, plus CLI-managed prevention hooks for Claude Code and Cursor.

```bash
apiiro hooks pre-commit install     # Install pre-commit hook
apiiro hooks pre-commit status      # Check hook status
apiiro hooks pre-commit uninstall   # Remove hook

apiiro hooks claude install            # Enable the apiiro-prevention plugin (CLI equivalent of /plugin install)
apiiro hooks claude status             # Check status
apiiro hooks claude uninstall          # Disable the plugin
apiiro hooks claude install --system   # Target Claude Code managed settings (admin/MDM scope)

apiiro hooks cursor install         # Install the Cursor prevention hook
apiiro hooks cursor status          # Check hook status and integrity
apiiro hooks cursor uninstall       # Remove the hook

apiiro hooks update                 # Refresh locally-installed hook artifacts once out of date
apiiro hooks update --dry-run       # Preview without making changes
```

Restart Claude Code after installing or uninstalling its plugin for the change to take effect.

### Doctor

Unified health check for your Apiiro setup — CLI version, auth state, per-agent skills, Claude Code plugin status, Cursor hook integrity, pre-commit hook, and hook toggles. Works without authentication.

```bash
apiiro doctor           # Human-readable report
apiiro doctor --json    # Machine-readable
```

### Update

Check for a newer CLI release, replace the running binary in place, and refresh installed hook files to the new version. Works without authentication.

```bash
apiiro update           # Check, install if a newer version is available, then refresh hooks
apiiro update --check   # Only check; don't install
```

The download is checksum-verified and test-run before it replaces anything. Only self-updates the compiled binary (not npm or dev-mode invocations) and skips Homebrew-managed installs — run `brew upgrade apiiro` or `npm i -g apiiro-cli@latest` for those.

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
| `DO_NOT_TRACK` | Standard opt-out convention; also disables anonymous usage analytics. | — |
| `APIIRO_CLIENT` | Surface invoking the CLI: `cli` or `ide`. Used in analytics only. | `cli` |
| `APIIRO_CLIENT_VERSION` | Version of the invoking surface (e.g. IDE extension version). | CLI version when `APIIRO_CLIENT=cli` |

## Privacy & Telemetry

The CLI may send anonymous usage analytics (command name, success/failure, duration, OS, CLI version, client surface, and tenant id from your access token) to help Apiiro understand which features are used. No source code, repository URLs, file paths, finding details, email addresses, or tokens are collected.

The first time analytics would be recorded in an interactive terminal, the CLI prints a one-time notice on stderr. Telemetry is disabled automatically in CI environments, and you can opt out at any time with `APIIRO_TELEMETRY=0` or the standard `DO_NOT_TRACK=1`.

## Troubleshooting

- **TLS / HTTPS errors** (corporate TLS inspection) — Point `NODE_EXTRA_CA_CERTS` at a PEM file from your IT team and retry.
- **"Certificate has expired"** — Try `apiiro login --no-merge-system-ca`.
- **macOS: keychain export slow or failing** — Raise `APIIRO_CA_EXPORT_TIMEOUT_MS` / `APIIRO_CA_EXPORT_MAX_BUFFER_BYTES`, or set `APIIRO_FORCE_SECURITY_EXPORT=1`.

## Documentation

Full documentation is available at [docs.apiiro.com](https://docs.apiiro.com).

## License

Use of the Apiiro CLI is subject to the [Developer Tools EULA](https://github.com/apiiro/marketplace/blob/main/Apiiro%20Developer%20Tools%20EULA.pdf).
