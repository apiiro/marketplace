#!/bin/sh
set -eu

agent="${1:-}"
action="${2:-}"
case "$agent:$action" in
  codex:session-start|codex:secure-prompt|codex:pre-commit-scan|copilot:session-start|copilot:pre-commit-scan) ;;
  *) echo "[Apiiro] Invalid plugin hook invocation." >&2; exit 0 ;;
esac

apiiro_bin="$(command -v apiiro 2>/dev/null || true)"
for candidate in   "${HOME:-}/.local/bin/apiiro"   "/Library/Application Support/Apiiro/bin/apiiro"   "/usr/local/bin/apiiro"; do
  if [ -z "$apiiro_bin" ] && [ -x "$candidate" ]; then apiiro_bin="$candidate"; fi
done

if [ -z "$apiiro_bin" ]; then
  echo "[Apiiro] CLI not found; skipping plugin hook. Install it and run 'apiiro login'." >&2
  exit 0
fi

exec "$apiiro_bin" hooks "$agent" "$action"
