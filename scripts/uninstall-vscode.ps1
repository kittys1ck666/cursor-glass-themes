#Requires -Version 5.1
param([switch]$Insiders)

$ErrorActionPreference = "Stop"

$ThemeDir = Join-Path $env:USERPROFILE ".vscode\glass-themes"
$SettingsPath = if ($Insiders) {
    Join-Path $env:APPDATA "Code - Insiders\User\settings.json"
} else {
    Join-Path $env:APPDATA "Code\User\settings.json"
}
$BackupPath = "$SettingsPath.bak-glass-theme"
$AppFolder = if ($Insiders) { "Microsoft VS Code Insiders" } else { "Microsoft VS Code" }

function Resolve-VSCodePaths {
    param([string]$FolderName)
    $candidates = @(
        Join-Path $env:LOCALAPPDATA "Programs\$FolderName"
        (Join-Path ${env:ProgramFiles} $FolderName)
        (Join-Path ${env:ProgramFiles(x86)} $FolderName)
    ) | Where-Object { Test-Path $_ }
    foreach ($root in $candidates) {
        $product = Get-ChildItem $root -Recurse -Filter "product.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]resources[\\/]app[\\/]product\.json$' } |
            Select-Object -First 1
        if (-not $product) { continue }

        $appDir = $product.Directory.FullName
        $vsCodeDir = Join-Path $appDir "out\vs\code"
        $browserWb = Join-Path $vsCodeDir "electron-browser\workbench\workbench.html"
        $sandboxWb = Join-Path $vsCodeDir "electron-sandbox\workbench\workbench.html"
        $sandboxEsmWb = Join-Path $vsCodeDir "electron-sandbox\workbench\workbench.esm.html"

        $customCssPaths = @($sandboxWb, $sandboxEsmWb, $browserWb)

        return @{
            CustomCssWorkbenchPaths   = $customCssPaths
            ProductJson               = $product.FullName
            AppDir                    = $appDir
        }
    }
    return $null
}

$vscodePaths = Resolve-VSCodePaths -FolderName $AppFolder
$CustomCssWorkbenchPaths = if ($vscodePaths) { $vscodePaths.CustomCssWorkbenchPaths } else { @() }
$ProductJson = if ($vscodePaths) { $vscodePaths.ProductJson } else { $null }

function Get-RelativePathCompat {
    param([string]$FromDir, [string]$ToPath)
    $from = $FromDir.TrimEnd('\') + '\'
    $fromUri = New-Object System.Uri $from
    $toUri = New-Object System.Uri ((Resolve-Path $ToPath).Path)
    return [Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString()).Replace('\', '/')
}

function Update-ProductJsonChecksum {
    param([string]$ProductJsonPath, [string]$WorkbenchHtmlPath)
    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtmlPath))
    ).TrimEnd('=')
    $appDir = Split-Path $ProductJsonPath -Parent
    $rel = Get-RelativePathCompat -FromDir $appDir -ToPath $WorkbenchHtmlPath
    $key = if ($rel -match '^out/(.+)$') { $matches[1] } else { $rel }
    $product = Get-Content $ProductJsonPath -Raw -Encoding UTF8
    $escapedKey = [regex]::Escape($key)
    if ($product -match "`"$escapedKey`":\s*`"[^`"]+`"") {
        $product = $product -replace "`"$escapedKey`":\s*`"[^`"]+`"", "`"$key`": `"$hash`""
    } else {
        $product = $product -replace '"vs/code/[^"]+/workbench/workbench\.html":\s*"[^"]+"', "`"$key`": `"$hash`""
    }
    [System.IO.File]::WriteAllText($ProductJsonPath, $product, [System.Text.UTF8Encoding]::new($false))
}

function Restore-WorkbenchFromBackup {
    param([string]$Path)
    if (-not $Path) { return $false }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { return $false }
    $bak = Get-ChildItem $dir -Filter "workbench.*.bak-custom-css" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $bak) { return $false }
    $raw = Get-Content $bak.FullName -Raw -Encoding UTF8
    if ($raw -match 'VSCODE-CUSTOM-CSS-START') { return $false }
    $targetName = Split-Path $Path -Leaf
    # Prefer matching bak for workbench.html / workbench.esm.html when possible
    $matchBak = Get-ChildItem $dir -Filter "$($targetName).*.bak-custom-css" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($matchBak) {
        $raw = Get-Content $matchBak.FullName -Raw -Encoding UTF8
        if ($raw -match 'VSCODE-CUSTOM-CSS-START') { return $false }
        Copy-Item $matchBak.FullName $Path -Force
    } else {
        Copy-Item $bak.FullName $Path -Force
    }
    Write-Host "    restored CSP+html from $($bak.Name) -> $Path" -ForegroundColor Green
    return $true
}

function Remove-WorkbenchPatch {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { return $false }

    if (Restore-WorkbenchFromBackup -Path $Path) {
        if ($ProductJson -and (Test-Path $ProductJson)) {
            Update-ProductJsonChecksum -ProductJsonPath $ProductJson -WorkbenchHtmlPath $Path
        }
        return $true
    }

    $html = Get-Content $Path -Raw -Encoding UTF8
    if ($html -notmatch 'VSCODE-CUSTOM-CSS-START') { return $false }
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    [System.IO.File]::WriteAllText($Path, $html, [System.Text.UTF8Encoding]::new($false))
    if ($ProductJson -and (Test-Path $ProductJson)) {
        Update-ProductJsonChecksum -ProductJsonPath $ProductJson -WorkbenchHtmlPath $Path
    }
    Write-Host "    stripped glass patch (CSP backup not found): $Path" -ForegroundColor Yellow
    return $true
}

Write-Host "`n==> Removing workbench patch" -ForegroundColor Cyan
$restored = @()
foreach ($mirrorPath in ($CustomCssWorkbenchPaths | Select-Object -Unique)) {
    if (Remove-WorkbenchPatch -Path $mirrorPath) { $restored += $mirrorPath }
}
if ($restored.Count -gt 0) {
    foreach ($path in $restored) { Write-Host "    cleaned $path" -ForegroundColor Green }
} else {
    Write-Host "    no glass patch found" -ForegroundColor Yellow
}

Write-Host "`n==> Cleaning settings.json" -ForegroundColor Cyan
$GlassKeys = @(
    'vscode_custom_css.imports',
    'vscode_custom_css.statusbar',
    'workbench.colorCustomizations',
    'workbench.preferredLightColorTheme',
    'workbench.preferredDarkColorTheme',
    'window.autoDetectColorScheme'
)
if (Test-Path $BackupPath) {
    Copy-Item $BackupPath $SettingsPath -Force
    Write-Host "    Restored settings from settings.json.bak-glass-theme" -ForegroundColor Green
} elseif (Test-Path $SettingsPath) {
    $obj = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in $GlassKeys) {
        $p = $obj.PSObject.Properties[$key]
        if ($p) { $obj.PSObject.Properties.Remove($key) }
    }
    $json = $obj | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "    Glass settings keys removed (no backup found)" -ForegroundColor Green
}

Write-Host "`n==> Removing theme files" -ForegroundColor Cyan
if (Test-Path $ThemeDir) {
    Remove-Item $ThemeDir -Recurse -Force
    Write-Host "    $ThemeDir removed" -ForegroundColor Green
}

Write-Host "`nRestart VS Code. Backup kept at: $BackupPath`n" -ForegroundColor Yellow
