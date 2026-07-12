#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$ThemeDir = Join-Path $env:USERPROFILE ".cursor\cursor-abyss-glass"
$SettingsPath = Join-Path $env:APPDATA "Cursor\User\settings.json"
$BackupPath = "$SettingsPath.bak-glass-theme"
$CursorAppDir = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app"
$VsCodeDir = Join-Path $CursorAppDir "out\vs\code"
$ProductJson = Join-Path $CursorAppDir "product.json"
$CustomCssWorkbenchPaths = @(
    (Join-Path $VsCodeDir "electron-sandbox\workbench\workbench.html"),
    (Join-Path $VsCodeDir "electron-sandbox\workbench\workbench.esm.html"),
    (Join-Path $VsCodeDir "electron-browser\workbench\workbench.html")
)

$GlassKeys = @(
    'vscode_custom_css.imports',
    'vscode_custom_css.statusbar',
    'cursor.general.reduceTransparency',
    'workbench.colorCustomizations',
    'workbench.preferredLightColorTheme',
    'workbench.preferredDarkColorTheme',
    'window.autoDetectColorScheme'
)

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
    }
    [System.IO.File]::WriteAllText($ProductJsonPath, $product, [System.Text.UTF8Encoding]::new($false))
}

function Restore-WorkbenchFromBackup {
    param([string]$Path)
    if (-not $Path) { return $false }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { return $false }
    $matchBak = Get-ChildItem $dir -Filter "$(Split-Path $Path -Leaf).*.bak-custom-css" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $bak = if ($matchBak) { $matchBak } else {
        Get-ChildItem $dir -Filter "workbench.*.bak-custom-css" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $bak) { return $false }
    $raw = Get-Content $bak.FullName -Raw -Encoding UTF8
    if ($raw -match 'VSCODE-CUSTOM-CSS-START') { return $false }
    Copy-Item $bak.FullName $Path -Force
    Write-Host "    restored CSP+html from $($bak.Name) -> $Path" -ForegroundColor Green
    return $true
}

function Remove-WorkbenchPatch {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { return $false }
    if (Restore-WorkbenchFromBackup -Path $Path) {
        if (Test-Path $ProductJson) { Update-ProductJsonChecksum -ProductJsonPath $ProductJson -WorkbenchHtmlPath $Path }
        return $true
    }
    $html = Get-Content $Path -Raw -Encoding UTF8
    if ($html -notmatch 'VSCODE-CUSTOM-CSS-START') { return $false }
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    [System.IO.File]::WriteAllText($Path, $html, [System.Text.UTF8Encoding]::new($false))
    if (Test-Path $ProductJson) { Update-ProductJsonChecksum -ProductJsonPath $ProductJson -WorkbenchHtmlPath $Path }
    Write-Host "    stripped glass patch (CSP backup not found): $Path" -ForegroundColor Yellow
    return $true
}

Write-Host "`n==> Removing workbench patch" -ForegroundColor Cyan
$restored = @()
foreach ($mirrorPath in ($CustomCssWorkbenchPaths | Select-Object -Unique)) {
    if (Remove-WorkbenchPatch -Path $mirrorPath) { $restored += $mirrorPath }
}
if ($restored.Count -eq 0) {
    Write-Host "    no glass patch found" -ForegroundColor Yellow
}

Write-Host "`n==> Cleaning settings.json" -ForegroundColor Cyan
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

Write-Host "`nRestart Cursor. Backup kept at: $BackupPath`n" -ForegroundColor Yellow
