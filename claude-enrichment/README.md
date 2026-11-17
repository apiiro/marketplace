# Guardian Enrichment

Shows what Apiiro Guardian's secure-prompt hook added to your prompt, in the Claude Code terminal and desktop app.

When Guardian adds security requirements to a prompt, a band above the prompt names the topics it added (for example Authentication, Data Storage). Details expands the full requirements in place; Close hides the band until the next enrichment. In the terminal the chords are `ctrl+x ↑` (details), `ctrl+x ↓` (hide) and `ctrl+x x` (close). The status line counts the session's enriched prompts, and `/guardian-enrichment` lists the latest 20.

## Setup

1. Install the Apiiro CLI 1.10.1 or later and install the Claude Code hooks (`apiiro hooks claude install`), or use the marketplace steps below.
2. Register the marketplace once: `/plugin marketplace add apiiro/marketplace`.
3. If using marketplace hooks, install the prevention plugin: `/plugin install apiiro-prevention@apiiro`.
4. Install the plugin: `/plugin install guardian-enrichment@apiiro`.
5. Turn on the enrichment log: `apiiro hooks config enable preventLog`.

The plugin reads the log the CLI writes under `~/.apiiro/prevent-log/`, one file per session. The log is off by default because it contains the first 200 characters of each enriched prompt and the security context added to it. Entries are redacted, retained for seven days, and readable by local processes running as your user. The plugin code makes no network requests. Claude Code may persist or sync plugin state according to its own host settings; the plugin state includes recent redacted event excerpts and UI state.

## Options

- Toast on each enrichment: also raise a toast each time Guardian enriches a prompt. Off by default.
