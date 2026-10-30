# Apiiro CLI - Jamf Deployment

For a fleet rollout, deploy the public CLI directly from its release assets. No PKG,
Homebrew, npm, or custom binary is required. The policy installs the architecture-specific binary at
`/opt/apiiro/bin/apiiro`, owned by root, and configures the logged-in user's skills
and hooks without changing unrelated integrations.

Jamf only installs the CLI. After that, the CLI keeps itself on the version your
organization selects in Apiiro: it downloads that exact release into each user's own
folder (`~/.apiiro/versions`) and runs it, while `/opt/apiiro/bin/apiiro` itself never
changes. To let Jamf manage the version instead, set the Apiiro CLI version setting
to **Off**; the CLI then runs the binary that Jamf installed.

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
| 6 | Required exact CLI version to install, without `v` | None |
| 7 | Feature profile: `secure-prompt` or `all` | `secure-prompt` |
| 8 | Binary source: `published` or `pkg` | `published` |
| 9 | Optional comma-separated 24-32 character hexadecimal OAuth environment IDs; empty leaves authorization unrestricted | Empty |

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

For headless MDM packaging, build with `bun run build:pkg --mdm`. This component
package installs only `/opt/apiiro/bin/apiiro`: no installer UI, PATH changes,
Homebrew cleanup, or bundled uninstaller. It uses the same CLI receipt and binary
path as the interactive package, so the two are alternative delivery methods, not
parallel installations. Signing and notarization requirements still apply; an
explicit `--internal` build is for approved internal iterations only.

## Recurring Drift Repair

Keep binary delivery and hook activation as separate rollout stages. For package
delivery, use a version-scoped install policy; do not attach an Install package to
an Ongoing policy that runs at every check-in.

After the canary passes, create a repair policy using the same configuration
script, exact version, feature profile, tenant restriction, and agent selection.
Use Recurring Check-in with Ongoing frequency, but scope it to a Smart Group of
computers with missing or drifted selected hooks, intersected with the approved
rollout cohort. Preserve explicit opt-out exclusions on both policies. Refresh
inventory on the normal fleet schedule so a later drift can enter the repair group.

For published delivery, the script reuses the binary only after checking the
approved release checksum. For package delivery, select `pkg` without attaching
a package to the repair policy: repair must use the already-delivered approved
binary. Route missing or old package binaries back to the binary delivery policy.
Run the repair policy twice on a canary before enabling recurring execution.

Do not use `healthy=false` alone as the repair criterion: missing authentication
needs user onboarding, not repeated installation. Use the selected agent's hook
scope/status fields and inspect conflicts before attempting repair. Avoid changing
hook command paths on every version bump; retain `/opt/apiiro/bin/apiiro`.

## Deployment Evidence

Keep three distinct checks in rollout reporting:

| Check | Evidence | What it does not prove |
|-------|----------|------------------------|
| Installation | Verified binary, successful configuration log, expected hook scope | User authentication or hook execution |
| Local readiness | Fresh `doctor --ea`, binary hash/version, selected hook status and authentication | Backend delivery or scan completion |
| Runtime | A real agent event correlated with the intended tenant's backend result | Other users or capabilities not exercised |

Jamf Completed means the configuration script succeeded. Inventory submission can
fail independently; its warning must leave the record pending verification until
a later successful recon. Check the Extension Attribute's `collected_at` rather
than treating an old healthy snapshot as current. Never put credentials, prompts,
or scan payloads in Extension Attributes or policy parameters. Do not introduce a
shared Protect token or whole-disk permissions for this hook deployment.

## Authentication And Hooks

Claude hooks are configured in the console user's `~/.claude/settings.json`.
The policy removes Apiiro's duplicate plugin/managed hook sources while preserving
other plugins and hooks. It installs skills without enabling additional hook
sources. Cursor, Copilot, and Codex use their supported managed settings surfaces
when selected. The deployment assumes the default Claude configuration directory;
custom profiles require a separate explicitly configured policy.

Each user authenticates with their own Apiiro account. The Claude SessionStart hook
opens login when credentials are missing; this is not silent service-account login.
Startup sign-in completes before the first prompt proceeds. Existing sessions
can also initiate sign-in on a prompt, and concurrent sessions share one login.
Login is bounded to four minutes; unsuccessful sign-in still blocks the prompt.
When parameter 9 is set, the policy passes the restriction to user-scoped Claude
hook installation and persists it only in Jamf-owned environment settings, so new
authorization requests from that user are limited to the selected environments.
Existing credentials are not changed or retroactively constrained by this filter.
Without an environment restriction, device login can recover from unavailable
browser callbacks. With parameter 9 set, use browser login: device login does not
enforce this restriction and is unavailable.
Restart existing Claude sessions after setup. A successful installation does not
prove authentication or actual prompt enrichment.

For staged migrations, retain repo hooks until native Secure Prompt delivery has
been verified. Remove duplicate repo hooks or use the repository's supported
per-user opt-out during the pilot; this generic policy does not modify repositories
or their private hook settings.

## Verification And Upgrades

- Inspect the per-computer Jamf log for successful binary verification, selected
  hook scope, and configuration completion.
- Run `/opt/apiiro/bin/apiiro doctor --ea` as the user. Verify `installed_version`
  (the version Jamf installed), `version` (the version that runs, which follows the
  Apiiro setting), authentication, `claude_hook_scope=user`, and the intended disabled
  capabilities. The Extension Attribute also reports missing binaries, pending user
  setup, and the automatic-update state (`auto_update`, `auto_update_policy`,
  `auto_update_target`, `auto_update_error`).
- Start a fresh Claude session and verify a real coding prompt receives enrichment.
  Confirm the intended tenant and that no scans execute under `secure-prompt`.
- Run the policy twice on a canary and verify it converges without replacing the
  verified binary or creating duplicate hooks. Test fresh login, not only cached auth.
- Expand scope only after this evidence is present on a second managed Mac.

Upgrades come from the Apiiro CLI version setting, not from Jamf. To roll out a
version, lock it in Apiiro; to go back, lock the earlier version with downgrades
allowed. If the setting is **Off**, upgrade by changing Parameter 6 and deliberately
scheduling a new policy run; changing a Once-per-user policy's parameters does not
rerun already-completed installs. For a profile change, update the profile and
schedule a new run in the same way.

Unsigned release binaries may be acceptable for an approved internal pilot.
Checksum verification establishes integrity relative to the release, not Apple
Developer ID signing or notarization. Confirm your fleet's execution requirements
before a company-wide deployment.
