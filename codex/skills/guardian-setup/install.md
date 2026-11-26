# Install Apiiro CLI 1.12.2

Each step downloads one release asset of v1.12.2, checks it against the SHA-256 written here, and installs nothing if the check fails. The CLI then updates itself to the version the organization selects in Apiiro.

## macOS / Linux

```bash
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) ASSET=apiiro-macos-arm64 SHA256=dbbe5f863c4b3bee3c864389388ab17823866e17de967988934a1caa21fd43c9 ;;
  Darwin-x86_64) ASSET=apiiro-macos-x64 SHA256=c6ca767530a3dfd17e9a771aec7e0fff5fbeb01d5d289a593993b5ee88a3c1e3 ;;
  Linux-x86_64) ASSET=apiiro-linux-x64 SHA256=03a79939411650bb3a9ee6c7148be08d3e8978e9704507d66b8d565b0f4f9453 ;;
  Linux-aarch64 | Linux-arm64) ASSET=apiiro-linux-arm64 SHA256=665442dd7f42b76be4eb852a09672581799b9e2a9299b9857a09eea3356e853e ;;
  *) ASSET= ;;
esac &&
[ -n "$ASSET" ] &&
TMP=$(mktemp -d) &&
curl -fsSLo "$TMP/apiiro" "https://github.com/apiiro/marketplace/releases/download/v1.12.2/$ASSET" &&
if command -v sha256sum >/dev/null; then echo "$SHA256  $TMP/apiiro" | sha256sum -c -; else echo "$SHA256  $TMP/apiiro" | shasum -a 256 -c -; fi &&
chmod +x "$TMP/apiiro" && mkdir -p ~/.local/bin && mv "$TMP/apiiro" ~/.local/bin/apiiro &&
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo 'Add to your shell profile: export PATH="$HOME/.local/bin:$PATH"' ;; esac
```

If the PATH line prints, add it to `~/.zshrc` or `~/.bashrc` and open a new shell. On any other platform, nothing is downloaded.

## Windows (PowerShell)

```powershell
$dir = Join-Path $env:LOCALAPPDATA 'Apiiro\bin'
$tmp = Join-Path $env:TEMP 'apiiro-win.exe'
Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/apiiro/marketplace/releases/download/v1.12.2/apiiro-win.exe' -OutFile $tmp
if ((Get-FileHash -Algorithm SHA256 $tmp).Hash -ne '5297993cbfe4a8699fa397dcde0cda283ca3da91c4fc501c8cc3224a9e663d58') { Remove-Item $tmp; throw 'Checksum mismatch: apiiro-win.exe was not installed' }
New-Item -ItemType Directory -Force $dir | Out-Null
Move-Item -Force $tmp (Join-Path $dir 'apiiro.exe')
if (($env:Path -split ';') -notcontains $dir) { "Add $dir to your user PATH and open a new terminal" }
```

## Other install methods

npm, Homebrew and RPM: point the user to https://github.com/apiiro/marketplace#installation.
