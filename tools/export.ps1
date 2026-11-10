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
  New-Item -ItemType Directory -Path builds/content -Force | Out-Null
  Copy-Item -LiteralPath content/licenses -Destination builds/content -Recurse -Force
  $sourceCommit = (& git rev-parse HEAD | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot identify the source commit.' }
  $sourceTree = (& git rev-parse 'HEAD^{tree}' | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $sourceTree -notmatch '^[0-9a-f]{40}$') { throw 'Cannot identify the source tree.' }
  $trackedStatus = (& git status --porcelain --untracked-files=no | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $trackedStatus) { throw 'Export provenance requires a clean tracked working tree.' }
  # The presets exclude these development directories. Any other untracked resource could enter
  # all_resources and would make the commit/tree manifest an inaccurate description of the pack.
  $untrackedGame = @(& git ls-files --others --exclude-standard | Where-Object { $_ -notmatch '^(docs|tests|tools|asset_sources|\.github)/' })
  if ($LASTEXITCODE -ne 0 -or $untrackedGame.Count -gt 0) { throw "Untracked game inputs are not covered by the source commit: $untrackedGame" }
  $hashes = Get-FileHash -LiteralPath builds/evacuation.exe,builds/evacuation.console.exe,builds/evacuation.x86_64 -Algorithm SHA256
  $outputs = [ordered]@{}
  foreach ($entry in $hashes) { $outputs[[IO.Path]::GetFileName($entry.Path)] = $entry.Hash.ToLowerInvariant() }
  [ordered]@{
    schema_version = 1
    source_commit = $sourceCommit
    source_tree = $sourceTree
    godot_version = $lock.cli_version
    outputs_sha256 = $outputs
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath builds/build-manifest.json -Encoding utf8
  $hashes | Format-Table Hash,Path
} finally {
  Pop-Location
}
exit 0
