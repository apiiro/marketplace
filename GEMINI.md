# Apiiro Guardian

This extension connects Gemini CLI to the hosted Apiiro MCP server (`https://mcp.apiiro.com/mcp`). Its `apiiro_*` tools answer from the user's own Apiiro tenant: risks and findings, code inventory (APIs, dependencies, sensitive data), policies, scans, pull requests, and Autofix.

## Sign-in

The server uses OAuth. On first use Gemini CLI opens the Apiiro sign-in page in a browser. If a tool call fails with an authentication error, ask the user to run `/mcp auth apiiro`. Never ask for, print, or store an Apiiro API key or token.

## When to use the tools

- Before implementing a new feature, API change, authentication or authorization logic, data model change, or service integration, call `apiiro_secure_prompt` with the task and the `git remote get-url origin` URL. Apply any returned `enrichment` as extra requirements. An empty enrichment means there is nothing to add.
- For questions about known risks in the current repository, find its repository key with `apiiro_repositories`, then call `apiiro_risks`.
- For what a repository contains (APIs, dependencies, PII, technologies), use `apiiro_inventory`.
- For open-ended security questions, use `apiiro_ask`.

## Changes need the user's confirmation

`apiiro_risks_update`, `apiiro_autofix_trigger`, and `apiiro_scans_trigger` change state in the user's Apiiro tenant or repositories. Say what will change and get a clear yes before calling them.

Do not paste tenant data, findings, or secrets into commits, public issues, or pull request descriptions unless the user asks.

## More

- Apiiro Guardian CLI and other agents: https://github.com/apiiro/marketplace
- Documentation: https://docs.apiiro.com
- Support: https://support.apiiro.com
- Privacy Policy: https://apiiro.com/privacy-policy/
