# Apiiro CLI

Command-line interface for the [Apiiro](https://apiiro.com) platform — security scanning, risk analysis, and AI-powered queries.

## Installation

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
brew tap apiiro/tap && brew install apiiro
```

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
sudo yum install -y https://github.com/apiiro/marketplace/releases/latest/download/apiiro-<version>.x86_64.rpm
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

Bundles all skills plus security hooks. In Claude Code:

```
/plugin marketplace add apiiro/marketplace
/plugin install apiiro@apiiro
```

Then ask Claude to "set up Apiiro" — the bundled `apiiro-setup` skill installs the CLI and walks you through authentication.

### Agent Skills (any assistant)

Install skills for AI coding assistants (Claude Code, Cursor, etc.) using [Vercel Skills](https://github.com/vercel-labs/skills):

```bash
npx skills add apiiro/marketplace
```

Available skills: `apiiro-risks`, `apiiro-fix`, `apiiro-guardian`, `apiiro-threat-model`, `apiiro-fast-scan`, `apiiro-diff-scan`, `apiiro-secure-prompt`.

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

Quick local scanning for secrets and OSS vulnerabilities. Auto-detects changed files in the current git repo. Agent skill: `apiiro-fast-scan`.

```bash
apiiro fast-scan secrets            # Scan for secrets
apiiro fast-scan secrets --staged   # Scan staged files only (pre-commit)
apiiro fast-scan secrets --full     # Scan entire file, not just git-changed lines
apiiro fast-scan oss                # Scan for OSS vulnerabilities
apiiro fast-scan all                # Run both concurrently
apiiro fast-scan config             # Get scan configuration
```

### Diff Scan

Compare two git references for security risks. Primary CI/CD integration point. Agent skill: `apiiro-diff-scan`.

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

List and inspect risks for a repository. Agent skills: `apiiro-risks` (list/inspect), `apiiro-fix` (remediate).

```bash
apiiro risks                                     # List all risks (auto-detects repo)
apiiro risks --repo my-repo-name                 # Specify repo (defaults to its default branch)
apiiro risks --repo my-repo-name --branch dev    # Target a specific monitored branch
apiiro risks --repository-id <repo-id>           # Specify repo (branch) by ID
apiiro risks --risk-level Critical               # Filter by risk level
apiiro risks --risk-category "API Security"      # Filter by category
apiiro risks get <risk-id>                       # Get risk details
apiiro risks remediate <risk-id>                 # Get remediation instructions
```

> When a repository has multiple monitored branches, each branch is a separate
> profile with its own ID. `--repo` resolves to the **default branch** by
> default; use `--branch <name>` (or `--repository-id <id>`) to pin a specific
> branch so results are reproducible.

### Inventory

List inventory items (APIs, dependencies, sensitive data, secrets) for a repository or application. Requires a scope (auto-detected from git, or one of the explicit flags).

```bash
apiiro inventory                                 # Auto-detect repo from git
apiiro inventory --repo my-repo-name             # Specify repo (defaults to its default branch)
apiiro inventory --repo my-repo-name --branch dev # Target a specific monitored branch
apiiro inventory --repository-id <repo-id>       # Specify repo (branch) by ID
apiiro inventory --application-id <app-id>       # Scope to an application
apiiro inventory --entity-type API               # APIs only
apiiro inventory --entity-type Dependency        # Dependencies only
apiiro inventory --entity-type Secret            # Secrets only
apiiro inventory --entity-type SensitiveData     # Sensitive data only
apiiro inventory --repo my-repo -o json          # JSON output
apiiro inventory --repo my-repo --max-pages -1   # Fetch every page (default cap: 5)
```

### Threat Model

Perform STRIDE-based threat analysis on feature specs, requirements, or architectural changes. Agent skill: `apiiro-threat-model`.

```bash
apiiro threat-model "Add REST API for file uploads to S3"
apiiro threat-model "Implement OAuth2 with PKCE" --title "Auth redesign"
apiiro threat-model "Add webhook support" -o json
apiiro threat-model "Migrate sessions to JWT" -f threat-report.md
```

### Guardian (AI Agent)

Query Apiiro's AI agent for security analysis and insights. Agent skill: `apiiro-guardian`.

```bash
apiiro guardian query "what risks exist in this repo"
apiiro guardian query "deep analysis of auth flow" --model normal
apiiro guardian query "what is STRIDE?" --global
apiiro guardian query "detailed analysis" --timeout 120
apiiro guardian query "what risks exist here" --remote gh   # detect via a non-origin remote
```

The repo is detected from the `origin` remote, or the first remote if there's no `origin`. Use `--remote <name>` to choose a specific remote, or `--repository-key <key>` to set it explicitly.

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
- `--no-merge-system-ca` — Skip the TLS **retry** path (no second HTTPS attempt with merged OS CA material: native system store, macOS keychains, Linux PEM bundles, Windows root store export, plus bundled roots). Every request uses Bun’s default trust only. Use if you hit issues such as **certificate has expired** from merged roots. Place the flag **before or after** the subcommand (e.g. `apiiro --no-merge-system-ca login` or `apiiro login --no-merge-system-ca`).

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_EXTRA_CA_CERTS` | Optional PEM path: contents are **appended** to the retry CA bundle after the first HTTPS attempt fails with a TLS trust error (alongside OS + bundled roots), unless `--no-merge-system-ca` is set. | — |
| `APIIRO_CA_EXPORT_TIMEOUT_MS` | Timeout (ms) for OS CA subprocess I/O (macOS `security`, Windows PowerShell). Default 3 minutes, max 20. `CA_EXPORT_TIMEOUT_MS` is used only if unset. | `180000` |
| `APIIRO_CA_EXPORT_MAX_BUFFER_BYTES` | Max subprocess stdout bytes when building the merged PEM. Default 100MB. `CA_EXPORT_MAX_BUFFER_BYTES` is used only if unset. | `104857600` |
| `APIIRO_FORCE_SECURITY_EXPORT` | macOS: `1`/`true`/`yes`/`on` forces `security` export from both System keychains, skipping native `tls.getCACertificates('system')` for the OS portion. | — |

## Troubleshooting

- **TLS / HTTPS errors** (`unable to verify the first certificate`, corporate TLS inspection) — Point `NODE_EXTRA_CA_CERTS` at a PEM file from your IT team, then retry. The CLI prefers Bun’s default trust first and only merges OS and extra roots after a qualifying TLS failure (unless `--no-merge-system-ca`).
- **"Certificate has expired"** after an upgrade or on strict networks — Try `apiiro login --no-merge-system-ca` so only the runtime default trust store is used on the first attempt.
- **macOS: keychain export slow, incomplete native CAs, or failing** — Increase `APIIRO_CA_EXPORT_TIMEOUT_MS` / `APIIRO_CA_EXPORT_MAX_BUFFER_BYTES`, or set `APIIRO_FORCE_SECURITY_EXPORT=1` (see table).

## Documentation

Full documentation is available at [docs.apiiro.com](https://docs.apiiro.com).

## License

Use of the Apiiro CLI is subject to the [Developer Tools EULA](https://github.com/apiiro/marketplace/blob/main/Apiiro%20Developer%20Tools%20EULA.pdf).
