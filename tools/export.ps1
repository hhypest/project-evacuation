[CmdletBinding()]
param([string]$GodotPath = $env:GODOT_BIN)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
  $command = Get-Command godot -ErrorAction SilentlyContinue
  if (-not $command) { throw 'Pass -GodotPath or set GODOT_BIN.' }
  $GodotPath = $command.Source
}
Push-Location $root
try {
  $lock = Get-Content -LiteralPath tools/toolchain.json -Raw | ConvertFrom-Json
  if ((& $GodotPath --version | Out-String).Trim() -ne $lock.cli_version) { throw 'Wrong editor version.' }
  New-Item -ItemType Directory -Path builds -Force | Out-Null
  foreach ($preset in @(@('Windows Vulkan', 'builds/evacuation.exe'), @('Linux Vulkan', 'builds/evacuation.x86_64'))) {
    $log = @(& $GodotPath --headless --path . --export-release $preset[0] $preset[1] 2>&1)
    $code = $LASTEXITCODE
    $output = ($log | ForEach-Object { "$_" }) -join "`n"
    if ($code -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|WARNING:)') { throw "Export failed: $output" }
    if (-not (Test-Path -LiteralPath $preset[1])) { throw "No output for $($preset[0])" }
    Write-Output "Exported $($preset[0])"
  }
  Copy-Item -LiteralPath LICENSE,THIRD_PARTY_NOTICES.md -Destination builds
  Copy-Item -LiteralPath content/licenses -Destination builds -Recurse -Force
  Get-FileHash -LiteralPath builds/evacuation.exe,builds/evacuation.x86_64 -Algorithm SHA256 | Format-Table Hash,Path
} finally {
  Pop-Location
}
exit 0
