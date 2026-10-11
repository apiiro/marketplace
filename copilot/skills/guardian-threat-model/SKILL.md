---
name: guardian-threat-model
description: "Use when the user wants an Apiiro STRIDE threat model of a design, spec, or proposed change before implementation (\"threat model this feature\", \"what could go wrong with this design\"). Existing code: guardian-query."
---

# Apiiro Threat Model

Analyze a design, feature spec, or architectural change for security threats using STRIDE methodology. This is for proactive analysis of *proposed* changes — for questions about *existing* code, use the guardian-query skill instead.

## Usage

Pass the content to analyze as the first argument. For longer specs, pipe from a file or use quotes.

```bash
apiiro threat-model "Add a new REST API endpoint that accepts file uploads and stores them in S3"
apiiro threat-model "Implement OAuth2 authorization code flow with PKCE" --title "Auth redesign"
apiiro threat-model "Add webhook support for third-party integrations" -o json
apiiro threat-model "Migrate user sessions from cookies to JWT tokens" -f threat-report.md
```

Options: `-t, --title <title>` (summary of what is analyzed), `-o, --output <json|text>` (default: text), `-f, --file <path>`, `--timeout <seconds>` (default: 360).

Text output returns the analysis directly. JSON output includes `success`, `analysis`, and `error` fields.
