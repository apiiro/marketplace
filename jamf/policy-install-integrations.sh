#!/bin/bash
# Apiiro CLI - Jamf Pro After policy script.
#
# Jamf parameters:
#   $4  space-separated agent targets (default: claude)
#   $5  optional tenant API URL, written to /etc/zshenv
#   $6  required exact public CLI version
#   $7  hook profile: secure-prompt (default) or all
#   $8  binary source: published (default) or pkg
#   $9  optional comma-separated OAuth environment IDs (empty: unrestricted)

set -euo pipefail

log() { echo "[apiiro-integrations] $*"; }

ZSHENV="/etc/zshenv"
PATH_FILE="/etc/paths.d/apiiro"
JAMF_BIN="/usr/local/bin/jamf"
CLI_BIN="/opt/apiiro/bin/apiiro"
TENANT_MARKER="# apiiro-cli tenant config"
AUTH_MARKER="# apiiro-cli internal auth config"
RELEASE_REPO="apiiro/marketplace"
RELEASE_BASE_URL="https://github.com/$RELEASE_REPO/releases/download/v${6:-}"
TENANT_URL=""
OAUTH_ALLOWED_ENVS=""
DOWNLOAD_DIR=""

# Test-only seams. Production keeps the release host and managed path fixed.
if [[ "${APIIRO_TEST_MODE:-}" == "1" ]]; then
  ZSHENV="${APIIRO_TEST_ZSHENV:-$ZSHENV}"
  PATH_FILE="${APIIRO_TEST_PATH_FILE:-$PATH_FILE}"
  JAMF_BIN="${APIIRO_TEST_JAMF_BIN:-$JAMF_BIN}"
  CLI_BIN="${APIIRO_TEST_MANAGED_BIN:-$CLI_BIN}"
  RELEASE_BASE_URL="${APIIRO_TEST_RELEASE_BASE_URL:-$RELEASE_BASE_URL}"
fi

run_as_console_user() {
  local uid="$1" user="$2"
  shift 2
  if [[ "${APIIRO_TEST_MODE:-}" == "1" ]]; then
    HOME="$USER_HOME" USER="$user" LOGNAME="$user" APIIRO_OAUTH_ALLOWED_ENVS="$OAUTH_ALLOWED_ENVS" "$@"
  elif [[ "$(id -u)" -eq 0 ]]; then
    local -a env_args=(USER="$user" LOGNAME="$user" HOME="$USER_HOME" PATH="/opt/apiiro/bin:/usr/local/bin:/usr/bin:/bin")
    [[ -n "$OAUTH_ALLOWED_ENVS" ]] && env_args+=(APIIRO_OAUTH_ALLOWED_ENVS="$OAUTH_ALLOWED_ENVS")
    if [[ -n "$TENANT_URL" ]]; then
      env_args+=(APIIRO_API_URL="$TENANT_URL")
      launchctl asuser "$uid" sudo -u "$user" -H /usr/bin/env -i "${env_args[@]}" "$@"
    else
      launchctl asuser "$uid" sudo -u "$user" -H /usr/bin/env -i "${env_args[@]}" "$@"
    fi
  else
    log "ERROR: managed hook installation must run as root."
    return 1
  fi
}

resolve_home() {
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && -n "${APIIRO_TEST_USER_HOME+x}" ]]; then
    printf '%s' "$APIIRO_TEST_USER_HOME"
    return
  fi
  dscl . -read "/Users/$1" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory: //' || true
}

resolve_console_user() {
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && -n "${APIIRO_TEST_CONSOLE_USER+x}" ]]; then
    printf '%s' "$APIIRO_TEST_CONSOLE_USER"
    return
  fi
  stat -f%Su /dev/console 2>/dev/null || true
}

normalize_user_paths() {
  local user="$1" home="$2" path
  [[ "$(id -u)" -eq 0 ]] || return 0
  for path in "$home/.apiiro" "$home/.claude" "$home/.cursor" "$home/.copilot" "$home/.codex" "$home/.agents"; do
    [[ -e "$path" ]] || continue
    if find "$path" ! -user "$user" -print -quit 2>/dev/null | grep -q .; then
      log "Fixing non-user-owned content under $path"
      chown -R "$user" "$path" || log "WARN: chown failed for $path (non-fatal)"
    fi
  done
}

remove_marker_block() {
  local marker="$1" file="$2"
  [[ -f "$file" ]] || return 0
  awk -v marker="$marker" '
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (lines[i] == marker) {
          skip[i] = 1
          if (i + 1 <= NR) skip[i + 1] = 1
          if (i - 1 >= 1 && lines[i - 1] == "") skip[i - 1] = 1
        }
      }
      for (i = 1; i <= NR; i++) if (!(i in skip)) print lines[i]
    }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

write_tenant_config() {
  local api_url="$1"
  [[ ! -L "$ZSHENV" ]] || { log "ERROR: refusing to follow a symlink for tenant configuration."; return 1; }
  remove_marker_block "$TENANT_MARKER" "$ZSHENV"
  {
    printf '\n'
    printf '%s\n' "$TENANT_MARKER"
    printf 'export APIIRO_API_URL=%q\n' "$api_url"
  } >> "$ZSHENV"
  chmod 0644 "$ZSHENV"
}

write_claude_tenant_env() {
  local uid="$1" user="$2" api_url="$3" settings="$USER_HOME/.claude/settings.json"
  # shellcheck disable=SC2016
  run_as_console_user "$uid" "$user" /bin/bash -c '
    set -eu
    settings="$1"
    api_url="$2"
    state="$HOME/.apiiro/jamf-tenant-url"
    [[ ! -L "$HOME" && ! -L "$HOME/.claude" && ! -L "$settings" && ! -L "$HOME/.apiiro" && ! -L "$state" ]] || exit 21
    mkdir -p "$HOME/.claude" "$HOME/.apiiro"
    temp="$(mktemp "${settings}.jamf.XXXXXX")"
    if [[ -f "$settings" ]]; then cp -p "$settings" "$temp"; else printf "%s\n" '{}' > "$temp"; fi
    /usr/bin/plutil -convert xml1 "$temp" >/dev/null 2>&1 || { rm -f "$temp"; exit 22; }
    /usr/bin/plutil -insert env -dictionary "$temp" >/dev/null 2>&1 || true
    if ! /usr/bin/plutil -replace env.APIIRO_API_URL -string "$api_url" "$temp" >/dev/null 2>&1 &&
       ! /usr/bin/plutil -insert env.APIIRO_API_URL -string "$api_url" "$temp" >/dev/null 2>&1; then
      rm -f "$temp"
      exit 23
    fi
    converted="${temp}.json"
    /usr/bin/plutil -convert json -o "$converted" "$temp" >/dev/null 2>&1 || { rm -f "$temp" "$converted"; exit 24; }
    mode="$(stat -f %Lp "$settings" 2>/dev/null || printf 600)"
    mv "$converted" "$settings"
    chmod "$mode" "$settings"
    rm -f "$temp"
    printf "%s\n" "$api_url" > "$state"
    chmod 600 "$state"
  ' apiiro-tenant-configure "$settings" "$api_url" || {
    log "ERROR: could not persist the tenant URL in Claude settings."
    return 1
  }
}

clear_claude_tenant_env() {
  local uid="$1" user="$2" settings="$USER_HOME/.claude/settings.json"
  # shellcheck disable=SC2016
  run_as_console_user "$uid" "$user" /bin/bash -c '
    set -eu
    settings="$1"
    state="$HOME/.apiiro/jamf-tenant-url"
    [[ ! -L "$HOME" && ! -L "$HOME/.claude" && ! -L "$settings" && ! -L "$HOME/.apiiro" && ! -L "$state" ]] || exit 21
    [[ -f "$state" ]] || exit 0
    owned="$(cat "$state")"
    [[ -f "$settings" ]] || { rm -f "$state"; exit 0; }
    current="$(/usr/bin/plutil -extract env.APIIRO_API_URL raw -o - "$settings" 2>/dev/null || true)"
    if [[ "$current" == "$owned" ]]; then
      temp="$(mktemp "${settings}.jamf.XXXXXX")"
      cp -p "$settings" "$temp"
      /usr/bin/plutil -convert xml1 "$temp" >/dev/null 2>&1 || { rm -f "$temp"; exit 22; }
      /usr/bin/plutil -remove env.APIIRO_API_URL "$temp" >/dev/null 2>&1 || true
      converted="${temp}.json"
      /usr/bin/plutil -convert json -o "$converted" "$temp" >/dev/null 2>&1 || { rm -f "$temp" "$converted"; exit 23; }
      mode="$(stat -f %Lp "$settings" 2>/dev/null || printf 600)"
      mv "$converted" "$settings"
      chmod "$mode" "$settings"
      rm -f "$temp"
    fi
    rm -f "$state"
  ' apiiro-tenant-clear "$settings" || {
    log "ERROR: could not clear the Jamf-owned tenant URL from Claude settings."
    return 1
  }
}

write_claude_oauth_env() {
  local uid="$1" user="$2" allowed="$3" settings="$USER_HOME/.claude/settings.json"
  # shellcheck disable=SC2016
  run_as_console_user "$uid" "$user" /bin/bash -c '
    set -eu
    settings="$1"
    allowed="$2"
    state="$HOME/.apiiro/jamf-oauth-allowed-envs"
    [[ ! -L "$HOME" && ! -L "$HOME/.claude" && ! -L "$settings" && ! -L "$HOME/.apiiro" && ! -L "$state" ]] || exit 21
    mkdir -p "$HOME/.claude" "$HOME/.apiiro"
    if [[ -z "$allowed" ]]; then
      [[ -f "$state" ]] || exit 0
      owned="$(cat "$state")"
      [[ -f "$settings" ]] || { rm -f "$state"; exit 0; }
      temp="$(mktemp "${settings}.jamf.XXXXXX")"
      cp -p "$settings" "$temp"
      /usr/bin/plutil -convert xml1 "$temp" >/dev/null 2>&1 || { rm -f "$temp"; exit 22; }
      current="$(/usr/bin/plutil -extract env.APIIRO_OAUTH_ALLOWED_ENVS raw -o - "$temp" 2>/dev/null || true)"
      if [[ "$current" == "$owned" ]]; then
        /usr/bin/plutil -remove env.APIIRO_OAUTH_ALLOWED_ENVS "$temp" >/dev/null 2>&1 || true
        converted="${temp}.json"
        /usr/bin/plutil -convert json -o "$converted" "$temp" >/dev/null 2>&1 || { rm -f "$temp" "$converted"; exit 23; }
        mode="$(stat -f %Lp "$settings" 2>/dev/null || printf 600)"
        mv "$converted" "$settings"
        chmod "$mode" "$settings"
      fi
      rm -f "$temp"
      rm -f "$state"
      exit 0
    fi
    existing_state=0
    [[ -f "$state" ]] && existing_state=1
    if [[ -f "$settings" && "$existing_state" -eq 1 ]]; then
      owned="$(cat "$state")"
      current="$(/usr/bin/plutil -extract env.APIIRO_OAUTH_ALLOWED_ENVS raw -o - "$settings" 2>/dev/null || true)"
      [[ -z "$current" || "$current" == "$owned" ]] || exit 25
    fi
    if [[ -f "$settings" && "$existing_state" -eq 0 ]]; then
      current="$(/usr/bin/plutil -extract env.APIIRO_OAUTH_ALLOWED_ENVS raw -o - "$settings" 2>/dev/null || true)"
      if [[ -n "$current" ]]; then
        [[ "$current" == "$allowed" ]] && exit 0
        exit 25
      fi
    fi
    temp="$(mktemp "${settings}.jamf.XXXXXX")"
    if [[ -f "$settings" ]]; then cp -p "$settings" "$temp"; else printf "%s\n" '{}' > "$temp"; fi
    /usr/bin/plutil -convert xml1 "$temp" >/dev/null 2>&1 || { rm -f "$temp"; exit 22; }
    /usr/bin/plutil -insert env -dictionary "$temp" >/dev/null 2>&1 || true
    if ! /usr/bin/plutil -replace env.APIIRO_OAUTH_ALLOWED_ENVS -string "$allowed" "$temp" >/dev/null 2>&1 &&
       ! /usr/bin/plutil -insert env.APIIRO_OAUTH_ALLOWED_ENVS -string "$allowed" "$temp" >/dev/null 2>&1; then
      rm -f "$temp"
      exit 23
    fi
    converted="${temp}.json"
    /usr/bin/plutil -convert json -o "$converted" "$temp" >/dev/null 2>&1 || { rm -f "$temp" "$converted"; exit 24; }
    mode="$(stat -f %Lp "$settings" 2>/dev/null || printf 600)"
    mv "$converted" "$settings"
    chmod "$mode" "$settings"
    rm -f "$temp"
    printf "%s\n" "$allowed" > "$state"
    chmod 600 "$state"
  ' apiiro-oauth-env-configure "$settings" "$allowed" || {
    local status=$?
    case "$status" in
      21) log "ERROR: unsafe symlink in the Claude OAuth configuration path." ;;
      22) log "ERROR: Claude settings could not be parsed as JSON (JSON null values are not supported)." ;;
      23|24) log "ERROR: Claude settings could not be updated or serialized." ;;
      25) log "ERROR: Claude OAuth environment setting differs from the Jamf-owned value; preserving the existing setting." ;;
      *) log "ERROR: could not persist the Claude OAuth environment setting (exit $status); check user ownership and write permissions." ;;
    esac
    return 1
  }
}

write_oauth_zshenv_config() {
  [[ ! -L "$ZSHENV" ]] || { log "ERROR: refusing to follow a symlink for OAuth environment configuration."; return 1; }
  remove_marker_block "$AUTH_MARKER" "$ZSHENV"
  [[ -z "$OAUTH_ALLOWED_ENVS" ]] && { [[ -f "$ZSHENV" ]] && chmod 0644 "$ZSHENV"; return 0; }
  {
    printf '\n'
    printf '%s\n' "$AUTH_MARKER"
    printf 'export APIIRO_OAUTH_ALLOWED_ENVS=%q\n' "$OAUTH_ALLOWED_ENVS"
  } >> "$ZSHENV"
  chmod 0644 "$ZSHENV"
}

validate_tenant_url() {
  local value="$1"
  [[ "$value" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$ ]] || {
    log "ERROR: Parameter 5 must be an HTTPS tenant URL."
    return 1
  }
}

validate_version() {
  local value="$1" source="${2:-published}"
  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    log "ERROR: Parameter 6 must be an exact supported public version such as 1.7.1."
    return 1
  }
  case "$source:$value" in
    published:0.*|published:1.[0-6].*|published:1.7.0 )
      log "ERROR: public versions before 1.7.1 do not support this Jamf hook flow."
      return 1
      ;;
  esac
}

validate_binary_source() {
  case "$1" in
    published|pkg) ;;
    *) log "ERROR: Parameter 8 must be published or pkg."; return 1 ;;
  esac
}

validate_allowed_envs() {
  local value="$1" item normalized=""
  local -a items=()
  [[ -z "$value" ]] && { OAUTH_ALLOWED_ENVS=""; return 0; }
  [[ "$value" != ,* && "$value" != *, && "$value" != *,,* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || {
    log "ERROR: Parameter 9 must be a comma-separated list of 24-32 character hexadecimal environment IDs."
    return 1
  }
  IFS=',' read -r -a items <<< "$value"
  for item in "${items[@]}"; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ "$item" =~ ^[a-fA-F0-9]{24,32}$ ]] || {
      log "ERROR: Parameter 9 must be a comma-separated list of 24-32 character hexadecimal environment IDs."
      return 1
    }
    [[ -z "$normalized" ]] || normalized+=','
    normalized+="$item"
  done
  OAUTH_ALLOWED_ENVS="$normalized"
}

resolve_targets() {
  local target_param="$1" token
  local -a tokens=()
  AGENT_FLAGS=()
  SELECTED_AGENTS=()
  [[ -z "$target_param" ]] && target_param="claude"
  IFS=' ' read -r -a tokens <<< "$target_param"
  for token in "${tokens[@]}"; do
    case "$token" in
      claude|cursor|copilot|codex) AGENT_FLAGS+=("--$token"); SELECTED_AGENTS+=("$token") ;;
      all) AGENT_FLAGS+=(--all); SELECTED_AGENTS=(claude cursor copilot codex) ;;
      "") ;;
      *) log "WARN: unknown agent target token '$token' - skipping" ;;
    esac
  done
  if [[ ${#AGENT_FLAGS[@]} -eq 0 ]]; then
    log "ERROR: no valid agent targets resolved from Parameter 4='$target_param'"
    return 1
  fi
}

stat_uid() {
  stat -c %u "$1" 2>/dev/null || stat -f %u "$1"
}

stat_mode() {
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

secure_path() {
  local path="$1" kind="$2" mode uid tail
  [[ ! -L "$path" ]] || { log "ERROR: refusing symlink in managed path: $path"; return 1; }
  [[ -e "$path" ]] || return 1
  if [[ "$kind" == "directory" ]]; then
    [[ -d "$path" ]] || return 1
  else
    [[ -f "$path" ]] || return 1
  fi
  uid="$(stat_uid "$path")"
  mode="$(stat_mode "$path")"
  if [[ "${APIIRO_TEST_MODE:-}" != "1" && "$uid" != "0" ]]; then
    log "ERROR: managed path is not root-owned: $path"
    return 1
  fi
  tail="${mode:${#mode}-3:3}"
  case "${tail:1:1}${tail:2:1}" in
    *2|*3|*6|*7|2*|3*|6*|7*) log "ERROR: managed path is writable by group/other: $path"; return 1 ;;
  esac
}

ensure_secure_directory() {
  local path="$1" parent
  [[ ! -L "$path" ]] || { log "ERROR: refusing symlink in managed path: $path"; return 1; }
  if [[ -e "$path" ]]; then
    secure_path "$path" directory || return 1
    return 0
  fi
  parent="$(dirname "$path")"
  [[ "$parent" != "$path" ]] || { log "ERROR: cannot create managed path: $path"; return 1; }
  ensure_secure_directory "$parent" || return 1
  mkdir "$path" || return 1
  secure_path "$path" directory || return 1
}

ensure_managed_layout() {
  local bin_dir api_dir
  bin_dir="$(dirname "$CLI_BIN")"
  api_dir="$(dirname "$bin_dir")"
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && "${APIIRO_TEST_STRICT_PATHS:-}" != "1" ]]; then
    [[ ! -L "$api_dir" && ! -L "$bin_dir" ]] || { log "ERROR: refusing symlink in managed path."; return 1; }
    mkdir -p "$bin_dir"
  elif [[ "$(id -u)" -ne 0 && "${APIIRO_TEST_MODE:-}" != "1" ]]; then
    log "ERROR: public managed installation must run as root."
    return 1
  else
    ensure_secure_directory "$(dirname "$api_dir")" || return 1
    ensure_secure_directory "$api_dir" || return 1
    ensure_secure_directory "$bin_dir" || return 1
  fi
  secure_path "$api_dir" directory
  secure_path "$bin_dir" directory
}

detect_asset() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os:$arch" in
    Darwin:arm64) printf '%s' "apiiro-macos-arm64" ;;
    Darwin:x86_64)
      if sysctl -n sysctl.proc_translated 2>/dev/null | grep -q '^1$'; then
        printf '%s' "apiiro-macos-arm64"
      else
        printf '%s' "apiiro-macos-x64"
      fi
      ;;
    Linux:x86_64|Linux:amd64) printf '%s' "apiiro-linux-x64" ;;
    Linux:aarch64|Linux:arm64) printf '%s' "apiiro-linux-arm64" ;;
    *) log "ERROR: unsupported platform '$os $arch'."; return 1 ;;
  esac
}

download_file() {
  local url="$1" output="$2"
  if [[ "${APIIRO_TEST_MODE:-}" == "1" ]]; then
    curl -fsSL "$url" -o "$output"
  else
    curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 120 --retry 3 --retry-delay 1 "$url" -o "$output"
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print tolower($1)}'
  else
    log "ERROR: sha256sum or shasum is required for release verification."
    return 1
  fi
}

checksum_for_asset() {
  local checksums="$1" asset="$2"
  awk -v asset="$asset" '
    NF == 2 && length($1) == 64 && $1 !~ /[^[:xdigit:]]/ && ($2 == asset || $2 == "*" asset) {
      count++
      value = tolower($1)
    }
    END {
      if (count != 1) exit 1
      print value
    }
  ' "$checksums"
}

verify_checksum() {
  local file="$1" checksums="$2" asset="$3" expected actual
  expected="$(checksum_for_asset "$checksums" "$asset")" || {
    log "ERROR: checksums.txt must contain exactly one strict SHA-256 entry for $asset."
    return 1
  }
  actual="$(sha256_file "$file")"
  [[ "$actual" == "$expected" ]] || {
    log "ERROR: checksum mismatch for $asset; refusing to install it."
    return 1
  }
}

verify_binary_version() {
  local file="$1" version="$2" actual
  actual="$("$file" --version 2>/dev/null | tr -d '\r\n')"
  [[ "$actual" == "$version" ]] || {
    log "ERROR: downloaded CLI reports '${actual:-unknown}', expected '$version'."
    return 1
  }
}

write_path_file() {
  local path_dir temp
  path_dir="$(dirname "$PATH_FILE")"
  if [[ "${APIIRO_TEST_MODE:-}" == "1" ]]; then
    mkdir -p "$path_dir"
  else
    secure_path "$path_dir" directory
  fi
  if [[ -e "$PATH_FILE" ]]; then secure_path "$PATH_FILE" file; fi
  temp="$(mktemp "$path_dir/apiiro.XXXXXX")"
  printf '%s\n' "$(dirname "$CLI_BIN")" > "$temp"
  chmod 0644 "$temp"
  mv "$temp" "$PATH_FILE"
}

install_public_binary() {
  local version="$1" asset workdir checksums binary expected current_hash
  asset="$(detect_asset)"
  ensure_managed_layout
  DOWNLOAD_DIR="$(mktemp -d "$(dirname "$CLI_BIN")/.apiiro-download.XXXXXX")"
  workdir="$DOWNLOAD_DIR"
  checksums="$workdir/checksums.txt"
  binary="$workdir/$asset"
  trap '[[ -n "${DOWNLOAD_DIR:-}" ]] && rm -rf "$DOWNLOAD_DIR"; DOWNLOAD_DIR=""' EXIT HUP INT TERM

  log "Downloading public Apiiro CLI $version ($asset)"
  download_file "$RELEASE_BASE_URL/checksums.txt" "$checksums" || {
    log "ERROR: could not download release checksums; refusing to install unverified binary."
    return 1
  }
  expected="$(checksum_for_asset "$checksums" "$asset")" || {
    log "ERROR: checksums.txt must contain exactly one strict SHA-256 entry for $asset."
    return 1
  }

  [[ ! -L "$CLI_BIN" ]] || { log "ERROR: refusing symlink at managed CLI path: $CLI_BIN"; return 1; }
  if [[ -e "$CLI_BIN" ]]; then
    secure_path "$CLI_BIN" file
    current_hash="$(sha256_file "$CLI_BIN")"
    if [[ "$current_hash" == "$expected" ]] && verify_binary_version "$CLI_BIN" "$version"; then
      log "Managed CLI already matches the approved public release."
      write_path_file
      return 0
    fi
    log "Existing managed CLI is not the approved public release; replacing it after verification."
  fi

  download_file "$RELEASE_BASE_URL/$asset" "$binary" || {
    log "ERROR: could not download the public CLI release."
    return 1
  }
  chmod 0755 "$binary"
  verify_checksum "$binary" "$checksums" "$asset"
  verify_binary_version "$binary" "$version"
  mv "$binary" "$CLI_BIN"
  secure_path "$CLI_BIN" file
  write_path_file
  log "Installed and verified public Apiiro CLI $version."
}

use_pkg_binary() {
  local version="$1" installed bin_dir api_dir parent_dir
  bin_dir="$(dirname "$CLI_BIN")"
  api_dir="$(dirname "$bin_dir")"
  parent_dir="$(dirname "$api_dir")"
  secure_path "$parent_dir" directory || { log "ERROR: PKG mode requires an existing protected managed parent directory."; return 1; }
  secure_path "$api_dir" directory || { log "ERROR: PKG mode requires an existing protected managed directory."; return 1; }
  secure_path "$bin_dir" directory || { log "ERROR: PKG mode requires an existing protected managed bin directory."; return 1; }
  [[ ! -L "$CLI_BIN" ]] || { log "ERROR: refusing symlink at managed CLI path: $CLI_BIN"; return 1; }
  secure_path "$CLI_BIN" file || { log "ERROR: PKG mode requires an existing protected CLI at $CLI_BIN."; return 1; }
  [[ -x "$CLI_BIN" ]] || { log "ERROR: PKG mode requires an executable CLI at $CLI_BIN."; return 1; }
  installed="$("$CLI_BIN" --version 2>/dev/null | tr -d '\r\n')"
  [[ "$installed" == "$version" ]] || {
    log "ERROR: installed PKG CLI reports '${installed:-unknown}', expected '$version'."
    return 1
  }
  write_path_file
  log "Using the existing verified PKG-installed Apiiro CLI $version."
}

run_root_cli() {
  /usr/bin/env -i HOME=/var/root PATH="/opt/apiiro/bin:/usr/local/bin:/usr/bin:/bin" "$CLI_BIN" "$@"
}

remove_user_hooks() {
  local uid="$1" user="$2" agent output rc=0
  shift 2
  for agent in "$@"; do
    if ! output="$(run_as_console_user "$uid" "$user" "$CLI_BIN" hooks "$agent" uninstall 2>&1)"; then
      log "ERROR: could not remove the user-scoped $agent hooks."
      [[ -n "$output" ]] && printf '%s\n' "$output"
      rc=1
    fi
  done
  return "$rc"
}

find_user_agent_cli() {
  local agent="$1" home="$2" candidate
  for candidate in \
    "$home/.local/bin/$agent" \
    "$home/.$agent/packages/standalone/current/bin/$agent" \
    "/opt/homebrew/bin/$agent" \
    "/usr/local/bin/$agent"; do
    if [[ -x "$candidate" ]]; then printf '%s' "$candidate"; return 0; fi
  done
  return 1
}

remove_user_prevention_plugins() {
  local uid="$1" user="$2" home="$3" agent cli installed output rc=0
  shift 3
  for agent in "$@"; do
    case "$agent" in
      codex)
        if cli="$(find_user_agent_cli codex "$home")"; then
          if ! installed="$(run_as_console_user "$uid" "$user" "$cli" plugin list --json 2>&1)"; then
            log "ERROR: could not inspect the user-scoped Codex plugins."; [[ -n "$installed" ]] && printf '%s\n' "$installed"; rc=1
          elif [[ "$installed" == *"apiiro-prevention@apiiro"* ]] && ! output="$(run_as_console_user "$uid" "$user" "$cli" plugin remove apiiro-prevention@apiiro --json 2>&1)"; then
            log "ERROR: could not remove the user-scoped Codex prevention plugin."; [[ -n "$output" ]] && printf '%s\n' "$output"; rc=1
          fi
        fi
        ;;
      copilot)
        if cli="$(find_user_agent_cli copilot "$home")"; then
          if ! installed="$(run_as_console_user "$uid" "$user" "$cli" plugin list 2>&1)"; then
            log "ERROR: could not inspect the user-scoped Copilot plugins."; [[ -n "$installed" ]] && printf '%s\n' "$installed"; rc=1
          elif [[ "$installed" == *"apiiro-prevention@apiiro"* ]] && ! output="$(run_as_console_user "$uid" "$user" "$cli" plugin uninstall apiiro-prevention@apiiro 2>&1)"; then
            log "ERROR: could not remove the user-scoped Copilot prevention plugin."; [[ -n "$output" ]] && printf '%s\n' "$output"; rc=1
          fi
        fi
        ;;
    esac
  done
  return "$rc"
}

verify_hook_scopes() {
  local uid="$1" user="$2" agent report expected key actual doctor_rc=0 rc=0
  shift 2
  if report="$(run_as_console_user "$uid" "$user" "$CLI_BIN" doctor --ea 2>&1)"; then doctor_rc=0; else doctor_rc=$?; fi
  [[ -n "$report" ]] || { log "ERROR: could not verify the installed hook scopes."; return 1; }
  for agent in "$@"; do
    case "$agent" in
      claude) key="claude_hook_scope"; expected="user" ;;
      cursor) key="cursor_hook_scope"; expected="managed" ;;
      copilot) key="copilot_hook_scope"; expected="managed" ;;
      codex) key="codex_hook_scope"; expected="managed" ;;
    esac
    actual="$(printf '%s\n' "$report" | awk -F= -v key="$key" '$1 == key { print $2; exit }')"
    if [[ "$actual" != "$expected" ]]; then
      log "ERROR: $agent hook scope is '${actual:-missing}', expected '$expected'."; rc=1
    fi
  done
  if [[ "$rc" -ne 0 ]]; then printf '%s\n' "$report"; else log "Verified hook scopes for: $*"; [[ "$doctor_rc" -ne 0 ]] && log "WARN: apiiro doctor reported an issue outside the selected agent scope (non-fatal)."; fi
  return "$rc"
}

install_hooks() {
  local uid="$1" user="$2" agent rc=0
  shift 2
  for agent in "$@"; do
    case "$agent" in
      claude) run_root_cli hooks claude uninstall --system --direct >/dev/null 2>&1 || true; run_as_console_user "$uid" "$user" "$CLI_BIN" hooks claude install --direct || rc=1 ;;
      cursor) run_root_cli hooks cursor install --system || rc=1 ;;
      copilot) run_root_cli hooks copilot install --system || rc=1 ;;
      codex) run_root_cli hooks codex install --system || rc=1 ;;
    esac
  done
  return "$rc"
}

main() {
  local console_user uid user_home target_param profile version_pin binary_source configure_claude_env=0 oauth_env_failed=0 agent
  local -a agent_flags=() selected_agents=()
  console_user="$(resolve_console_user)"
  if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "loginwindow" ]]; then
    log "ERROR: no console user logged in (got '${console_user:-<empty>}'); retry is required."
    exit 1
  fi
  [[ "$(id -u)" -eq 0 || "${APIIRO_TEST_MODE:-}" == "1" ]] || { log "ERROR: public managed installation must run as root."; exit 1; }
  if ! uid="$(id -u "$console_user" 2>/dev/null)"; then log "ERROR: could not resolve uid for console user '$console_user'."; exit 1; fi
  user_home="$(resolve_home "$console_user")"; [[ -z "$user_home" ]] && user_home="/Users/$console_user"; USER_HOME="$user_home"
  binary_source="${8:-published}"; validate_binary_source "$binary_source"
  version_pin="${6:-}"; validate_version "$version_pin" "$binary_source"
  validate_allowed_envs "${9:-}"
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && "${APIIRO_TEST_PATH_ONLY:-}" == "1" ]]; then
    if [[ "$binary_source" == "pkg" ]]; then use_pkg_binary "$version_pin"; else install_public_binary "$version_pin"; fi
    exit 0
  fi
  target_param="${4:-claude}"; resolve_targets "$target_param"; agent_flags=("${AGENT_FLAGS[@]}"); selected_agents=("${SELECTED_AGENTS[@]}")
  for agent in "${selected_agents[@]}"; do [[ "$agent" == "claude" ]] && configure_claude_env=1; done
  if [[ -n "$OAUTH_ALLOWED_ENVS" ]]; then
    for agent in "${selected_agents[@]}"; do
      [[ "$agent" == "claude" ]] || { log "ERROR: Parameter 9 is supported only with Parameter 4 set to claude; $agent cannot persist the OAuth environment restriction."; exit 1; }
    done
  fi
  profile="${7:-secure-prompt}"
  case "$profile" in secure-prompt|all) ;; *) log "ERROR: Parameter 7 must be secure-prompt or all."; exit 1 ;; esac
  TENANT_URL="${5:-}"; if [[ -n "$TENANT_URL" ]]; then validate_tenant_url "$TENANT_URL"; fi
  if [[ "${APIIRO_TEST_MODE:-}" == "1" && "${APIIRO_TEST_TENANT_ONLY:-}" == "1" ]]; then
    if [[ -n "$TENANT_URL" ]]; then write_claude_tenant_env "$uid" "$console_user" "$TENANT_URL"; else clear_claude_tenant_env "$uid" "$console_user"; fi
    exit 0
  fi
  if [[ "$binary_source" == "pkg" ]]; then use_pkg_binary "$version_pin"; else install_public_binary "$version_pin"; fi
  normalize_user_paths "$console_user" "$user_home"
  if [[ -n "$TENANT_URL" ]]; then write_tenant_config "$TENANT_URL"; else remove_marker_block "$TENANT_MARKER" "$ZSHENV"; fi
  if [[ "$configure_claude_env" -eq 1 && ( "${APIIRO_TEST_MODE:-}" != "1" || "${APIIRO_TEST_RUN_USER_SETTINGS:-}" == "1" ) ]]; then
    if [[ -n "$TENANT_URL" ]]; then write_claude_tenant_env "$uid" "$console_user" "$TENANT_URL"; else clear_claude_tenant_env "$uid" "$console_user"; fi
    write_claude_oauth_env "$uid" "$console_user" "$OAUTH_ALLOWED_ENVS" || oauth_env_failed=1
  fi
  write_oauth_zshenv_config
  log "Configuring Apiiro hooks for '$console_user' using profile '$profile'"
  if [[ "$profile" == "secure-prompt" ]]; then
    run_as_console_user "$uid" "$console_user" "$CLI_BIN" hooks config disable all
    run_as_console_user "$uid" "$console_user" "$CLI_BIN" hooks config enable disableEnrichPrompt
  else
    run_as_console_user "$uid" "$console_user" "$CLI_BIN" hooks config enable all
  fi
  log "Running 'apiiro init --non-interactive --skills-only ${agent_flags[*]}' as console user '$console_user'"
  run_as_console_user "$uid" "$console_user" "$CLI_BIN" init --non-interactive --skills-only "${agent_flags[@]}"
  remove_user_hooks "$uid" "$console_user" "${selected_agents[@]}"
  remove_user_prevention_plugins "$uid" "$console_user" "$user_home" "${selected_agents[@]}"
  install_hooks "$uid" "$console_user" "${selected_agents[@]}"
  verify_hook_scopes "$uid" "$console_user" "${selected_agents[@]}"
  if [[ -x "$JAMF_BIN" ]]; then "$JAMF_BIN" recon || log "WARN: jamf recon failed (non-fatal)"; fi
  if [[ "$oauth_env_failed" -ne 0 ]]; then log "ERROR: hooks installed, but the OAuth environment restriction was not persisted in Claude settings."; exit 1; fi
  log "Integrations install complete for '$console_user'."
}

main "$@"
