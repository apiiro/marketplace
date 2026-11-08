---
name: guardian-setup
description: "Use to install, update, or authenticate the Apiiro CLI, verify its version and available features, configure IDE and pre-commit hooks, or when an apiiro command fails with not found or auth errors."
---

You are setting up Apiiro. Do the following in order and confirm each step:

## 1. Install Apiiro CLI

- Check if installed: `which apiiro`
- If already installed, skip to step 2
- Detect the user's OS and offer the appropriate install method:

**One-line install (macOS / Linux) — simplest:**
```bash
curl -fsSL https://apiiro.com/install.sh | bash
```
Verifies the checksum, installs to `~/.local/bin` (no sudo), and configures PATH. On Windows (PowerShell): `irm https://apiiro.com/install.ps1 | iex`.

**macOS (Homebrew):**
```bash
brew tap apiiro/tap && brew trust apiiro/tap && brew install apiiro
```

**Linux (Homebrew):**
```bash
brew tap apiiro/tap && brew trust apiiro/tap && brew install apiiro
```

**Linux (RPM/yum):**
```bash
# Get the latest RPM URL (asset name includes the version number)
RPM_URL=$(curl -s https://api.github.com/repos/apiiro/marketplace/releases/latest | grep "browser_download_url.*\.rpm" | cut -d '"' -f 4)
sudo yum install -y "$RPM_URL"
```

**Linux (direct download):**
```bash
curl -fsSL https://github.com/apiiro/marketplace/releases/latest/download/apiiro-linux-x64 -o apiiro
chmod +x apiiro
sudo mv apiiro /usr/local/bin/apiiro
```

**Windows:**
Download `apiiro-win.exe` from https://github.com/apiiro/marketplace/releases

## 2. Authenticate with Apiiro

- Run: `apiiro login`
- This opens a browser window — sign in with your Apiiro account
- If the usual browser sign-in cannot complete (no browser opens, or the local callback is blocked), run `apiiro login --device` and enter the printed code in any browser instead

## 3. Verify authentication

- Run: `apiiro auth status`

## 4. Check for a newer version

- Run: `apiiro update --check`
- The CLI updates itself to the version the organization selects in Apiiro, for every install method (Homebrew and npm included). If a newer version is available, run `apiiro update` to install it now
- If automatic updates are off on this machine (`APIIRO_AUTO_UPDATE=off` or `apiiro update --disable`), say so; `apiiro update --enable` turns them back on

## 5. Check available features

Probe which features are enabled for the user's environment. Run these commands and collect results:

```bash
# Fast Scan (secrets + OSS) — fetches the tenant's scan configuration
apiiro fast-scan config 2>&1

# Guardian
apiiro ask "test" --global 2>&1

# Threat Modeling
apiiro threat-model "test" 2>&1
```

For each command, check the output:
- If it contains "not enabled" → the feature is **not available** in this environment
- Otherwise → the feature is **available**

`-f/--file` is an output flag on every command (it saves the result to a file), so do not pass it to probe a feature.

Present a summary table to the user showing which features are enabled and which are not. For disabled features, note: "Contact your Apiiro administrator to enable this feature."

## 6. Configure prevention hooks

- Run: `apiiro init` — detects Claude Code, Cursor, GitHub Copilot CLI, OpenAI Codex, and opencode, installs the skills and the prevention hooks (session context, prompt enrichment where the host supports it, and commit scanning); then run `apiiro doctor` to verify the result. The Codex and Copilot CLI hooks need a 2026.09.09 or newer CLI — upgrade first if `apiiro --version` is older
- Claude Code, Codex, and opencode enrich each prompt; Cursor and Copilot CLI get session context plus commit scanning, because neither host's prompt hook can inject context
- Codex runs a hook only after it is trusted once: tell the user to run `codex` in a terminal, type `/hooks`, and trust each Apiiro entry. Until then Codex skips the hooks silently, and a changed or newly added entry (for example after `apiiro hooks update`) needs trusting again
- For skills without prevention hooks, run `apiiro agents install` instead (`--agent claude|cursor|copilot|codex|opencode` for one host, `--all` for every known host); `apiiro agents status` shows what is installed
- Restart Claude Code after setup

## 7. Offer status line setup (Claude Code only)

Apiiro can add a 🛡️ shield to the Claude Code status line that appears when Apiiro Guardian is active.

**Do NOT modify `~/.claude/settings.json` or any scripts directly.** Instead, explain what the status line does and ask the user if they'd like to set it up. If they agree, use the `statusline-setup` agent to configure it.

Tell the user:
- The shield icon (🛡️) appears in the Claude Code status line when Apiiro Guardian is active in the current session
- It requires adding a `statusLine` entry to `~/.claude/settings.json`
- If they already have a custom status line, the Apiiro check will be appended to their existing script (a backup of the original script will be created first)

If the user wants to proceed, delegate to the `statusline-setup` agent with these details:

### Case A: No existing status line, or one left by an earlier Apiiro setup

Earlier versions pointed `statusLine.command` at `${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh` or `statusline.ps1`, which the plugin no longer ships, so that status line is now blank. Treat such a command as no status line: replace it with the one below.

Create the script that matches the user's OS, then add the `statusLine` entry to `~/.claude/settings.json`.

**macOS / Linux:** write `~/.claude/apiiro-statusline.sh` and make it executable (`chmod +x`):

```bash
#!/usr/bin/env bash
input=$(cat)
SESSION_ID=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
SESSION_FILE="$HOME/.apiiro/sessions/$SESSION_ID"
MAX_AGE=600
if [ -n "$SESSION_ID" ] && [ -f "$SESSION_FILE" ]; then
  MTIME=$(stat -f %m "$SESSION_FILE" 2>/dev/null || stat -c %Y "$SESSION_FILE" 2>/dev/null || echo 0)
  [ $(($(date +%s) - MTIME)) -lt $MAX_AGE ] && echo "🛡️ Apiiro Guardian Activated"
fi
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/apiiro-statusline.sh"
  }
}
```

**Windows:** write `%USERPROFILE%\.claude\apiiro-statusline.ps1`, then put its absolute path (for example `C:\Users\<name>\.claude\apiiro-statusline.ps1`) in the command:

```powershell
$inputText = [Console]::In.ReadToEnd()
$SessionId = ''
try { $SessionId = ($inputText | ConvertFrom-Json -ErrorAction Stop).session_id } catch { }
if (-not $SessionId) { exit 0 }
$SessionFile = Join-Path $HOME ".apiiro/sessions/$SessionId"
if (Test-Path -LiteralPath $SessionFile -PathType Leaf) {
  $age = (Get-Date).ToUniversalTime().Subtract((Get-Item -LiteralPath $SessionFile).LastWriteTimeUtc).TotalSeconds
  if ($age -lt 600) { Write-Output ([char]::ConvertFromUtf32(0x1F6E1) + [char]0xFE0F + " Apiiro Guardian Activated") }
}
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -ExecutionPolicy Bypass -File \"<absolute path of apiiro-statusline.ps1>\""
  }
}
```

### Case B: User already has a custom status line script

**First, back up the existing script** by copying it to `<script-path>.bak` before making any changes.

Then find the script file referenced in the existing `statusLine.command` setting and append the Apiiro shield check to the **end** of that script. The check should use the same stdin JSON variable the script already captures (commonly `$input`):

```bash
# Apiiro shield
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
SESSION_FILE="$HOME/.apiiro/sessions/$SESSION_ID"
MAX_AGE=600
if [ -n "$SESSION_ID" ] && [ -f "$SESSION_FILE" ]; then
  MTIME=$(stat -f %m "$SESSION_FILE" 2>/dev/null || stat -c %Y "$SESSION_FILE" 2>/dev/null || echo 0)
  [ $(($(date +%s) - MTIME)) -lt $MAX_AGE ] && echo "🛡️ Apiiro Guardian Activated"
fi
```

**Important:** Claude Code pipes a JSON object to the status line script via stdin. The script must read stdin once (e.g., `input=$(cat)`) and parse fields from that variable. Do not read stdin again for the Apiiro check — reuse the existing variable. Check the script to confirm the variable name before appending.

## 8. Verify and finish

- Run: `apiiro doctor` — checks CLI version, auth, per-agent skills, plugin status, hook integrity, pre-commit hook, and hook toggles in one report
- Fix anything it flags before telling the user they are done

Tell the user they are all set! Summarize:
- Which features are available in their environment
- The `guardian-*` skills they can invoke from the agent (ask the agent to list available skills if they want a tour)
