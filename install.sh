#!/bin/sh
# Apiiro Guardian CLI installer.
#
#   curl -fsSL https://apiiro.com/install.sh | bash
#
# Downloads the right binary for your OS/arch from the latest public release,
# verifies its SHA-256, installs it to ~/.local/bin (no sudo), and points you at
# the next steps. Every line is wrapped in a function and only run from main() at
# the end, so a truncated download can never half-execute.
#
# Environment overrides:
#   APIIRO_INSTALL_DIR    install directory            (default: ~/.local/bin)
#   APIIRO_VERSION        version to install, e.g. 1.5.0 (default: latest)
#   APIIRO_NO_MODIFY_PATH set to 1 to skip editing your shell profile
set -eu

REPO="apiiro/marketplace"

# ----------------------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------------------
status()  { printf '  %s\n' "$*" >&2; }
warn()    { printf '  warning: %s\n' "$*" >&2; }
error()   { printf '\n  error: %s\n\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# Downloader — prefer curl, fall back to wget
# ----------------------------------------------------------------------------
download() {
  # download <url> <output-path>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$1" -O "$2"
  else
    error "need curl or wget to download files"
  fi
}

# ----------------------------------------------------------------------------
# Detect the release asset name for this machine
# ----------------------------------------------------------------------------
detect_asset() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Darwin)
      case "$arch" in
        arm64) echo "apiiro-macos-arm64" ;;
        x86_64)
          # Under Rosetta 2 uname reports x86_64 on Apple Silicon; install native arm64.
          if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
            echo "apiiro-macos-arm64"
          else
            echo "apiiro-macos-x64"
          fi ;;
        *) error "unsupported macOS architecture: $arch" ;;
      esac ;;
    Linux)
      case "$arch" in
        x86_64|amd64)  echo "apiiro-linux-x64" ;;
        aarch64|arm64) echo "apiiro-linux-arm64" ;;
        *) error "unsupported Linux architecture: $arch" ;;
      esac ;;
    *)
      error "unsupported OS: $os. On Windows use \`irm https://apiiro.com/install.ps1 | iex\`, or \`brew install apiiro\`." ;;
  esac
}

# ----------------------------------------------------------------------------
# Verify a file against the release checksums.txt (sha256sum format)
# ----------------------------------------------------------------------------
sha256_of() {
  # sha256_of <file> — prints the hex digest, or nothing if no tool is available
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  fi
}

verify_checksum() {
  # verify_checksum <binary-file> <checksums-file> <asset-name>
  # Fail closed on a missing entry — checksums.txt ships with every release, so
  # its absence means tampering or a blocked request, not a benign gap.
  expected=$(grep " $3\$" "$2" 2>/dev/null | awk '{print $1}' | head -n1)
  if [ -z "$expected" ]; then
    error "no checksum listed for $3 in checksums.txt — refusing to install unverified"
  fi
  actual=$(sha256_of "$1")
  if [ -z "$actual" ]; then
    # The one defensible soft path: the box genuinely has no sha256 tool.
    warn "no sha256 tool (sha256sum/shasum/openssl) available — cannot verify $3"
    return 0
  fi
  if [ "$expected" != "$actual" ]; then
    error "checksum mismatch for $3
    expected: $expected
    actual:   $actual"
  fi
  status "checksum verified"
}

# ----------------------------------------------------------------------------
# Optional: verify the binary's SLSA build-provenance attestation.
# Opt-in (APIIRO_VERIFY_ATTESTATION=1) because it requires the GitHub CLI and
# only works once release provenance is published. When enabled and gh is
# present, a failed verification aborts the install.
# ----------------------------------------------------------------------------
verify_attestation() {
  [ "${APIIRO_VERIFY_ATTESTATION:-0}" = "1" ] || return 0
  if ! command -v gh >/dev/null 2>&1; then
    warn "APIIRO_VERIFY_ATTESTATION=1 but the gh CLI is not installed — cannot verify provenance"
    return 0
  fi
  status "verifying build provenance"
  if ! gh attestation verify "$1" --owner apiiro >/dev/null 2>&1; then
    error "build-provenance verification failed for $1"
  fi
  status "provenance verified"
}

# ----------------------------------------------------------------------------
# PATH configuration — append a marked block to the shell profile if needed
# ----------------------------------------------------------------------------
profile_for_shell() {
  case "${SHELL:-}" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    *)      echo "$HOME/.profile" ;;
  esac
}

ensure_on_path() {
  # ensure_on_path <bin-dir>
  case ":$PATH:" in
    *":$1:"*) return 0 ;;   # already on PATH
  esac

  if [ "${APIIRO_NO_MODIFY_PATH:-0}" = "1" ]; then
    warn "$1 is not on your PATH. Add it manually or re-run without APIIRO_NO_MODIFY_PATH."
    return 0
  fi

  profile=$(profile_for_shell)
  # Key on the dir itself, not just our marker: someone who reran with a
  # different APIIRO_INSTALL_DIR should still get the new dir onto PATH.
  if [ -f "$profile" ] && grep -qF "PATH=\"$1:" "$profile" 2>/dev/null; then
    return 0
  fi
  {
    printf '\n# >>> Apiiro installer >>>\n'
    # shellcheck disable=SC2016  # literal $PATH is intentional — it must expand at shell startup, not now
    printf 'export PATH="%s:$PATH"\n' "$1"
    printf '# <<< Apiiro installer <<<\n'
  } >> "$profile"
  PATH_MODIFIED="$profile"
}

# ----------------------------------------------------------------------------
# Best-effort: wire Apiiro into any coding agents you already have installed.
# Skills only — prevention hooks stay opt-in (`apiiro hooks claude install`).
# No-ops silently on CLI versions that predate the command.
# ----------------------------------------------------------------------------
wire_agents() {
  if "$1" agents install >/dev/null 2>&1; then
    status "configured installed coding agents"
    AGENTS_WIRED=1
  fi
}

# ----------------------------------------------------------------------------
main() {
  PATH_MODIFIED=""
  AGENTS_WIRED=0

  asset=$(detect_asset)

  if [ -n "${APIIRO_VERSION:-}" ]; then
    base_url="https://github.com/${REPO}/releases/download/v${APIIRO_VERSION}"
    label="v${APIIRO_VERSION}"
  else
    base_url="https://github.com/${REPO}/releases/latest/download"
    label="latest"
  fi

  bin_dir="${APIIRO_INSTALL_DIR:-$HOME/.local/bin}"
  target="$bin_dir/apiiro"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  printf '\n  Installing Apiiro CLI (%s, %s)\n\n' "$label" "$asset"

  status "downloading $asset"
  if ! download "$base_url/$asset" "$tmp/apiiro"; then
    error "could not download $asset from $base_url
    Check the version ($label) exists, or see https://github.com/${REPO}/releases"
  fi

  status "fetching checksums"
  if ! download "$base_url/checksums.txt" "$tmp/checksums.txt" 2>/dev/null; then
    error "could not fetch checksums.txt from $base_url — refusing to install unverified"
  fi
  verify_checksum "$tmp/apiiro" "$tmp/checksums.txt" "$asset"

  verify_attestation "$tmp/apiiro"

  chmod +x "$tmp/apiiro"
  mkdir -p "$bin_dir"
  mv "$tmp/apiiro" "$target"
  status "installed to $target"

  if ! "$target" --version >/dev/null 2>&1; then
    error "installation verification failed — $target did not run"
  fi

  ensure_on_path "$bin_dir"
  wire_agents "$target"

  version=$("$target" --version 2>/dev/null || echo "")
  printf '\n  Apiiro CLI %s installed.\n\n' "$version"

  if [ -n "$PATH_MODIFIED" ]; then
    printf '  Added %s to your PATH in %s.\n' "$bin_dir" "$PATH_MODIFIED"
    # shellcheck disable=SC2016  # showing the user a literal command to copy-paste
    printf '  Open a new terminal, or run:  export PATH="%s:$PATH"\n\n' "$bin_dir"
  fi

  printf '  Next steps:\n'
  printf '    1. apiiro login\n'
  if [ "$AGENTS_WIRED" != "1" ]; then
    printf '    2. Add the skills to your agent:\n'
    printf '         Claude Code:  /plugin marketplace add apiiro/marketplace  then  /plugin install apiiro@apiiro\n'
    printf '         Other agents: npx skills add apiiro/marketplace\n'
  fi
  printf '\n'
}

main "$@"
