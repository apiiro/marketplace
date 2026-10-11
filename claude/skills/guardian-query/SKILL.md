---
name: guardian-query
description: "Use for freeform security questions about code (\"is this code secure?\", attack surface, auth flows) or org-wide posture (\"top risks across the org\", --global), answered by the Apiiro Guardian AI agent. One repo's risks: guardian-risks."
---

# Apiiro Guardian

Ask security questions and get AI-powered analysis about your repository.

## Query

Auto-detects the current git repository for context (like `risks` does). No need to specify a repo explicitly — Guardian picks it up from the git remote (`origin`, or the first remote if there's no `origin`). If the repo has several remotes pointing at different providers, target one with `--remote <name>`. If it still shows `[✗ Not Monitored by Apiiro]`, pass the repository key directly with `--repository-key <key>`.

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
apiiro guardian query "detailed analysis" --timeout 120   # wait longer between responses
apiiro guardian query "what risks exist here" --remote gh  # use the 'gh' remote, not origin
apiiro guardian query "risk analysis" -f analysis.md
```

Options: `--model <fast|normal>` (default: `fast`), `-g, --global`, `--remote <name>`, `--repository-key <key>`, `--timeout <seconds>` (default: 60, measured as max inactivity between responses), `-f, --file <path>`.

In TTY mode, a progress spinner shows the agent's status while it works, then the full answer is rendered once as markdown.

## Repository Management

```bash
apiiro guardian repository detect          # Detect and verify repo in Apiiro
apiiro guardian repository clear           # Clear cached repo info
apiiro guardian repository clear --global  # Clear all cached repos
```

Detection results are cached for 24 hours.
