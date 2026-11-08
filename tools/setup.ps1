[CmdletBinding()]
param([switch]$SkipTemplates)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$workspace = Join-Path $root 'work'
New-Item -ItemType Directory -Path $workspace -Force | Out-Null
Set-Content -LiteralPath (Join-Path $workspace '.gdignore') -Value ''
$base = "https://github.com/godotengine/godot-builds/releases/download/$($lock.release)"
$platformIsWindows = $env:OS -eq 'Windows_NT'
if (-not $platformIsWindows -and -not $IsLinux) { throw 'Automatic setup supports Windows and Linux x86_64.' }

function Get-VerifiedAsset {
  param([object]$Asset)
  if ([IO.Path]::GetFileName($Asset.filename) -ne $Asset.filename) { throw 'Unsafe artifact filename.' }
  $archivePath = Join-Path $workspace $Asset.filename
  if (-not (Test-Path -LiteralPath $archivePath)) {
    # The release host answers 502/503/504 at times; retry with backoff and keep partial files out of the cache.
    $partial = "$archivePath.part"
    $delays = @(0, 10, 30, 60, 120)
    for ($attempt = 1; $attempt -le $delays.Count; $attempt++) {
      if ($delays[$attempt - 1] -gt 0) { Start-Sleep -Seconds $delays[$attempt - 1] }
      Write-Host "Downloading $($Asset.filename) (attempt $attempt of $($delays.Count))"
      try {
        Invoke-WebRequest "$base/$($Asset.filename)" -OutFile $partial
        Move-Item -LiteralPath $partial -Destination $archivePath -Force
        break
      } catch {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        if ($attempt -eq $delays.Count) { throw }
        Write-Warning "Download failed: $($_.Exception.Message)"
      }
    }
  }
  if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA512).Hash.ToLowerInvariant() -ne $Asset.sha512) {
    throw "Checksum mismatch: $archivePath. Keep the file for diagnosis; replace it before retrying."
  }
  return $archivePath
}

$asset = if ($platformIsWindows) { $lock.artifacts.windows_editor } else { $lock.artifacts.linux_editor }
$editorArchive = Get-VerifiedAsset -Asset $asset
$editorDir = Join-Path $workspace 'verified-editor'
New-Item -ItemType Directory -Path $editorDir -Force | Out-Null
Expand-Archive -LiteralPath $editorArchive -DestinationPath $editorDir -Force
$binaryName = if ($platformIsWindows) { "Godot_v$($lock.release)_win64_console.exe" } else { "Godot_v$($lock.release)_linux.x86_64" }
$binary = Join-Path $editorDir $binaryName
if (-not $platformIsWindows) {
  chmod +x $binary
  if ($LASTEXITCODE -ne 0) { throw 'Could not make the editor executable.' }
}
if ((& $binary --version | Out-String).Trim() -ne $lock.cli_version) { throw 'Unexpected editor build.' }

if (-not $SkipTemplates) {
  $templatesArchive = Get-VerifiedAsset -Asset $lock.artifacts.templates
  $dataRoot = if ($platformIsWindows) { $env:APPDATA } elseif ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/share' }
  $engineDirectory = if ($platformIsWindows) { 'Godot' } else { 'godot' }
  $destination = Join-Path $dataRoot "$engineDirectory/export_templates/$($lock.templates_directory)"
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($templatesArchive)
  try {
    foreach ($entry in $archive.Entries) {
      if ($entry.FullName -match '^templates/(version.txt|linux_(debug|release).x86_64|windows_(debug|release)_x86_64.exe)$') {
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $destination ([IO.Path]::GetFileName($entry.FullName))), $true)
      }
    }
  } finally { $archive.Dispose() }
  Write-Host "Verified Windows/Linux x86_64 templates installed: $destination"
}
Write-Output $binary
