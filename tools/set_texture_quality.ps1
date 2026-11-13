[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Source', '2K')][string]$Quality,
  [string]$GodotPath = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $root 'tools/toolchain.json') -Raw | ConvertFrom-Json
if (-not $GodotPath) {
  $command = Get-Command godot -ErrorAction SilentlyContinue
  if (-not $command) { throw 'Pass -GodotPath or set GODOT_BIN.' }
  $GodotPath = $command.Source
}
$version = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $lock.cli_version) { throw "Expected $($lock.cli_version); got $version" }
$limit = if ($Quality -eq '2K') { 2048 } else { 0 }
$originals = [ordered]@{}
$changes = [ordered]@{}
$utf8 = [Text.UTF8Encoding]::new($false)

function Register-Texture([string]$mapPath) {
  $path = $mapPath + '.import'
  $source = [IO.File]::ReadAllText($path)
  if ([regex]::Matches($source, '(?m)^process/size_limit=\d+\r?$').Count -ne 1) { throw "Invalid import limit in $path" }
  $originals[$path] = $source
  $changes[$path] = [regex]::Replace($source, '(?m)^process/size_limit=\d+', "process/size_limit=$limit")
}

# Validate the entire set before modifying any file; source images are never rewritten.
foreach ($model in @('ballast_cube', 'floor_button', 'emitter', 'receiver', 'wall_button', 'wall_switch', 'logic_box', 'door', 'door_frame')) {
  $folder = Join-Path $root "content/models/devices/$model"
  $textures = @(Get-ChildItem -LiteralPath $folder -File | Where-Object Extension -In '.jpg', '.png')
  if ($textures.Count -ne 3) { throw "Expected exactly three source maps in $model." }
  foreach ($texture in $textures) { Register-Texture $texture.FullName }
}
foreach ($variant in @('5kg', '10kg')) {
  Register-Texture (Join-Path $root "content/textures/expedition/ballast_${variant}_albedo.jpg")
}
$manifest = Join-Path $root 'content/definitions/device_texture_quality.tres'
$source = [IO.File]::ReadAllText($manifest)
if ([regex]::Matches($source, '(?m)^max_size = \d+\r?$').Count -ne 1) { throw 'Invalid texture profile resource.' }
$originals[$manifest] = $source
$changes[$manifest] = [regex]::Replace($source, '(?m)^max_size = \d+', "max_size = $limit")

function Invoke-QualityGodot {
  param([string[]]$Arguments)
  $captured = @(& $GodotPath @Arguments 2>&1)
  $code = $LASTEXITCODE
  $output = ($captured | ForEach-Object { "$_" }) -join "`n"
  if ($code -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|WARNING:)') { throw $output }
  return $output
}

try {
  foreach ($path in $changes.Keys) { [IO.File]::WriteAllText($path, $changes[$path], $utf8) }
  $null = Invoke-QualityGodot -Arguments @('--headless', '--path', $root, '--import')
  $report = Invoke-QualityGodot -Arguments @('--headless', '--path', $root, '--script', 'tools/texture_quality_smoke.gd')
  if ($report -notmatch 'TEXTURE_QUALITY_PASSED') { throw 'Missing texture-size verification result.' }
  Write-Output $report
  Write-Output "TEXTURE_PROFILE_APPLIED quality=$Quality max_size=$limit maps=29 (original images preserved; restart the game)"
} catch {
  $reason = $_
  foreach ($path in $originals.Keys) { [IO.File]::WriteAllText($path, $originals[$path], $utf8) }
  # Restore the imported cache as well, so a failed operation does not leave a mixed profile.
  try { $null = Invoke-QualityGodot -Arguments @('--headless', '--path', $root, '--import') }
  catch { Write-Warning 'Source settings restored; rerun Godot --headless --import to restore the cache.' }
  throw $reason
}
