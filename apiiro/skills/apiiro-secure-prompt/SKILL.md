---
name: apiiro-secure-prompt
description: |
  Apiiro CLI command for enhancing developer prompts with security considerations before coding begins. Takes a coding task description and returns the same task with security requirements injected — preserving the original business intent while adding security guardrails. Use this skill whenever the user wants to improve a coding task with security guidance, add security requirements to a task before starting implementation, or get a security-enhanced version of a prompt. Trigger on phrases like "make this prompt more secure", "add security to my task", "what security should I consider for this feature", or when the user is about to start a coding task and wants security baked in. This is different from threat-model (which produces a full STRIDE analysis report) — secure-prompt enhances a *task description* the user is about to implement.
---

# Apiiro Secure Prompt

Takes a coding task and returns it with security requirements injected. The enhanced prompt preserves the original business intent while adding targeted security considerations based on the repository context.

This is different from `apiiro threat-model` — secure-prompt enhances a task you're about to code, while threat-model produces a standalone STRIDE analysis report.

## Usage

Auto-detects the current git repository for context.

```bash
apiiro guardian secure-prompt "implement user authentication with JWT"
apiiro guardian secure-prompt "add file upload endpoint"
apiiro guardian secure-prompt "build payment processing module" -o json
apiiro guardian secure-prompt "create REST API" --global       # Without repo context
apiiro guardian secure-prompt "implement OAuth flow" -f enhanced.txt
apiiro guardian secure-prompt "build payment module" --force   # Bypass classifier gate
```

Options: `-g, --global`, `--force` (bypass classifier gate), `-o, --output <json|text>` (default: text), `-f, --file <path>`.

Text output returns the original prompt followed by the security requirements (or the prompt unchanged when there's nothing to add). JSON output includes `success`, `enrichment`, `gate_decision`, and `error` fields.
