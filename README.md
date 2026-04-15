# Apiiro CLI

Command-line interface for the [Apiiro](https://apiiro.com) platform — security scanning, risk analysis, and AI-powered queries.

## Installation

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

### Agent Skills

Install skills for AI coding assistants (Claude Code, Cursor, etc.) using [Vercel Skills](https://github.com/vercel-labs/skills):

```bash
npx skills add apiiro/marketplace
```

Available skills: `apiiro-risks`, `apiiro-fix`, `apiiro-guardian`, `apiiro-threat-model`, `apiiro-scan`, `apiiro-secure-prompt`.

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

Quick local scanning for secrets and OSS vulnerabilities. Auto-detects changed files in the current git repo. Agent skill: `apiiro-scan`.

```bash
apiiro fast-scan secrets            # Scan for secrets
apiiro fast-scan secrets --staged   # Scan staged files only (pre-commit)
apiiro fast-scan secrets --full     # Scan entire file, not just git-changed lines
apiiro fast-scan oss                # Scan for OSS vulnerabilities
apiiro fast-scan all                # Run both concurrently
apiiro fast-scan config             # Get scan configuration
```

### Diff Scan

Compare two git references for security risks. Primary CI/CD integration point.

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
apiiro risks --repo my-repo-name                 # Specify repo explicitly
apiiro risks --risk-level Critical               # Filter by risk level
apiiro risks --risk-category "API Security"      # Filter by category
apiiro risks get <risk-id>                       # Get risk details
apiiro risks remediate <risk-id>                 # Get remediation instructions
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
- `--no-color` — Disable colored output

## Documentation

Full documentation is available at [docs.apiiro.com](https://docs.apiiro.com).

## License

Use of the Apiiro CLI is subject to the [Developer Tools EULA](https://github.com/apiiro/marketplace/blob/main/Apiiro%20Developer%20Tools%20EULA.pdf).
