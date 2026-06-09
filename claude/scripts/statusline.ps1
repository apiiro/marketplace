# Claude Code status line — shows a shield while an Apiiro Guardian hook has
# touched $HOME/.apiiro/sessions/<session_id> within the last $MaxAge seconds.

$inputText = [Console]::In.ReadToEnd()
$SessionId = ''
try {
  $SessionId = ($inputText | ConvertFrom-Json -ErrorAction Stop).session_id
} catch { }

if (-not $SessionId) { exit 0 }

$SessionFile = Join-Path $HOME ".apiiro/sessions/$SessionId"
$MaxAge = 600

if (Test-Path -LiteralPath $SessionFile -PathType Leaf) {
  $mtime = (Get-Item -LiteralPath $SessionFile).LastWriteTimeUtc
  $age = (Get-Date).ToUniversalTime().Subtract($mtime).TotalSeconds
  if ($age -lt $MaxAge) {
    Write-Output "🛡️ Apiiro Guardian Activated"
  }
}
