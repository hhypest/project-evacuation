[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Recurse -Filter '*.gd')
$classes = @{}
foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
  $layer = $relative.Split('/')[1]
  $source = Get-Content -LiteralPath $file.FullName -Raw
  if ($source -match '(?m)^class_name\s+(\w+)') { $classes[$Matches[1]] = $layer }
}
$allowed = @{
  domain = @('domain')
  application = @('application', 'domain')
  infrastructure = @('infrastructure', 'application', 'domain')
  presentation = @('presentation', 'application', 'domain')
  bootstrap = @('bootstrap', 'presentation', 'infrastructure', 'application', 'domain')
}
$violations = [Collections.Generic.List[string]]::new()
foreach ($file in $files) {
  $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
  $layer = $relative.Split('/')[1]
  if (-not $allowed.ContainsKey($layer)) { throw "Unknown source layer: $relative" }
  $source = (Get-Content -LiteralPath $file.FullName -Raw) -replace '(?m)#.*$', ''
  foreach ($className in $classes.Keys) {
    if ($source -match ('\b' + [regex]::Escape($className) + '\b') -and $classes[$className] -notin $allowed[$layer]) {
      $violations.Add("$relative references $className in $($classes[$className])")
    }
  }
  foreach ($match in [regex]::Matches($source, 'res://src/([^/]+)/')) {
    if ($match.Groups[1].Value -notin $allowed[$layer]) { $violations.Add("$relative loads an outer layer") }
  }
  if ($layer -in @('domain', 'application')) {
    $forbidden = '\b(Node\w*|SceneTree|Input|InputMap|FileAccess|DirAccess|Resource\w*|PackedScene|ProjectSettings|Engine|OS|DisplayServer|RenderingServer|PhysicsServer\w*|CharacterBody3D|RigidBody3D|Camera3D|Area3D)\b|res://content/'
    if ($source -match $forbidden) { $violations.Add("$relative uses an engine runtime dependency: $($Matches[0])") }
  }
}
if ($violations.Count -gt 0) { throw ($violations -join "`n") }
Write-Output "Layer check passed ($($files.Count) scripts). This is a lexical guard; review still checks architecture."
