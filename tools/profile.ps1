[CmdletBinding()]
param(
  [ValidateSet('Current', 'Source', '2K')][string]$Quality = 'Current',
  [string]$GodotPath = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
  $command = Get-Command godot -ErrorAction SilentlyContinue
  if (-not $command) { throw 'Pass -GodotPath or set GODOT_BIN.' }
  $GodotPath = $command.Source
}
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$version = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $lock.cli_version) { throw "Expected $($lock.cli_version); got $version" }
if ($Quality -ne 'Current') {
  & (Join-Path $PSScriptRoot 'set_texture_quality.ps1') -Quality $Quality -GodotPath $GodotPath
}
& $GodotPath --path $root -- --profile
exit $LASTEXITCODE
