param(
    [Parameter(Mandatory = $true)]
    [string]$KujoBin
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Entry = Join-Path $RepoRoot "scout.kujo"
$OutputRoot = Join-Path $RepoRoot "tests/tmp/windows-contract"

function Invoke-Scout {
    param([string[]]$ScoutArguments)
    & $KujoBin run $Entry -- @ScoutArguments
    if ($LASTEXITCODE -ne 0) { throw "Scout exited with code $LASTEXITCODE" }
}

function Read-SingleReport {
    param([string]$Root)
    $reports = @(Get-ChildItem -Path $Root -Recurse -Filter intelligence.json)
    if ($reports.Count -ne 1) { throw "Expected one intelligence report in $Root; found $($reports.Count)" }
    return Get-Content -Raw $reports[0].FullName | ConvertFrom-Json
}

if (Test-Path $OutputRoot) { Remove-Item -Recurse -Force $OutputRoot }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null

$version = (& $KujoBin --version).Trim()
if ($version -ne "kujo 1.5.0") { throw "Unexpected Kujo version: $version" }

$artifactRoot = Join-Path $OutputRoot "artifacts"
Invoke-Scout @((Join-Path $RepoRoot "tests/fixtures/arc001"), "-o", $artifactRoot, "-d", "2", "--strict", "--security-export", "sarif", "--kennel-index", "--kennel-metadata")
$manifestPath = Get-ChildItem -Path $artifactRoot -Recurse -Filter scan_manifest.json | Select-Object -First 1 -ExpandProperty FullName
if (-not $manifestPath) { throw "scan_manifest.json was not generated" }
$runDir = Split-Path $manifestPath
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$intelligence = Get-Content -Raw (Join-Path $runDir "intelligence.json") | ConvertFrom-Json
if ($intelligence.metrics.total_files -ne 2) { throw "Unexpected artifact-smoke file count" }
if ($manifest.artifacts.security_sarif -ne "security.sarif") { throw "Missing SARIF artifact pointer" }
foreach ($relativePath in @("README.md", "intelligence.json", "security.sarif", "index.json", $manifest.artifacts.kennel_metadata)) {
    if (-not (Test-Path (Join-Path $runDir $relativePath))) { throw "Missing Scout artifact: $relativePath" }
}

foreach ($family in @("python", "js", "php", "rust", "go", "jvm", "kujo")) {
    $routeRoot = Join-Path $OutputRoot "route-$family"
    $fixture = Join-Path $RepoRoot "tests/fixtures/test002/routes_$family"
    Invoke-Scout @($fixture, "-o", $routeRoot, "-d", "3", "--quick", "--strict", "--skip-deps", "--skip-security")
    $report = Read-SingleReport $routeRoot
    $actual = (($report.routes | ForEach-Object { "$($_.method)|$($_.path)" }) -join "`n").Trim()
    $expected = (Get-Content -Raw (Join-Path $RepoRoot "tests/fixtures/test002/snapshots/$family.txt")).Trim()
    if ($actual -ne $expected) { throw "Route contract mismatch for $family`: expected '$expected', got '$actual'" }
}

$securityRoot = Join-Path $OutputRoot "security"
Invoke-Scout @((Join-Path $RepoRoot "tests/fixtures/test006"), "-o", $securityRoot, "-d", "2", "--quick", "--strict", "--skip-deps", "--skip-routes", "--security-export", "jsonl")
$securityReport = Read-SingleReport $securityRoot
$expectedLabels = @("Dangerous code execution function", "Embedded private key", "Hardcoded credential", "Hardcoded token", "Insecure deserialization", "Weak hash usage", "XSS sink usage")
$actualLabels = @($securityReport.security_findings | ForEach-Object { $_.label } | Sort-Object -Unique)
if ((Compare-Object $expectedLabels $actualLabels).Count -ne 0) { throw "Security label contract mismatch" }
$jsonlPath = Get-ChildItem -Path $securityRoot -Recurse -Filter security.jsonl | Select-Object -First 1 -ExpandProperty FullName
if (-not $jsonlPath) { throw "security.jsonl was not generated" }
foreach ($line in Get-Content $jsonlPath) { $null = $line | ConvertFrom-Json }

Write-Host "Native Windows Scout contract subset passed"
