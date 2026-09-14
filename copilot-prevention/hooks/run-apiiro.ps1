Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$agent = if ($args.Count -gt 0) { $args[0] } else { '' }
$action = if ($args.Count -gt 1) { $args[1] } else { '' }
$allowed = @(
  'codex:session-start', 'codex:secure-prompt', 'codex:pre-commit-scan',
  'copilot:session-start', 'copilot:pre-commit-scan'
)
if (-not $allowed.Contains("$($agent):$action")) {
  [Console]::Error.WriteLine('[Apiiro] Invalid plugin hook invocation.')
  exit 0
}

$command = Get-Command apiiro -ErrorAction SilentlyContinue
$candidates = @(
  (Join-Path $HOME '.local\bin\apiiro.exe'),
  $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Apiiro\bin\apiiro.exe' }),
  (Join-Path $env:ProgramFiles 'Apiiro\bin\apiiro.exe')
) | Where-Object { $_ }
$apiiro = if ($command) { $command.Source } else { $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1 }
if (-not $apiiro) {
  [Console]::Error.WriteLine("[Apiiro] CLI not found; skipping plugin hook. Install it and run 'apiiro login'.")
  exit 0
}

& $apiiro hooks $agent $action
exit $LASTEXITCODE
