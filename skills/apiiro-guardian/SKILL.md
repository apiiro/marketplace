---
name: apiiro-guardian
description: |
  Apiiro CLI commands for querying the Guardian AI agent: ask security questions, get analysis and insights about a repository, and manage repository detection. Use this skill whenever the user wants AI-powered security analysis, security posture review, or wants to ask questions about their codebase's security. Also trigger when they need deep analysis of authentication flows, attack surfaces, or want an AI to explain security concepts. Even without mentioning "apiiro" or "guardian", trigger when the user asks things like "is this code secure?", "what's the attack surface here?", or "explain this vulnerability". For dedicated STRIDE threat modeling of a design or feature spec, use the apiiro-threat-model skill instead. For fixing a known risk, use apiiro-fix.
---

# Apiiro Guardian

Ask security questions and get AI-powered analysis about your repository.

## Query

Auto-detects the current git repository for context (like `risks` does). No need to specify a repo explicitly — Guardian picks it up from the git remote.

**Important:** Before running a query, consider whether the question is repo-specific or org-wide:
- **Repo-specific** (default): questions about the current repo's code, risks, auth flows, dependencies, etc.
- **Org-wide** (`--global`): questions about the org's policies, top risks across all repos, general security posture, or anything not tied to a specific codebase.

If the question is clearly about the org as a whole (e.g. "top risks last week", "what are our policies"), use `--global`. If it's unclear, ask the user: _"Should I scope this to the current repo, or across your whole org?"_

```bash
apiiro guardian query "what risks exist in this repo"
apiiro guardian query "deep analysis of auth flow" --model normal
apiiro guardian query "what is STRIDE?" --global          # General security question
apiiro guardian query "top risks across the org last week" --global
apiiro guardian query "what are our org security policies?" --global
apiiro guardian query "detailed analysis" --timeout 120   # 120s timeout
apiiro guardian query "risk analysis" -f analysis.md
```

Options: `--model <fast|normal>` (default: `fast`), `-g, --global`, `--timeout <seconds>` (default: 60), `-f, --file <path>`.

In TTY mode, responses stream with markdown rendering.

## Repository Management

```bash
apiiro guardian repository detect          # Detect and verify repo in Apiiro
apiiro guardian repository clear           # Clear cached repo info
apiiro guardian repository clear --global  # Clear all cached repos
```

Detection results are cached for 24 hours.
