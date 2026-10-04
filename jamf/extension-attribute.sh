#!/bin/bash
# Apiiro CLI - Jamf Pro Extension Attribute.
# Reports the root-owned CLI and selected integration health.

set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CLI_BIN="/opt/apiiro/bin/apiiro"
if [[ "${APIIRO_TEST_MODE:-}" == "1" ]]; then
  CLI_BIN="${APIIRO_TEST_MANAGED_BIN:-$CLI_BIN}"
fi

emit() { printf '%s=%s\n' "$1" "$2"; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

resolve_console_user() {
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && -n "${APIIRO_TEST_CONSOLE_USER+x}" ]]; then
    printf '%s' "$APIIRO_TEST_CONSOLE_USER"
    return
  fi
  stat -f%Su /dev/console 2>/dev/null || true
}

run_doctor_as_console_user() {
  local user="$1" uid="$2"
  if [[ "$(id -u)" -eq 0 && "${APIIRO_TEST_MODE:-}" != "1" ]]; then
    launchctl asuser "$uid" sudo -u "$user" -H /usr/bin/env -i HOME="$(dscl . -read "/Users/$user" NFSHomeDirectory | sed 's/^NFSHomeDirectory: //')" USER="$user" LOGNAME="$user" PATH="$PATH" "$CLI_BIN" doctor --ea 2>/dev/null
  else
    "$CLI_BIN" doctor --ea 2>/dev/null
  fi
}

main() {
  local console_user uid res
  echo '<result>'
  console_user="$(resolve_console_user)"

  if [[ ! -x "$CLI_BIN" ]]; then
    emit console_user "${console_user:-none}"
    emit status not_installed
    emit collected_at "$(now_utc)"
    echo '</result>'
    exit 0
  fi

  if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "loginwindow" ]]; then
    emit console_user none
    emit status installed_pending_user
    emit binary "$CLI_BIN"
    emit version "$($CLI_BIN --version 2>/dev/null || printf unknown)"
    emit collected_at "$(now_utc)"
    echo '</result>'
    exit 0
  fi
  emit console_user "$console_user"
  if ! uid="$(id -u "$console_user" 2>/dev/null)"; then
    emit status error
    emit collected_at "$(now_utc)"
    emit binary "$CLI_BIN"
    emit reason "cannot_resolve_user:$console_user"
    echo '</result>'
    exit 0
  fi

  res="$(run_doctor_as_console_user "$console_user" "$uid" || true)"
  if [[ -z "$res" ]]; then
    emit status error
    emit collected_at "$(now_utc)"
    emit binary "$CLI_BIN"
    emit reason doctor_no_output
  else
    printf '%s\n' "$res"
  fi
  echo '</result>'
}

main "$@"
