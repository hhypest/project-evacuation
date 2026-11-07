[CmdletBinding()]
param(
  [string]$GodotPath = $env:GODOT_BIN,
  [switch]$SkipRunnerSelfCheck
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
  $command = Get-Command godot -ErrorAction SilentlyContinue
  if (-not $command) { throw 'Pass -GodotPath or set GODOT_BIN to the pinned Godot console/editor binary.' }
  $GodotPath = $command.Source
}
$version = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne '4.7.2.stable.official.ed1daf0bf') {
  throw "Expected official Godot 4.7.2.stable.official.ed1daf0bf; got $version"
}

function Invoke-CheckedGodot {
  param([string[]]$Arguments, [int]$ExpectedExit = 0)
  $captured = @(& $GodotPath @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $output = ($captured | ForEach-Object { "$_" }) -join "`n"
  if ($exitCode -ne $ExpectedExit -or ($ExpectedExit -eq 0 -and $output -match '(?m)(SCRIPT ERROR:|ERROR:|WARNING:)')) {
    throw "Godot check failed: exit=$exitCode expected=$ExpectedExit args=$Arguments`n$output"
  }
  return $output
}

Push-Location $root
try {
  $null = Invoke-CheckedGodot -Arguments @('--headless', '--path', '.', '--import')
  & (Join-Path $PSScriptRoot 'check_layers.ps1') -Root $root
  $scripts = @(Get-ChildItem -LiteralPath src,tests,tools -Recurse -Filter '*.gd' | Sort-Object FullName)
  foreach ($script in $scripts) {
    $relative = [IO.Path]::GetRelativePath($root, $script.FullName).Replace('\', '/')
    $source = Get-Content -LiteralPath $script.FullName -Raw
    if ($source -match '(?m)^ +\S|[ \t]+(?=\r?$)' -or -not $source.EndsWith("`n")) {
      throw "GDScript formatting violation: $relative (tabs, no trailing spaces, final newline required)."
    }
    $null = Invoke-CheckedGodot -Arguments @('--headless', '--path', '.', '--script', $relative, '--check-only')
  }
  Write-Output "Parse/type checks passed ($($scripts.Count) scripts)."
  $report = Invoke-CheckedGodot -Arguments @('--headless', '--path', '.', '--fixed-fps', '60', '--script', 'tests/run_tests.gd', '--', '--suite', 'all')
  if ($report -notmatch 'TEST_RESULT total=([1-9]\d*) failed=0') { throw "Missing nonempty successful test report: $report" }
  Write-Output $report
  if (-not $SkipRunnerSelfCheck) {
    $null = Invoke-CheckedGodot -ExpectedExit 1 -Arguments @('--headless', '--path', '.', '--script', 'tests/run_tests.gd', '--', '--suite', 'unit', '--self-test-failure')
    $null = Invoke-CheckedGodot -ExpectedExit 2 -Arguments @('--headless', '--path', '.', '--script', 'tests/run_tests.gd', '--', '--suite', 'unknown')
    $null = Invoke-CheckedGodot -ExpectedExit 2 -Arguments @('--headless', '--path', '.', '--script', 'tests/run_tests.gd', '--', '--suite')
    Write-Output 'Runner failure and invalid-argument exit checks passed.'
  }
  Write-Output 'CHECKS_PASSED (CPU/headless only; Vulkan smoke is separate).'
} finally {
  Pop-Location
}
exit 0
