---
name: guardian-threat-model
description: |
  Apiiro CLI command for STRIDE-based threat modeling: analyze feature specs, requirements, or architectural changes for security threats. Use this skill whenever the user wants a threat model, threat analysis, STRIDE analysis, or security review of a design or feature spec before implementation. Also trigger when they ask "what are the threats in this design", "threat model this feature", "what could go wrong with this approach", "is this architecture secure", or want to understand the security implications of a proposed change. This is different from guardian (which answers freeform security questions about existing code) — use threat-model when the user has a design, spec, or feature description they want analyzed for threats.
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
