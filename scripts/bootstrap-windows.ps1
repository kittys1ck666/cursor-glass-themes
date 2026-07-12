#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot Windows installer for Cursor Glass Themes (no git required).

.DESCRIPTION
  Downloads the theme repo ZIP, extracts it, and runs install.ps1.
  Patches Cursor workbench directly - Custom CSS extension is optional.

.EXAMPLE
  # From PowerShell (no git needed):
  irm https://raw.githubusercontent.com/kittys1ck666/cursor-glass-themes/cursor/fix-installer-bugs-ccba/scripts/bootstrap-windows.ps1 | iex

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1 -Theme sakura
#>
param(
    [string]$Theme = "abyss",
    [string]$Branch = "cursor/fix-installer-bugs-ccba",
    [string]$Repo = "kittys1ck666/cursor-glass-themes"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "  Cursor Glass Themes - Easy Install (Windows)" -ForegroundColor White
Write-Host "  No git. Workbench patch built-in." -ForegroundColor White
Write-Host ""

# Close Cursor tip
$cursorProc = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
if ($cursorProc) {
    Write-Host "  Tip: fully quit Cursor before install for a clean patch." -ForegroundColor Yellow
}

$work = Join-Path $env:TEMP "cursor-glass-themes-install"
$zip = Join-Path $env:TEMP "cursor-glass-themes.zip"
$zipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"

Write-Step "Downloading $Repo@$Branch"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
if (Test-Path $zip) { Remove-Item $zip -Force }
Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
Write-Ok "Downloaded ZIP"

Write-Step "Extracting"
Expand-Archive -Path $zip -DestinationPath $work -Force
$repoDir = Get-ChildItem $work -Directory | Select-Object -First 1
if (-not $repoDir) { throw "Extract failed - repo folder not found" }
Write-Ok $repoDir.FullName

$installer = Join-Path $repoDir.FullName "scripts\install.ps1"
if (-not (Test-Path $installer)) { throw "install.ps1 not found in ZIP" }

Write-Step "Running installer (theme: $Theme)"
& powershell -ExecutionPolicy Bypass -File $installer -Theme $Theme
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  Installer failed (exit $LASTEXITCODE). See errors above." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "  Easy install finished." -ForegroundColor Green
Write-Host "  Fully quit Cursor -> open it again." -ForegroundColor Green
Write-Host ""
