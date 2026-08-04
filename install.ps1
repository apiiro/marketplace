# Apiiro CLI installer for Windows (PowerShell).
#
#   irm https://apiiro.com/install.ps1 | iex
#
# Downloads apiiro-win.exe from the latest public release, verifies its SHA-256,
# installs it under %LOCALAPPDATA%\Apiiro\bin (no admin), adds it to the user
# PATH, and points you at the next steps. Wrapped in a function so a truncated
# download can't half-execute.
#
# Environment overrides:
#   APIIRO_INSTALL_DIR     install directory        (default: %LOCALAPPDATA%\Apiiro\bin)
#   APIIRO_VERSION         version to install, e.g. 1.5.0 (default: latest)
#   APIIRO_NO_MODIFY_PATH  set to 1 to skip editing your user PATH

function Install-Apiiro {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $repo = 'apiiro/marketplace'
    $asset = 'apiiro-win.exe'   # single x64 build; runs on arm64 Windows via emulation

    if ($env:APIIRO_VERSION) {
        $baseUrl = "https://github.com/$repo/releases/download/v$($env:APIIRO_VERSION)"
        $label = "v$($env:APIIRO_VERSION)"
    } else {
        $baseUrl = "https://github.com/$repo/releases/latest/download"
        $label = 'latest'
    }

    $binDir = if ($env:APIIRO_INSTALL_DIR) { $env:APIIRO_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Apiiro\bin' }
    $target = Join-Path $binDir 'apiiro.exe'

    Write-Host ""
    Write-Host "  Installing Apiiro CLI ($label, $asset)"
    Write-Host ""

    $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("apiiro-" + [System.Guid]::NewGuid().ToString('N')))
    try {
        $tmpBin = Join-Path $tmp 'apiiro.exe'
        Write-Host "  downloading $asset"
        Invoke-WebRequest -Uri "$baseUrl/$asset" -OutFile $tmpBin -UseBasicParsing

        # Verify against the published checksums. Fail closed: checksums.txt
        # ships with every release, so a failed fetch or a missing entry means
        # something is wrong (or someone is blocking it to force an unverified
        # install) — refuse rather than downgrade to a warning.
        Write-Host "  fetching checksums"
        $tmpSums = Join-Path $tmp 'checksums.txt'
        try {
            Invoke-WebRequest -Uri "$baseUrl/checksums.txt" -OutFile $tmpSums -UseBasicParsing
        } catch {
            throw "could not fetch checksums.txt from $baseUrl - refusing to install unverified: $_"
        }
        $line = Select-String -Path $tmpSums -Pattern ([regex]::Escape($asset)) | Select-Object -First 1
        if (-not $line) { throw "no checksum listed for $asset in checksums.txt - refusing to install unverified" }
        $expected = ($line.Line -split '\s+')[0]
        $actual = (Get-FileHash -Algorithm SHA256 -Path $tmpBin).Hash
        if (-not ($expected -and $actual -ieq $expected)) {
            throw "checksum mismatch for $asset`n    expected: $expected`n    actual:   $actual"
        }
        Write-Host "  checksum verified"

        # Optional SLSA build-provenance check (opt-in; needs the gh CLI).
        if ($env:APIIRO_VERIFY_ATTESTATION -eq '1') {
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                Write-Host "  verifying build provenance"
                & gh attestation verify $tmpBin --owner apiiro *> $null
                if ($LASTEXITCODE -ne 0) { throw "build-provenance verification failed for $asset" }
                Write-Host "  provenance verified"
            } else {
                Write-Warning "APIIRO_VERIFY_ATTESTATION=1 but the gh CLI is not installed — cannot verify provenance"
            }
        }

        if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
        Move-Item -Path $tmpBin -Destination $target -Force
        Write-Host "  installed to $target"
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }

    # Sanity check
    & $target --version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "installation verification failed — $target did not run" }

    # Add to user PATH if missing. Read and write the raw registry value with
    # its kind preserved: [Environment]::GetEnvironmentVariable expands
    # %VAR%-style entries and SetEnvironmentVariable rewrites the key as REG_SZ,
    # which would freeze any REG_EXPAND_SZ entries (e.g. %USERPROFILE%\bin) in
    # the user's existing PATH.
    $pathModified = $false
    if ($env:APIIRO_NO_MODIFY_PATH -ne '1') {
        $envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        if (-not $envKey) { $envKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment') }
        try {
            $userPath = [string]$envKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $kind = try { $envKey.GetValueKind('Path') } catch { [Microsoft.Win32.RegistryValueKind]::ExpandString }
            $onPath = ($userPath -split ';' | Where-Object { $_ }) -contains $binDir
            if (-not $onPath) {
                $newPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
                $envKey.SetValue('Path', $newPath, $kind)
                $env:Path = "$env:Path;$binDir"
                $pathModified = $true
            }
        } finally {
            $envKey.Dispose()
        }
    }

    # Best-effort: wire Apiiro into any installed coding agents (skills only).
    $agentsWired = $false
    try {
        & $target agents install *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "  configured installed coding agents"; $agentsWired = $true }
    } catch { }

    $version = (& $target --version) 2>$null
    Write-Host ""
    Write-Host "  Apiiro CLI $version installed."
    Write-Host ""
    if ($pathModified) {
        Write-Host "  Added $binDir to your user PATH. Open a new terminal to use 'apiiro'."
        Write-Host ""
    }
    Write-Host "  Next steps:"
    Write-Host "    1. apiiro login"
    if (-not $agentsWired) {
        Write-Host "    2. Add the skills to your agent:"
        Write-Host "         Claude Code:  /plugin marketplace add apiiro/marketplace  then  /plugin install apiiro@apiiro"
        Write-Host "         Other agents: npx skills add apiiro/marketplace"
    }
    Write-Host ""
}

Install-Apiiro
