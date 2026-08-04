# Apiiro Guardian CLI

Command-line interface for the [Apiiro](https://apiiro.com) Guardian Agent — discover inventory, assess risk, detect vulnerabilities, fix risk, and prevent risk.

## Installation

### One-line install (macOS / Linux / Windows)

Downloads the right binary for your platform, verifies its checksum, installs it to a user directory (no sudo), and wires Apiiro into any coding agents you already have.

```bash
# macOS / Linux
curl -fsSL https://apiiro.com/install.sh | bash
```

```powershell
# Windows (PowerShell)
irm https://apiiro.com/install.ps1 | iex
```

Environment overrides: `APIIRO_INSTALL_DIR`, `APIIRO_VERSION`, `APIIRO_NO_MODIFY_PATH`.

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

### Homebrew (macOS / Linux)

```bash
brew tap apiiro/tap
brew trust apiiro/tap    # required on Homebrew 6.0+
brew install apiiro
```

> Homebrew 6.0+ refuses formulae from untrusted third-party taps, so the one-time `brew trust` step is
> required. Trust the **tap**, not the individual formula — trusting only `apiiro/tap/apiiro` leaves
> Homebrew erroring on the tap's other formula (`apiiro-latest`) in later commands.

### Direct Download

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

### RPM (Linux)

```bash
sudo yum install -y https://github.com/apiiro/marketplace/releases/latest/download/apiiro-<version>-1.x86_64.rpm
```

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

### Claude Code Plugin

Bundles all Apiiro skills. In Claude Code:

```
/plugin marketplace add apiiro/marketplace
/plugin install apiiro@apiiro
```

Then ask Claude to "set up Apiiro" — the bundled `guardian-setup` skill installs the CLI and walks you through authentication.

The `apiiro` plugin ships skills only. Prevention hooks (prompt security enrichment and pre-commit secret scanning) are a separate, opt-in plugin — `/plugin install apiiro-prevention@apiiro` (same in Cursor).

### Agent Skills (any assistant)

If you have the CLI installed, it can write the skills into every coding agent it detects (Claude Code, Cursor, GitHub Copilot, Codex) — skills only, prevention hooks stay opt-in:

```bash
apiiro agents install     # or: status / uninstall
```

Or install the skills directly with [Vercel Skills](https://github.com/vercel-labs/skills), no CLI required:

```bash
npx skills add apiiro/marketplace
```

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

Alternatively, set the `API_KEY` environment variable.

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

Git pre-commit hook for automatic security scanning.

```bash
apiiro hooks pre-commit install     # Install pre-commit hook
apiiro hooks pre-commit status      # Check hook status
apiiro hooks pre-commit uninstall   # Remove hook
```

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
