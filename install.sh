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
      error "unsupported OS: $os. On Windows use \`irm https://apiiro.com/install.ps1 | iex\`." ;;
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
# PATH configuration — patch every common shell's startup file, not just the
# one $SHELL points at. A machine with zsh as the login shell but bash also
# installed (or vice versa) should get `apiiro` on PATH no matter which one a
# given terminal launches.
# ----------------------------------------------------------------------------

# patch_shell_rc <rc-file> <bin-dir> — appends a marked PATH export if the
# dir isn't already referenced there. Prints the rc path and returns 0 when
# it wrote something, returns 1 (silently) when it was already present.
patch_shell_rc() {
  rc="$1"; dir="$2"
  # Key on the dir itself, not just our marker: someone who reran with a
  # different APIIRO_INSTALL_DIR should still get the new dir onto PATH.
  if [ -f "$rc" ] && grep -qF "PATH=\"$dir:" "$rc" 2>/dev/null; then
    return 1
  fi
  mkdir -p "$(dirname "$rc")"
  {
    printf '\n# >>> Apiiro installer >>>\n'
    # shellcheck disable=SC2016  # literal $PATH is intentional — it must expand at shell startup, not now
    printf 'export PATH="%s:$PATH"\n' "$dir"
    printf '# <<< Apiiro installer <<<\n'
  } >> "$rc"
}

# patch_fish_rc <bin-dir> — fish uses fish_add_path, not an export line.
patch_fish_rc() {
  dir="$1"
  rc="$HOME/.config/fish/config.fish"
  if [ -f "$rc" ] && grep -qF "fish_add_path -gP $dir" "$rc" 2>/dev/null; then
    return 1
  fi
  mkdir -p "$HOME/.config/fish"
  printf '\n# >>> Apiiro installer >>>\nfish_add_path -gP %s\n# <<< Apiiro installer <<<\n' "$dir" >> "$rc"
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

  patched=""
  if command -v zsh >/dev/null 2>&1 && patch_shell_rc "$HOME/.zshrc" "$1"; then
    patched="$patched $HOME/.zshrc"
  fi
  if command -v bash >/dev/null 2>&1 && patch_shell_rc "$HOME/.bashrc" "$1"; then
    patched="$patched $HOME/.bashrc"
  fi
  if command -v fish >/dev/null 2>&1 && patch_fish_rc "$1"; then
    patched="$patched $HOME/.config/fish/config.fish"
  fi
  # POSIX fallback so sh-only environments (containers, minimal Linux) still work.
  if patch_shell_rc "$HOME/.profile" "$1"; then
    patched="$patched $HOME/.profile"
  fi

  PATH_MODIFIED="${patched# }"
}

# ----------------------------------------------------------------------------
# Best-effort: wire Apiiro into any coding agents you already have installed.
# Skills only — for skills + prevention hooks together, run `apiiro init` (or
# `apiiro hooks claude install`). No-ops silently on CLI versions that predate
# the command.
# ----------------------------------------------------------------------------
wire_agents() {
  if "$1" agents install >/dev/null 2>&1; then
    status "configured installed coding agents"
  fi
}

# ----------------------------------------------------------------------------
main() {
  PATH_MODIFIED=""

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
    printf '  Added %s to your PATH:\n' "$bin_dir"
    for profile in $PATH_MODIFIED; do
      printf '    %s\n' "$profile"
    done
    # shellcheck disable=SC2016  # showing the user a literal command to copy-paste
    printf '  Open a new terminal, or run:  export PATH="%s:$PATH"\n\n' "$bin_dir"
  fi

  printf '  Next steps:\n'
  printf '    1. apiiro login\n'
  printf '    2. apiiro init     (wires skills + prevention hooks into your coding agents)\n'
  printf '\n'
}

main "$@"
