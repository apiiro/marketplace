---
name: guardian-scan
description: "Use to scan code with the Apiiro CLI for secrets, leaked credentials, or vulnerable OSS dependencies, set up pre-commit hooks, or diff-scan branches and PRs for CI gates (\"check my code before I push\", \"scan this PR\")."
---

# Apiiro Scan

Security scanning via the Apiiro CLI: quick file scans, diff scans, pull-request scans and build scans. Use `apiiro scans <id>` to read existing results. The old `diff-scan` and `fast-scan` names still work for existing integrations.

## Quick Scans

```bash
apiiro scans trigger --type quick --scanners secrets --yes
apiiro scans trigger --type quick src/config.ts --scanners secrets --yes
apiiro scans trigger --type quick --scanners oss package.json bun.lock --yes
apiiro scans trigger --type quick --staged --scanners secrets,oss --yes
apiiro scans trigger --type quick --yes             # All four scanners
apiiro scans --config                              # Quick-scan configuration
```

Scanners: `secrets,oss,ai-sast,iac` (default: all four). Choose one scanner, or include both `secrets` and `oss` with optional `ai-sast` and `iac`. AI SAST can take minutes. Files default to git-changed files; `--staged` reads staged files. Requires a git repository with a remote. Eligibility is checked before uploading file contents. Unmonitored repositories are skipped unless Apiiro allows them for the environment. Skipped scans print a reason.

Triggers ask for confirmation every time. Ask the user before running a write, then pass `--yes` for the agreed command. Quick scans reuse fast-scan output and server verdicts: 0 = clean or could not run, 1 = findings, a server `Block`, or a usage error. A server `Warn` or `Success` allows the scan even with findings. The new commands require sign-in (exit 2 if missing).

`fast-scan` remains available without warnings or confirmation, including `secrets`, `oss`, `all`, `ai-sast`, `iac`, and `config`. Installed hooks and IDE integrations keep using it. Its `--full`, `--fail-on`, `--commit`, and `--base-commit` behavior is unchanged; signed-out scans still skip with exit 0. `fast-scan config` requires sign-in. Pattern scans use a 2-second budget (max 5 via `--timeout`); individual AI SAST and IaC scans use their existing longer budgets.

### Git Hooks

```bash
apiiro hooks pre-commit install                   # Install the pre-commit hook (scans all types)
apiiro hooks pre-commit install --scan-type secrets --force
apiiro hooks pre-commit install --global          # Opt in to the global core.hooksPath directory instead
apiiro hooks pre-commit status
apiiro hooks pre-commit uninstall
```

The pre-commit hook scans staged files; skip it temporarily with `git commit --no-verify`. An existing hook is kept as `pre-commit.pre-apiiro` and runs first; `--force` overwrites it instead. Install also removes the post-commit and post-rewrite hooks earlier versions installed.

## Diff, Pull-request and Build Scans

```bash
apiiro scans trigger -b main -c feature-branch -r https://github.com/org/repo --wait --yes
apiiro scans trigger -b main -c feature-branch --wait-external --wait --yes
apiiro scans trigger -b <base-sha> -c <candidate-sha> --baseline-type Commit --candidate-type Commit --wait --yes
apiiro scans trigger --type pr --pr 42 -r https://github.com/org/repo --wait --yes
apiiro scans trigger --type build --commit <40-character-sha> --branch main --directory src --yes
apiiro scans trigger --type pr --finish-upload <id> --yes
apiiro scans <id>                                  # Diff results
apiiro scans <id> --type pr --wait
apiiro scans <id> --type build
```

Default trigger type: `diff`. Repository URLs auto-detect from git. Diff triggers keep `-i` for interactive reference selection. `--wait-external` and `--finish-upload` support diff and pull-request scans. Build triggers reject `--wait-external`. `--legacy` reads V1 diff or pull-request results. Build results use V2. Build scan commits require 40 hexadecimal characters; uppercase letters are accepted and sent lowercase.

Exit codes: 0 = success/warn or passing build, 1 = blocked/failed/error, 2 = not signed in or results still pending without `--wait`. `--wait` polls for results; `--timeout <seconds>` bounds the wait (default: 300). A timeout exits 1 and prints the scan ID for a later read. The hidden `diff-scan` alias accepts its original flags and runs without confirmation.

## Pull Requests and CI/CD

```bash
apiiro pull-requests --repo <scmRepositoryKey> --status Blocked Pending -o json
apiiro pull-requests --stats --workflow <key> --look-back-days 30
apiiro cicd create --build --commit <40-lowercase-hex-sha> --repo <repositoryKey> --yes
apiiro cicd create --deployment --deployment-id 42 --name production --commit <sha1> <sha2> --repo-version payments=1.2 --yes
```

Pull-request filters: `--repo`, `--status` (`Blocked|Unblocked|Pending|TimedOut`, several allowed), `--workflow`, exact `--server-url`, `--look-back-days` (0–365), ISO `--since`/`--until` (narrow the look-back window). Offset paging defaults to `--page-size 100` (max 1000), `--max-pages 5`; capped results print a note and JSON includes `truncated`.

CI/CD create needs exactly one of `--build` or `--deployment` and asks for confirmation. Builds require one lowercase hexadecimal commit and a repository key; optional flags: `--version`, `--application`, `--build-id`, `--build-url`. Deployments require `--deployment-id` and at least one `--commit` or `--repo-version repo=version`; optional: `--name`, `--url`, multiple `--commit` values. Success prints a message, or `{}` with `-o json`.

## Managed Semgrep

```bash
apiiro semgrep -o json
apiiro semgrep update --git https://github.com/org/rules --yes
apiiro semgrep update --git <url> --provider-repo <key> --yes
apiiro semgrep update --tar rules.tar --yes
```

Choose exactly one of `--git` or `--tar`; `--provider-repo` requires `--git`; updates ask for confirmation and print the server's string message. Archive uploads stream from disk with a 600-second timeout unless `--timeout` overrides it. Configuration can be unavailable when AI SAST scan effort manages the rules.

## Global Options

`-o, --output <json|text>`, `-f, --file <path>`, `--no-color`.
