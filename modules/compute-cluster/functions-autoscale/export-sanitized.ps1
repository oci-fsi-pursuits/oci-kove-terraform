param(
  [string]$OutputZip = "../../exports/rdma-autoscale-sanitized.zip"
)

$ErrorActionPreference = "Stop"

$stackDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$staging = Join-Path $env:TEMP ("rdma-autoscale-sanitized-" + [guid]::NewGuid().ToString("N"))
$outputPath = [System.IO.Path]::GetFullPath((Join-Path $stackDir $OutputZip))
$outputDir = Split-Path -Parent $outputPath

New-Item -Path $staging -ItemType Directory | Out-Null
New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

$include = @(
  "README.md",
  "main.tf",
  "outputs.tf",
  "providers.tf",
  "schema.yaml",
  "variables.tf",
  "versions.tf",
  "terraform.tfvars.example",
  "terraform.tfvars.existing-build.minimal.example"
)

foreach ($file in $include) {
  Copy-Item -Path (Join-Path $stackDir $file) -Destination (Join-Path $staging $file) -Force
}

$templatesDir = Join-Path $stackDir "templates"
if (Test-Path $templatesDir) {
  Copy-Item -Path $templatesDir -Destination (Join-Path $staging "templates") -Recurse -Force
}

$functionDir = Join-Path $stackDir "function"
if (Test-Path $functionDir) {
  Copy-Item -Path $functionDir -Destination (Join-Path $staging "function") -Recurse -Force
}

$scriptsDir = Join-Path $stackDir "scripts"
if (Test-Path $scriptsDir) {
  Copy-Item -Path $scriptsDir -Destination (Join-Path $staging "scripts") -Recurse -Force
}

if (Test-Path $outputPath) {
  Remove-Item $outputPath -Force
}

Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outputPath -Force
Remove-Item -Path $staging -Recurse -Force

Write-Output "Sanitized export created: $outputPath"
