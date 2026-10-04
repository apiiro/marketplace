# Apiiro CLI - Jamf Deployment

For a fleet rollout, deploy the public CLI directly from its release assets. No PKG,
Homebrew, npm, or custom binary is required. The policy installs the architecture-specific binary at
`/opt/apiiro/bin/apiiro`, owned by root, and configures the logged-in user's skills
and hooks without changing unrelated integrations.

Use the scripts from the same approved release as the CLI. Older releases such as
1.7.0 predate this deployment flow and must not be paired with these scripts.

## Policy Setup

1. Download `jamf/policy-install-integrations.sh` and optionally
   `jamf/extension-attribute.sh` from the approved release tag in
   [the public repository](https://github.com/apiiro/marketplace).
2. Add the policy script under Settings > Computer Management > Scripts.
   Leave packages empty for the default published-release flow.
3. Configure the parameters below, and scope the policy to the initial team.
   Explicitly exclude computers whose users have opted out.
4. Enable Login and Recurring Check-in triggers. Use Once per user per computer
   with bounded automatic retries on failure. A run without a logged-in user
   fails so it is not mistaken for completed user setup.
5. Configure the optional Extension Attribute as a String with Script input.

| Parameter | Purpose | Default |
|-----------|---------|---------|
| 4 | Agent targets: `claude`, `cursor`, `copilot`, `codex`, or `all` | `claude` |
| 5 | Optional HTTPS tenant API URL | CLI default |
| 6 | Required exact approved CLI version, without `v` | None |
| 7 | Feature profile: `secure-prompt` or `all` | `secure-prompt` |
| 8 | Binary source: `published` or `pkg` | `published` |

The `secure-prompt` profile enables prompt enrichment and disables commit scans,
prompt secret scanning, and session enrichment. SessionStart authentication remains
active. Prompt enrichment is supported by Claude Code and OpenAI Codex; Cursor and
Copilot cannot inject context into each prompt, so start this profile with Claude.
The `all` profile enables the release's public prevention capabilities, not preview
scanner features.

The policy verifies `checksums.txt` from the pinned public release before executing
or replacing the CLI. It fails on missing or invalid checksums, unsupported
architecture, invalid parameters, or conflicting writable/symlinked installation
paths. An existing binary is reused only when its checksum matches the approved
release, not merely because its version string matches.

## Package Iterations

Use `pkg` for an explicitly approved package build during short iterations. Attach
the PKG to the policy and run it before the configuration script. It must install
the native CLI at `/opt/apiiro/bin/apiiro`, with root ownership and non-writable
managed paths, and support the direct Claude user hooks used by this policy.
Parameter 6 must match the package binary's exact version.

In `pkg` mode the script performs no release download and does not replace the
package's binary. Package integrity is supplied by the approved package/Jamf
distribution process, not the public release's checksum. Hook configuration and
feature profiles work the same way in both modes. A failed published download never
falls back to a package build.

Keep package iteration and published rollout policies scoped separately, or disable
one before switching the same Mac between them. Both use the same binary path;
concurrent policies can overwrite or downgrade one another. Use `published` for
the team rollout and retain the package policy for deliberate iterations.

## Authentication And Hooks

Claude hooks are configured in the console user's `~/.claude/settings.json`.
The policy removes Apiiro's duplicate plugin/managed hook sources while preserving
other plugins and hooks. It installs skills without enabling additional hook
sources. Cursor, Copilot, and Codex use their supported managed settings surfaces
when selected. The deployment assumes the default Claude configuration directory;
custom profiles require a separate explicitly configured policy.

Each user authenticates with their own Apiiro account. The Claude SessionStart hook
opens login when credentials are missing; this is not silent service-account login.
If browser login cannot complete, follow the CLI's device-login instructions.
Restart existing Claude sessions after setup. A successful installation does not
prove authentication or actual prompt enrichment.

For staged migrations, retain repo hooks until native Secure Prompt delivery has
been verified. Remove duplicate repo hooks or use the repository's supported
per-user opt-out during the pilot; this generic policy does not modify repositories
or their private hook settings.

## Verification And Upgrades

- Inspect the per-computer Jamf log for successful binary verification, selected
  hook scope, and configuration completion.
- Run `/opt/apiiro/bin/apiiro doctor --ea` as the user. Verify version,
  authentication, `claude_hook_scope=user`, and the intended disabled capabilities.
  The Extension Attribute also reports missing binaries and pending user setup.
- Start a fresh Claude session and verify a real coding prompt receives enrichment.
  Confirm the intended tenant and that no scans execute under `secure-prompt`.
- Run the policy twice on a canary and verify it converges without replacing the
  verified binary or creating duplicate hooks. Test fresh login, not only cached auth.
- Expand scope only after this evidence is present on a second managed Mac.

For an upgrade or profile change, update the version/profile and deliberately
schedule a new policy run. Changing a Once-per-user policy's parameters does not
rerun already-completed installs. Keep prior version/profile values for rollback;
the policy pins both upgrades and deliberate downgrades to verified release assets.

Unsigned release binaries may be acceptable for an approved internal pilot.
Checksum verification establishes integrity relative to the release, not Apple
Developer ID signing or notarization. Confirm your fleet's execution requirements
before a company-wide deployment.
