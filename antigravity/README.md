# Apiiro Guardian

Apiiro brings your organization's application security context into Antigravity. Ask which risks matter in a repository, from vulnerable dependencies and exposed secrets to sensitive data flowing through APIs, prioritized by Apiiro's risk graph. Before writing a feature, get the task rewritten with security requirements specific to that repository and your organization's policies. Get remediation guidance or start Apiiro Autofix for a risk, scan changed files for secrets and vulnerable dependencies, and look up any CVE or open-source package version.

Requires an Apiiro account; you see only the repositories and risks your Apiiro role allows.

## Setup

The plugin connects to the hosted Apiiro MCP server at `https://mcp.apiiro.com/mcp`. There is nothing to configure and no API key to paste: when the server first connects, Antigravity opens the Apiiro sign-in page in your browser. To sign in again in the Antigravity App, open **Customizations > Installed** and click **Authenticate** next to the Apiiro server.

## What's included

- **MCP server:** Apiiro tools for risks, inventory, policies, scans, pull requests, OSS and CVE lookups, secure-prompt enrichment, and Autofix.
- **Rules:** always-on guidance on when to call Apiiro, and a requirement to confirm before any tool that changes your Apiiro tenant or repositories.

## Links

- Documentation: https://docs.apiiro.com
- Support: https://support.apiiro.com
- Privacy Policy: https://apiiro.com/privacy-policy/
- License: [Apiiro Developer Tools EULA](https://github.com/apiiro/marketplace/blob/main/Apiiro%20Developer%20Tools%20EULA.pdf)
