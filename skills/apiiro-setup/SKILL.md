---
description: Install Apiiro CLI, authenticate, verify version, check available features, and configure hooks
user_invocable: true
---

You are setting up Apiiro. Do the following in order and confirm each step:

## 1. Install Apiiro CLI

- Check if installed: `which apiiro`
- If already installed, skip to step 2
- Detect the user's OS and offer the appropriate install method:

**macOS (Homebrew):**
```bash
brew tap apiiro/tap && brew install apiiro
```

**Linux (Homebrew):**
```bash
brew tap apiiro/tap && brew install apiiro
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

## 3. Verify authentication

- Run: `apiiro auth status`

## 4. Check version compatibility

- Compare installed version (`apiiro --version`) with minimum required version 1.2.0
- If older, upgrade using the same method used to install

## 5. Check available features

Probe which features are enabled for the user's environment. Run these commands and collect results:

```bash
# Fast Scan — secrets
apiiro fast-scan secrets --file /dev/null 2>&1

# Fast Scan — OSS
apiiro fast-scan oss --file /dev/null 2>&1

# Guardian
apiiro guardian query "test" 2>&1

# Threat Modeling
apiiro threat-model --content "test" 2>&1
```

For each command, check the output:
- If it contains "not enabled" → the feature is **not available** in this environment
- Otherwise → the feature is **available**

Present a summary table to the user showing which features are enabled and which are not. For disabled features, note: "Contact your Apiiro administrator to enable this feature."

## 6. Review automatic hooks

The Apiiro plugin includes automatic hooks that run in the background during IDE sessions. **All hooks are on by default.**

The available hooks depend on the IDE:

### Claude Code hooks

| Hook | Config key | What it does |
|------|-----------|--------------|
| **PreToolUse** (Bash) | `disablePreCommitScan` | Scans changed files for secrets and OSS vulnerabilities before `git commit` |
| **UserPromptSubmit** | `disablePromptSecretScan` | Blocks prompts that contain secrets (runs before enrich-prompt) |
| **UserPromptSubmit** | `disableEnrichPrompt` | Enriches security-relevant prompts with context |
| **SessionStart** / **PostCompact** | `disableEnrichSession` | Injects repository security posture at session start and after context compaction |

### Cursor hooks

| Hook | Config key | What it does |
|------|-----------|--------------|
| **beforeSubmitPrompt** | *(always on)* | Sends prompt to Apiiro for security analysis |
| **preToolUse** (Shell) | `disablePreCommitScan` | Scans changed files for secrets before `git commit` |
| **sessionStart** | `disableEnrichSession` | Injects repository security posture at session start |

Show the current hook status:
```bash
apiiro hooks config
```

To disable hooks if the user wants to opt out:
```bash
# Disable all hooks at once
apiiro hooks config disable all

# Or disable individually
apiiro hooks config disable disablePreCommitScan
apiiro hooks config disable disablePromptSecretScan
apiiro hooks config disable disableEnrichSession
# Claude Code only:
apiiro hooks config disable disableEnrichPrompt
```

Explain to the user what each hook does and ask if they'd like to disable any. Use `--project` flag if they want project-level config instead of global.

## 7. Offer status line setup (Claude Code only)

Apiiro can add a 🛡️ shield to the Claude Code status line that appears when Apiiro Guardian is active.

**Do NOT modify `~/.claude/settings.json` or any scripts directly.** Instead, explain what the status line does and ask the user if they'd like to set it up. If they agree, use the `statusline-setup` agent to configure it.

Tell the user:
- The shield icon (🛡️) appears in the Claude Code status line when Apiiro Guardian is active in the current session
- It requires adding a `statusLine` entry to `~/.claude/settings.json`
- If they already have a custom status line, the Apiiro check will be appended to their existing script (a backup of the original script will be created first)

If the user wants to proceed, delegate to the `statusline-setup` agent with these details:

### Case A: No existing status line

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
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

## 8. Done

Tell the user they are all set! Summarize:
- Which features are available in their environment
- Which hooks are now enabled
- Available security skills: scan, risks, guardian, secure-prompt, threat-model, fix
